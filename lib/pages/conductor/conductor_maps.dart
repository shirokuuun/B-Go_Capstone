import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:b_go/pages/conductor/destination_service.dart';
import 'package:b_go/services/direction_validation_service.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ConductorMaps extends StatefulWidget {
  final String route;
  final String role;

  const ConductorMaps({super.key, required this.route, required this.role});

  @override
  State<ConductorMaps> createState() => _ConductorMapsState();
}

class _ConductorMapsState extends State<ConductorMaps>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  int passengerCount = 0;
  List<Map<String, dynamic>> _activeBookings = [];
  List<Map<String, dynamic>> _activePreTickets = [];
  List<Map<String, dynamic>> _activeManualTickets = [];
  List<Map<String, dynamic>> _routeDestinations = [];
  Timer? _locationTimer;
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _conductorSubscription;
  StreamSubscription<QuerySnapshot>? _bookingsSubscription;
  StreamSubscription<QuerySnapshot>? _preTicketsSubscription;
  StreamSubscription<QuerySnapshot>? _manualTicketsSubscription;

  static const int MIN_ROUTE_MARKERS = 12;
  static const int MAX_ROUTE_MARKERS = 20;
  static const int MAX_PASSENGER_MARKERS = 100;
  static const int MAX_DESTINATIONS_CACHE = 50;
  static const Duration MARKER_REFRESH_COOLDOWN = Duration(seconds: 2);

  DateTime? _lastMarkerRefresh;

  // Track active trip direction
  String? _activeTripDirection;
  String? _activePlaceCollection;

  // Optimization variables
  static const int _locationUpdateInterval = 5;
  static const Duration _debounceDelay = Duration(milliseconds: 800);
  Timer? _debounceTimer;

  // Memory optimization
  Set<Marker> _cachedMarkers = {};
  String _lastMarkerCacheKey = '';

  // Performance flags
  bool _isUpdatingLocation = false;
  bool _isProcessingBookings = false;
  bool _isProcessingPreTickets = false;
  bool _isRefreshingMarkers = false;
  bool _isDisposed = false;

  // App lifecycle management
  bool _isAppActive = true;

  // Helper method to convert any numeric value to double
  double? _convertToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed;
    }
    return null;
  }

  // Get coordinates for a place name from route destinations
  Map<String, double>? _getCoordinatesForPlace(String placeName) {
    for (final destination in _routeDestinations) {
      if (destination['name'] == placeName) {
        final lat = _convertToDouble(destination['latitude']);
        final lng = _convertToDouble(destination['longitude']);
        if (lat != null && lng != null) {
          return {'latitude': lat, 'longitude': lng};
        }
      }
    }
    return null;
  }

  // Simple marker creation
  BitmapDescriptor _getCircularMarkerIcon() {
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  BitmapDescriptor _getSmallCircularMarker(Color color) {
    return BitmapDescriptor.defaultMarkerWithHue(_colorToHue(color));
  }

  BitmapDescriptor _getHumanIcon() {
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
  }

  double _colorToHue(Color color) {
    if (color == Colors.blue) return BitmapDescriptor.hueAzure;
    if (color == Colors.yellow) return BitmapDescriptor.hueYellow;
    if (color == Colors.green) return BitmapDescriptor.hueGreen;
    if (color == Colors.red) return BitmapDescriptor.hueRed;
    if (color == Colors.black) return BitmapDescriptor.hueViolet;
    return BitmapDescriptor.hueAzure;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _safeInitialize();
  }

  Future<void> _safeInitialize() async {
    try {
      if (_isDisposed) return;

      // Load route destinations first
      await _loadRouteDestinations();

      if (_isDisposed) return;
      await Future.delayed(Duration(milliseconds: 500));

      // Get location
      if (mounted && !_isDisposed) {
        await _getCurrentLocation();
      }

      if (_isDisposed) return;
      await Future.delayed(Duration(milliseconds: 300));

      // Load other data
      if (mounted && !_isDisposed && _currentPosition != null) {
        _loadBookings();
        _loadPreTickets();
        _loadManualTickets();
        _loadConductorData();
      }
    } catch (e) {
      print('Safe initialization error: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
        });
        _showLocationError('Initialization failed: $e');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;

    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _isAppActive = true;
        if (_currentPosition != null && _locationTimer == null) {
          _startLocationTracking();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _isAppActive = false;
        _pauseLocationTracking();
        break;
      case AppLifecycleState.detached:
        _cleanupResources();
        break;
      default:
        break;
    }
  }

  void _pauseLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);

    // Enhanced cleanup
    _cleanupResources();

    // Force garbage collection hint
    _forceMemoryCleanup();

    super.dispose();
  }

  void _forceMemoryCleanup() {
    // Clear all collections immediately
    _activeBookings.clear();
    _activePreTickets.clear();
    _activeManualTickets.clear();
    _routeDestinations.clear();
    _cachedMarkers.clear();

    // Reset counters
    passengerCount = 0;

    // Clear cache keys
    _lastMarkerCacheKey = '';
    _lastMarkerRefresh = null;

    print('Forced memory cleanup completed');
  }

  void _periodicMemoryCleanup() {
    if (_isDisposed) return;

    final totalMarkers = _cachedMarkers.length;
    final maxTotalMarkers = MIN_ROUTE_MARKERS + MAX_PASSENGER_MARKERS + 50;

    if (totalMarkers > maxTotalMarkers) {
      _cachedMarkers.clear();
      _lastMarkerCacheKey = '';
      print('Cleared marker cache due to size ($totalMarkers > $maxTotalMarkers)');
    }

    if (_routeDestinations.length > MAX_DESTINATIONS_CACHE) {
      _routeDestinations = _routeDestinations.take(MAX_DESTINATIONS_CACHE).toList();
      print('Trimmed destinations cache to ${MAX_DESTINATIONS_CACHE}');
    }
  }

  void _cleanupResources() {
    _isDisposed = true;

    // Cancel all timers and subscriptions
    _locationTimer?.cancel();
    _debounceTimer?.cancel();
    _bookingsSubscription?.cancel();
    _preTicketsSubscription?.cancel();
    _conductorSubscription?.cancel();
    _manualTicketsSubscription?.cancel();

    // ✅ DON'T stop geofencing service here - it should continue running
    // even when the conductor leaves the maps page. It will be stopped
    // when the conductor logs out or ends their trip in conductor_home.dart

    // Dispose map controller safely
    _mapController?.dispose();
    _mapController = null;

    // Clear data structures
    _activeBookings.clear();
    _activePreTickets.clear();
    _activeManualTickets.clear();
    _routeDestinations.clear();
    _cachedMarkers.clear();

    // Reset flags
    _isUpdatingLocation = false;
    _isProcessingBookings = false;
    _isProcessingPreTickets = false;
    _isRefreshingMarkers = false;
  }

  Future<void> _getCurrentLocation() async {
    if (_isUpdatingLocation || _isDisposed) return;
    _isUpdatingLocation = true;

    try {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = true;
        });
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services disabled');
      }

      // Get position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 8),
      ).timeout(
        Duration(seconds: 12),
        onTimeout: () => throw Exception('Location timeout'),
      );

      if (mounted && !_isDisposed) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
        });

        _startLocationTracking();

        // Delayed passenger count refresh
        Timer(Duration(seconds: 2), () {
          if (mounted && !_isDisposed) _refreshPassengerCount();
        });

        _showLocationSuccess();
      }
    } catch (e) {
      print('Location error: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
        });
        _showLocationError(e.toString());
      }
    } finally {
      _isUpdatingLocation = false;
    }
  }

  void _startLocationTracking() {
    if (_isDisposed) return;

    _locationTimer?.cancel();

    if (_currentPosition == null || !_isAppActive) return;

    _locationTimer = Timer.periodic(Duration(seconds: _locationUpdateInterval), (timer) {
      if (_isDisposed || !mounted || !_isAppActive) {
        timer.cancel();
        return;
      }

      // Periodic memory cleanup
      _periodicMemoryCleanup();

      _updateCurrentLocation();
    });
  }

  Future<void> _updateCurrentLocation() async {
    if (_isUpdatingLocation || !_isAppActive || _isDisposed) return;

    final passengerMarkerCount = _activeBookings.length +
        _activePreTickets.length +
        _activeManualTickets.length;
    if (passengerMarkerCount > MAX_PASSENGER_MARKERS + 30) {
      print('Skipping location update due to memory pressure (${passengerMarkerCount} passenger markers)');
      return;
    }

    _isUpdatingLocation = true;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 6),
      ).timeout(Duration(seconds: 8));

      if (mounted && _isAppActive && !_isDisposed) {
        setState(() {
          _currentPosition = position;
        });

        // ✅ GEOFENCING IS NOW HANDLED BY BACKGROUND SERVICE ONLY
        // Background geofencing_service.dart started in conductor_home.dart handles all drop-offs
        // This prevents duplicate drop-offs and passenger count issues
      }
    } catch (e) {
      print('Location update error: $e');
    } finally {
      _isUpdatingLocation = false;
    }
  }

  // GEOFENCING COMPLETELY REMOVED FROM CONDUCTOR_MAPS.DART
  // All passenger drop-offs are now handled by the background geofencing_service.dart
  // which is started in conductor_home.dart on login
  // This prevents duplicate drop-offs and incorrect passenger counts

  Future<void> _updatePreBookingStatus(
      String passengerId, String userId, String status) async {
    if (_isDisposed) return;

    print('🔄 _updatePreBookingStatus called for passenger: $passengerId');
    print('   User ID: $userId');
    print('   Target status: $status');

    String? actualUserId = userId;

    try {
      // Update in conductor's preBookings collection
      print('🔍 Searching conductor preBookings collection...');
      final query = await FirebaseFirestore.instance
          .collectionGroup('preBookings')
          .where(FieldPath.documentId, isEqualTo: passengerId)
          .limit(1)
          .get();

      print('📊 Query result: ${query.docs.length} documents found');

      if (query.docs.isNotEmpty && !_isDisposed) {
        print('✏️ Updating conductor preBooking document...');

        // If userId wasn't provided, try to get it from the conductor's document
        if (actualUserId.isEmpty) {
          final docData = query.docs.first.data();
          actualUserId = docData['userId'] as String;
          print('🔍 Retrieved userId from conductor document: $actualUserId');
        }

        await query.docs.first.reference.update({
          'status': status,
          'dropOffTimestamp': FieldValue.serverTimestamp(),
          'dropOffLocation': _currentPosition != null
              ? {
                  'latitude': _currentPosition!.latitude,
                  'longitude': _currentPosition!.longitude,
                }
              : null,
        });
        print('✅ Updated conductor pre-booking $passengerId status to $status');
      } else {
        print('⚠️ No conductor preBooking found for $passengerId');
      }

      // Also update in passenger's collection with improved error handling
      if (actualUserId.isNotEmpty && !_isDisposed) {
        print('👤 Updating passenger preBooking collection...');
        print('   Path: users/$actualUserId/preBookings/$passengerId');
        try {
          final docRef = FirebaseFirestore.instance
              .collection('users')
              .doc(actualUserId)
              .collection('preBookings')
              .doc(passengerId);

          final docSnapshot = await docRef.get();
          if (docSnapshot.exists) {
            await docRef.update({
              'status': status,
              'dropOffTimestamp': FieldValue.serverTimestamp(),
              'dropOffLocation': _currentPosition != null
                  ? {
                      'latitude': _currentPosition!.latitude,
                      'longitude': _currentPosition!.longitude,
                    }
                  : null,
            });
            print('✅ Updated passenger pre-booking $passengerId status to $status');
          } else {
            print('❌ Passenger pre-booking document does not exist at users/$actualUserId/preBookings/$passengerId');
          }
        } catch (userUpdateError) {
          print('❌ Error updating passenger pre-booking: $userUpdateError');
          print('   Stack trace: ${StackTrace.current}');
        }
      } else {
        print('⚠️ Skipping passenger update - userId is empty or disposed (actualUserId: $actualUserId)');
      }
    } catch (e) {
      print('❌ Error updating pre-booking status: $e');
      print('   Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _updateRemittanceTicketStatus(
      String preBookingId, String status) async {
    if (_isDisposed) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final conductorQuery = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (conductorQuery.docs.isEmpty) return;

      final conductorDocId = conductorQuery.docs.first.id;
      final now = DateTime.now();
      final formattedDate =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final ticketQuery = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorDocId)
          .collection('remittance')
          .doc(formattedDate)
          .collection('tickets')
          .where('documentType', isEqualTo: 'preBooking')
          .where('documentId', isEqualTo: preBookingId)
          .limit(1)
          .get();

      if (ticketQuery.docs.isNotEmpty && !_isDisposed) {
        final ticketData = ticketQuery.docs.first.data();
        final userId = ticketData['userId'];

        await ticketQuery.docs.first.reference.update({
          'status': status,
          'dropOffTimestamp': FieldValue.serverTimestamp(),
          'dropOffLocation': _currentPosition != null
              ? {
                  'latitude': _currentPosition!.latitude,
                  'longitude': _currentPosition!.longitude,
                }
              : null,
        });
        print('Updated remittance ticket for pre-booking $preBookingId to $status');

        if (userId != null && !_isDisposed) {
          try {
            final docRef = FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('preBookings')
                .doc(preBookingId);

            final docSnapshot = await docRef.get();
            if (docSnapshot.exists) {
              await docRef.update({
                'status': status,
                'dropOffTimestamp': FieldValue.serverTimestamp(),
                'dropOffLocation': _currentPosition != null
                    ? {
                        'latitude': _currentPosition!.latitude,
                        'longitude': _currentPosition!.longitude,
                      }
                    : null,
              });
              print('✅ Synced status to passenger collection for $preBookingId');
            } else {
              print('❌ Passenger pre-booking document does not exist at users/$userId/preBookings/$preBookingId');
            }
          } catch (userSyncError) {
            print('⚠️ Failed to sync to passenger collection: $userSyncError');
          }
        }
      }
    } catch (e) {
      print('Error updating remittance ticket status: $e');
    }
  }

  Future<void> _updateScannedQRCodeStatus(
      String preBookingId, String status) async {
    if (_isDisposed) return;

    print('🔄 _updateScannedQRCodeStatus called for preBookingId: $preBookingId');
    print('   Target status: $status');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No authenticated user found');
        return;
      }

      print('👤 Current user UID: ${user.uid}');

      print('🔍 Searching for conductor document...');
      final conductorQuery = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (conductorQuery.docs.isEmpty) {
        print('❌ No conductor document found for UID: ${user.uid}');
        return;
      }

      final conductorDocId = conductorQuery.docs.first.id;
      print('✅ Conductor document found: $conductorDocId');

      print('🔍 Searching scannedQRCodes collection...');
      print('   Path: conductors/$conductorDocId/scannedQRCodes');
      print('   Query: WHERE bookingId == $preBookingId');

      final qrCodeQuery = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorDocId)
          .collection('scannedQRCodes')
          .where('bookingId', isEqualTo: preBookingId)
          .limit(1)
          .get();

      print('📊 Query result: ${qrCodeQuery.docs.length} documents found');

      if (qrCodeQuery.docs.isNotEmpty && !_isDisposed) {
        final docId = qrCodeQuery.docs.first.id;
        final currentData = qrCodeQuery.docs.first.data();
        print('📄 Found scannedQRCode document: $docId');
        print('   Current status: ${currentData['status']}');
        print('✏️ Updating scannedQRCode status to: $status');

        await qrCodeQuery.docs.first.reference.update({
          'status': status,
          'dropOffTimestamp': FieldValue.serverTimestamp(),
          'dropOffLocation': _currentPosition != null
              ? {
                  'latitude': _currentPosition!.latitude,
                  'longitude': _currentPosition!.longitude,
                }
              : null,
        });
        print('✅ Successfully updated scannedQRCode for $preBookingId to $status');
      } else {
        print('❌ No scannedQRCode document found with bookingId: $preBookingId');
        print('   This means the QR code was not scanned or used a different ID');
      }
    } catch (e) {
      print('❌ Error updating scanned QR code status: $e');
    }
  }

  Future<void> _updateManualTicketStatus(
      String ticketId, String status, Map<String, dynamic> ticketData) async {
    if (_isDisposed) return;

    try {
      final conductorId = ticketData['conductorId'];
      final date = ticketData['date'];

      if (conductorId != null && date != null) {
        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorId)
            .collection('remittance')
            .doc(date)
            .collection('tickets')
            .doc(ticketId)
            .update({
          'status': status,
          'dropOffTimestamp': FieldValue.serverTimestamp(),
          'dropOffLocation': _currentPosition != null
              ? {
                  'latitude': _currentPosition!.latitude,
                  'longitude': _currentPosition!.longitude,
                }
              : null,
        });
        print('Updated manual ticket $ticketId status to $status');
      }
    } catch (e) {
      print('Error updating manual ticket status: $e');
    }
  }

  Future<void> _updatePreTicketStatus(
      String ticketId, String userId, String status) async {
    if (_isDisposed || userId.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('preTickets')
          .doc(ticketId)
          .update({
        'status': status,
        'dropOffTimestamp': FieldValue.serverTimestamp(),
        'dropOffLocation': _currentPosition != null
            ? {
                'latitude': _currentPosition!.latitude,
                'longitude': _currentPosition!.longitude,
              }
            : null,
      });

      print('Updated pre-ticket $ticketId status to $status');
    } catch (e) {
      print('Error updating pre-ticket status: $e');
    }
  }

  Future<void> _updateConductorPassengerCount() async {
    if (_isDisposed) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty && !_isDisposed) {
        await query.docs.first.reference.update({
          'passengerCount': passengerCount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        print('Updated conductor passenger count in Firebase: $passengerCount');
      }
    } catch (e) {
      print('Error updating conductor count: $e');
    }
  }

  void _showDropOffNotification(
      String passengerId, String from, String to, int quantity) {
    if (!mounted || _isDisposed) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Passenger Dropped Off',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600, color: Colors.white)),
                    Text(
                        '$from → $to (${quantity > 1 ? '$quantity passengers' : '1 passenger'})',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      print('Error showing drop-off notification: $e');
    }
  }

  void _loadConductorData() {
    if (_isDisposed) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _conductorSubscription?.cancel();
    _conductorSubscription = FirebaseFirestore.instance
        .collection('conductors')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (_isDisposed || !mounted || !_isAppActive) return;

      if (snapshot.docs.isNotEmpty) {
        final conductorData = snapshot.docs.first.data();
        final activeTrip = conductorData['activeTrip'];

        // Sync passenger count directly from Firebase
        final firebasePassengerCount = conductorData['passengerCount'] ?? 0;

        if (passengerCount != firebasePassengerCount && mounted && !_isDisposed) {
          setState(() {
            passengerCount = firebasePassengerCount;
          });
          print('Synced passenger count from Firebase: $firebasePassengerCount');
        }

        bool shouldRefresh = false;
        if (activeTrip != null && activeTrip['isActive'] == true) {
          final newDirection = activeTrip['direction'];
          final newPlaceCollection = activeTrip['placeCollection'];

          if (_activeTripDirection != newDirection ||
              _activePlaceCollection != newPlaceCollection) {
            setState(() {
              _activeTripDirection = newDirection;
              _activePlaceCollection = newPlaceCollection;
            });
            shouldRefresh = true;
          }
        } else {
          if (_activeTripDirection != null || _activePlaceCollection != null) {
            setState(() {
              _activeTripDirection = null;
              _activePlaceCollection = null;
            });
            shouldRefresh = true;
          }
        }

        if (shouldRefresh) {
          _debouncedRefreshMarkers();
        }
      }
    });
  }

  void _loadManualTickets() {
    if (_isDisposed) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('conductors')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get()
        .then((conductorQuery) {
      if (conductorQuery.docs.isEmpty || _isDisposed) return;

      final conductorId = conductorQuery.docs.first.id;
      final today = DateTime.now();
      final formattedDate =
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      _manualTicketsSubscription?.cancel();
      _manualTicketsSubscription = FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('remittance')
          .doc(formattedDate)
          .collection('tickets')
          .where('ticketType', isEqualTo: 'manual')
          .where('status', isEqualTo: 'boarded')
          .snapshots()
          .listen((snapshot) {
        if (_isDisposed || !mounted || !_isAppActive) return;

        try {
          final manualTickets = snapshot.docs.map((doc) {
            final data = doc.data();

            Map<String, double>? toCoords;
            if (data['toLatitude'] == null || data['toLongitude'] == null) {
              toCoords = _getCoordinatesForPlace(data['to'] ?? '');
            }

            return {
              'id': doc.id,
              'from': data['from'] ?? '',
              'to': data['to'] ?? '',
              'quantity': data['quantity'] ?? 1,
              'fromLatitude': _convertToDouble(data['fromLatitude']),
              'fromLongitude': _convertToDouble(data['fromLongitude']),
              'toLatitude':
                  toCoords?['latitude'] ?? _convertToDouble(data['toLatitude']),
              'toLongitude': toCoords?['longitude'] ??
                  _convertToDouble(data['toLongitude']),
              'ticketType': 'manual',
              'conductorId': conductorId,
              'date': formattedDate,
              'status': data['status'] ?? 'boarded',
            };
          }).toList();

          if (mounted && !_isDisposed) {
            setState(() {
              _activeManualTickets = manualTickets;
            });
            print('Loaded ${_activeManualTickets.length} active manual tickets for geofencing');
          }
        } catch (e) {
          print('Error processing manual tickets: $e');
        }
      });
    }).catchError((e) {
      print('Error getting conductor ID for manual tickets: $e');
    });
  }

  void _loadBookings() {
    if (_isProcessingBookings || _isDisposed) return;
    _isProcessingBookings = true;

    _bookingsSubscription?.cancel();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isProcessingBookings = false;
      return;
    }

    FirebaseFirestore.instance
        .collection('conductors')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get()
        .then((conductorQuery) {
      if (conductorQuery.docs.isEmpty || _isDisposed) {
        _isProcessingBookings = false;
        return;
      }

      final conductorDocId = conductorQuery.docs.first.id;
      final conductorData = conductorQuery.docs.first.data();

      final activeTripId = conductorData['activeTrip']?['tripId'];
      final preBookingsStream = activeTripId != null
          ? FirebaseFirestore.instance
              .collection('conductors')
              .doc(conductorDocId)
              .collection('preBookings')
              .where('route', isEqualTo: widget.route)
              .where('tripId', isEqualTo: activeTripId)
              .snapshots()
          : FirebaseFirestore.instance
              .collection('conductors')
              .doc(conductorDocId)
              .collection('preBookings')
              .where('route', isEqualTo: widget.route)
              .snapshots();

      _bookingsSubscription = preBookingsStream.listen((preBookingsSnapshot) {
        if (_isDisposed || !mounted || !_isAppActive) {
          _isProcessingBookings = false;
          return;
        }

        try {
          List<Map<String, dynamic>> activeBookings = [];

          print('📊 Processing ${preBookingsSnapshot.docs.length} pre-bookings from conductor collection...');

          for (var doc in preBookingsSnapshot.docs) {
            final data = doc.data();
            final status = data['status'] ?? '';
            final scannedBy = data['scannedBy'];

            print('  📋 Pre-booking ${doc.id}: status="$status", from="${data['from']}", to="${data['to']}", scannedBy=${scannedBy != null}');

            final isForCurrentTrip = activeTripId == null ||
                data['tripId'] == activeTripId ||
                data['tripId'] == null;

            final isActive = (status == 'paid' || status == 'boarded' || scannedBy != null) &&
                            status != 'accomplished';

            if (status == 'accomplished') {
              print('  ⏭️ SKIPPING - already accomplished');
            } else if (!isForCurrentTrip) {
              print('  ⏭️ SKIPPING - not for current trip');
            } else if (!isActive) {
              print('  ⏭️ SKIPPING - not active (status="$status")');
            }

            if (isActive && isForCurrentTrip) {
              print('  ✅ ACTIVE - adding to activeBookings list');
              final actualStatus = (scannedBy != null) ? 'boarded' : status;

              Map<String, double>? fromCoords;
              Map<String, double>? toCoords;

              if (data['fromLatitude'] == null || data['fromLongitude'] == null) {
                fromCoords = _getCoordinatesForPlace(data['from'] ?? '');
              }
              if (data['toLatitude'] == null || data['toLongitude'] == null) {
                toCoords = _getCoordinatesForPlace(data['to'] ?? '');
              }

              double? passengerLat, passengerLng;

              if (actualStatus == 'paid') {
                passengerLat = _convertToDouble(data['passengerLatitude']);
                passengerLng = _convertToDouble(data['passengerLongitude']);
              } else {
                passengerLat = toCoords?['latitude'] ?? _convertToDouble(data['toLatitude']);
                passengerLng = toCoords?['longitude'] ?? _convertToDouble(data['toLongitude']);
              }

              activeBookings.add({
                'id': doc.id,
                'userId': data['userId'],
                'from': data['from'],
                'to': data['to'],
                'quantity': data['quantity'] ?? 1,
                'fromLatitude': fromCoords?['latitude'] ?? _convertToDouble(data['fromLatitude']),
                'fromLongitude': fromCoords?['longitude'] ?? _convertToDouble(data['fromLongitude']),
                'toLatitude': toCoords?['latitude'] ?? _convertToDouble(data['toLatitude']),
                'toLongitude': toCoords?['longitude'] ?? _convertToDouble(data['toLongitude']),
                'passengerLatitude': passengerLat,
                'passengerLongitude': passengerLng,
                'status': actualStatus,
                'ticketType': 'preBooking',
                'qrData': data['qrData'],
                'isRealTime': actualStatus == 'paid',
              });
            }
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isDisposed || !mounted || !_isAppActive) {
              _isProcessingBookings = false;
              return;
            }

            setState(() {
              _activeBookings = activeBookings;
            });

            _debouncedRefreshMarkers();
            _isProcessingBookings = false;

            print('Loaded ${_activeBookings.length} active pre-bookings for geofencing');
          });
        } catch (e) {
          print('Error processing pre-bookings: $e');
          _isProcessingBookings = false;
        }
      });
    }).catchError((e) {
      print('Error getting conductor ID for pre-bookings: $e');
      _isProcessingBookings = false;
    });
  }

  void _loadPreTickets() {
    if (_isProcessingPreTickets || _isDisposed) return;
    _isProcessingPreTickets = true;

    _preTicketsSubscription?.cancel();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isProcessingPreTickets = false;
      return;
    }

    FirebaseFirestore.instance
        .collection('conductors')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get()
        .then((conductorQuery) {
      if (conductorQuery.docs.isEmpty || _isDisposed) {
        _isProcessingPreTickets = false;
        return;
      }

      final conductorDocId = conductorQuery.docs.first.id;

      final preTicketsStream = FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorDocId)
          .collection('preTickets')
          .where('route', isEqualTo: widget.route)
          .where('status', isEqualTo: 'boarded')
          .snapshots();

      _preTicketsSubscription = preTicketsStream.listen((preTicketsSnapshot) {
        if (_isDisposed || !mounted || !_isAppActive) {
          _isProcessingPreTickets = false;
          return;
        }

        try {
          List<Map<String, dynamic>> activePreTickets = [];

          for (var doc in preTicketsSnapshot.docs) {
            final data = doc.data();
            final status = data['status'] ?? '';

            if (status == 'boarded') {
              Map<String, double>? fromCoords;
              Map<String, double>? toCoords;

              if (data['fromLatitude'] == null ||
                  data['fromLongitude'] == null) {
                fromCoords = _getCoordinatesForPlace(data['from'] ?? '');
              }
              if (data['toLatitude'] == null || data['toLongitude'] == null) {
                toCoords = _getCoordinatesForPlace(data['to'] ?? '');
              }

              activePreTickets.add({
                'id': doc.id,
                'userId': _getUserIdFromPath(doc.reference.path),
                'from': data['from'],
                'to': data['to'],
                'quantity': data['quantity'] ?? 1,
                'fromLatitude': fromCoords?['latitude'] ??
                    _convertToDouble(data['fromLatitude']),
                'fromLongitude': fromCoords?['longitude'] ??
                    _convertToDouble(data['fromLongitude']),
                'toLatitude': toCoords?['latitude'] ??
                    _convertToDouble(data['toLatitude']),
                'toLongitude': toCoords?['longitude'] ??
                    _convertToDouble(data['toLongitude']),
                'passengerLatitude':
                    _convertToDouble(data['passengerLatitude']),
                'passengerLongitude':
                    _convertToDouble(data['passengerLongitude']),
                'status': status,
                'ticketType': 'preTicket',
              });
            }
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_isDisposed || !mounted || !_isAppActive) {
              _isProcessingPreTickets = false;
              return;
            }

            setState(() {
              _activePreTickets = activePreTickets;
            });

            _debouncedRefreshMarkers();
            _isProcessingPreTickets = false;

            print('Loaded ${_activePreTickets.length} active pre-tickets for geofencing');
          });
        } catch (e) {
          print('Error processing pre-tickets: $e');
          _isProcessingPreTickets = false;
        }
      });
    }).catchError((e) {
      print('Error getting conductor ID for pre-tickets: $e');
      _isProcessingPreTickets = false;
    });
  }

  String _getUserIdFromPath(String documentPath) {
    final pathParts = documentPath.split('/');
    if (pathParts.length >= 2 && pathParts[0] == 'users') {
      return pathParts[1];
    }
    return '';
  }

  Future<void> _loadRouteDestinations() async {
    if (_isDisposed) return;

    try {
      String routeId = widget.route;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final conductorQuery = await FirebaseFirestore.instance
              .collection('conductors')
              .where('uid', isEqualTo: user.uid)
              .limit(1)
              .get();

          if (conductorQuery.docs.isNotEmpty) {
            final conductorData = conductorQuery.docs.first.data();
            final routeName = conductorData['route'] as String?;
            if (routeName?.isNotEmpty == true) {
              routeId = routeName!;
            }
          }
        } catch (e) {
          print('Could not get route from conductor data: $e');
        }
      }

      if (_isDisposed) return;

      final destinations =
          await DestinationService.fetchRouteDestinations(routeId);

      if (mounted && !_isDisposed) {
        setState(() {
          _routeDestinations =
              destinations.take(MAX_DESTINATIONS_CACHE).toList();
        });

        if (destinations.isEmpty) {
          await _manualFetchDestinations(routeId);
        }
      }
    } catch (e) {
      print('Error loading destinations: $e');
      if (!_isDisposed) {
        await _manualFetchDestinations(widget.route);
      }
    }
  }

  Future<void> _manualFetchDestinations(String routeName) async {
    if (_isDisposed) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Destinations')
          .doc(routeName)
          .get();

      if (_isDisposed) return;

      if (snapshot.exists) {
        List<Map<String, dynamic>> manualDestinations = [];

        final placeSnapshot = await FirebaseFirestore.instance
            .collection('Destinations')
            .doc(routeName)
            .collection('Place')
            .get();

        if (_isDisposed) return;

        for (var doc in placeSnapshot.docs) {
          final data = doc.data();
          final latitude = _convertToDouble(data['latitude']);
          final longitude = _convertToDouble(data['longitude']);

          if (latitude != null && longitude != null) {
            manualDestinations.add({
              'name': data['Name']?.toString() ?? doc.id,
              'km': _convertToDouble(data['km']) ?? 0.0,
              'latitude': latitude,
              'longitude': longitude,
              'direction': 'forward',
            });
          }
        }

        final place2Snapshot = await FirebaseFirestore.instance
            .collection('Destinations')
            .doc(routeName)
            .collection('Place 2')
            .get();

        if (_isDisposed) return;

        for (var doc in place2Snapshot.docs) {
          final data = doc.data();
          final latitude = _convertToDouble(data['latitude']);
          final longitude = _convertToDouble(data['longitude']);

          if (latitude != null && longitude != null) {
            manualDestinations.add({
              'name': data['Name']?.toString() ?? doc.id,
              'km': _convertToDouble(data['km']) ?? 0.0,
              'latitude': latitude,
              'longitude': longitude,
              'direction': 'reverse',
            });
          }
        }

        if (manualDestinations.isNotEmpty && mounted && !_isDisposed) {
          setState(() {
            _routeDestinations = manualDestinations;
          });
        }
      }
    } catch (e) {
      print('Manual fetch failed: $e');
    }
  }

  Set<Marker> _buildMarkers() {
    if (!_isAppActive || _isDisposed) return _cachedMarkers;

    final now = DateTime.now();
    if (_lastMarkerRefresh != null &&
        now.difference(_lastMarkerRefresh!) < MARKER_REFRESH_COOLDOWN) {
      return _cachedMarkers;
    }

    final cacheKey =
        '${_currentPosition?.latitude}_${_currentPosition?.longitude}_${_activeBookings.length}_${_activePreTickets.length}_${_routeDestinations.length}_$_activePlaceCollection';

    if (cacheKey == _lastMarkerCacheKey && _cachedMarkers.isNotEmpty) {
      return _cachedMarkers;
    }

    _cachedMarkers.clear();
    final Set<Marker> markers = {};

    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: MarkerId('conductor'),
          position:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: InfoWindow(
            title: 'Conductor Location',
            snippet: 'Route: ${widget.route} - Passengers: $passengerCount',
          ),
          icon: _getSmallCircularMarker(Colors.blue),
        ),
      );
    }

    if (_routeDestinations.isNotEmpty) {
      final routeMarkers = _createGuaranteedRouteMarkers();
      markers.addAll(routeMarkers);
      print('Added ${routeMarkers.length} route markers (guaranteed)');
    }

    final passengerMarkers = _createSmartPassengerMarkers();
    markers.addAll(passengerMarkers);
    print('Added ${passengerMarkers.length} passenger markers');

    _cachedMarkers = markers;
    _lastMarkerCacheKey = cacheKey;
    _lastMarkerRefresh = now;

    print('Created ${markers.length} markers total (${passengerMarkers.length} passengers + 1 conductor)');
    return markers;
  }

  Set<Marker> _createGuaranteedRouteMarkers() {
    final Set<Marker> markers = {};

    List<Map<String, dynamic>> filteredDestinations = [];

    if (_activePlaceCollection != null) {
      filteredDestinations = _routeDestinations.where((destination) {
        final direction = destination['direction'] ?? 'unknown';

        if (_activePlaceCollection == 'Place') {
          return direction == 'forward' || direction == 'Place';
        } else if (_activePlaceCollection == 'Place 2') {
          return direction == 'reverse' || direction == 'Place 2';
        }
        return true;
      }).toList();
    } else {
      filteredDestinations = _routeDestinations;
    }

    int targetRouteMarkers =
        math.min(filteredDestinations.length, MAX_ROUTE_MARKERS);
    targetRouteMarkers = math.max(targetRouteMarkers,
        math.min(MIN_ROUTE_MARKERS, filteredDestinations.length));

    List<Map<String, dynamic>> selectedDestinations;
    if (filteredDestinations.length > targetRouteMarkers) {
      selectedDestinations = [];
      final step = filteredDestinations.length / targetRouteMarkers;
      for (int i = 0; i < targetRouteMarkers; i++) {
        final index = (i * step).floor();
        if (index < filteredDestinations.length) {
          selectedDestinations.add(filteredDestinations[index]);
        }
      }
    } else {
      selectedDestinations = filteredDestinations;
    }

    for (final destination in selectedDestinations) {
      final name = destination['name'] ?? 'Unknown';
      final km = destination['km'] ?? 0.0;
      final latitude = destination['latitude'] ?? 0.0;
      final longitude = destination['longitude'] ?? 0.0;
      final direction = destination['direction'] ?? 'unknown';

      if (latitude != 0.0 && longitude != 0.0) {
        markers.add(
          Marker(
            markerId: MarkerId('route_${name}_$direction'),
            position: LatLng(latitude, longitude),
            infoWindow: InfoWindow(
              title: name,
              snippet: '${km} km - ${widget.route} Route (${direction})',
            ),
            icon: _getCircularMarkerIcon(),
          ),
        );
      }
    }

    print('Created ${markers.length} guaranteed route markers from ${filteredDestinations.length} destinations');
    return markers;
  }

  Set<Marker> _createSmartPassengerMarkers() {
    final Set<Marker> markers = {};

    final availableSlots = MAX_PASSENGER_MARKERS;

    print('Creating smart passenger markers with ${availableSlots} available slots');

    List<Map<String, dynamic>> allPassengers = [
      ..._activeBookings.map((b) => {...b, 'ticketType': 'preBooking'}),
      ..._activePreTickets.map((t) => {...t, 'ticketType': 'preTicket'}),
      ..._activeManualTickets.map((m) => {...m, 'ticketType': 'manual'}),
    ];

    print('Total passengers: ${allPassengers.length}');

    List<Map<String, dynamic>> prioritizedPassengers;
    if (allPassengers.length > availableSlots && _currentPosition != null) {
      allPassengers.sort((a, b) {
        final aWaiting =
            a['status'] == 'paid' && a['ticketType'] == 'preBooking';
        final bWaiting =
            b['status'] == 'paid' && b['ticketType'] == 'preBooking';

        if (aWaiting && !bWaiting) return -1;
        if (!aWaiting && bWaiting) return 1;

        final aLat = aWaiting
            ? (_convertToDouble(a['passengerLatitude']) ?? 0.0)
            : (_convertToDouble(a['toLatitude']) ?? 0.0);
        final aLng = aWaiting
            ? (_convertToDouble(a['passengerLongitude']) ?? 0.0)
            : (_convertToDouble(a['toLongitude']) ?? 0.0);

        final bLat = bWaiting
            ? (_convertToDouble(b['passengerLatitude']) ?? 0.0)
            : (_convertToDouble(b['toLatitude']) ?? 0.0);
        final bLng = bWaiting
            ? (_convertToDouble(b['passengerLongitude']) ?? 0.0)
            : (_convertToDouble(b['toLongitude']) ?? 0.0);

        if (aLat == 0.0 || aLng == 0.0) return 1;
        if (bLat == 0.0 || bLng == 0.0) return -1;

        final aDist = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          aLat,
          aLng,
        );
        final bDist = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          bLat,
          bLng,
        );

        return aDist.compareTo(bDist);
      });

      prioritizedPassengers = allPassengers.take(availableSlots).toList();
      print('Prioritized ${prioritizedPassengers.length} passengers out of ${allPassengers.length}');
    } else {
      prioritizedPassengers = allPassengers;
    }

    for (final passenger in prioritizedPassengers) {
      final passengerLat =
          _convertToDouble(passenger['passengerLatitude']) ?? 0.0;
      final passengerLng =
          _convertToDouble(passenger['passengerLongitude']) ?? 0.0;

      if (passengerLat != 0.0 && passengerLng != 0.0) {
        final ticketType = passenger['ticketType'] ?? 'unknown';
        final status = passenger['status'] ?? 'unknown';
        final isRealTime = passenger['isRealTime'] ?? false;
        BitmapDescriptor icon;
        String title;

        switch (ticketType) {
          case 'preBooking':
            if (status == 'paid' && isRealTime) {
              icon = _getSmallCircularMarker(Colors.red);
              title = 'Pre-booked Passenger';
            } else if (status == 'boarded') {
              icon = _getHumanIcon();
              title = 'Pre-booked Passenger (Boarded)';
            } else {
              icon = _getSmallCircularMarker(Colors.blue);
              title = 'Pre-booked Passenger';
            }
            break;
          case 'preTicket':
            icon = _getSmallCircularMarker(Colors.orange);
            title = 'Pre-ticket Passenger';
            break;
          case 'manual':
            icon = _getSmallCircularMarker(Colors.grey);
            title = 'Manual Ticket';
            break;
          default:
            icon = _getSmallCircularMarker(Colors.purple);
            title = 'Passenger';
        }

        markers.add(
          Marker(
            markerId: MarkerId('${ticketType}_${passenger['id']}'),
            position: LatLng(passengerLat, passengerLng),
            infoWindow: InfoWindow(
              title: title,
              snippet:
                  '${passenger['from']} → ${passenger['to']} (${passenger['quantity']} pax)',
            ),
            icon: icon,
          ),
        );
      }
    }

    return markers;
  }

  void _debouncedRefreshMarkers() {
    if (_isRefreshingMarkers || _isDisposed) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, () {
      if (mounted && _isAppActive && !_isRefreshingMarkers && !_isDisposed) {
        _refreshMarkers();
      }
    });
  }

  void _refreshMarkers() {
    if (_isRefreshingMarkers || !_isAppActive || _isDisposed) return;
    _isRefreshingMarkers = true;

    try {
      _lastMarkerCacheKey = '';
      _cachedMarkers.clear();

      if (mounted && !_isDisposed) {
        setState(() {});
      }
    } finally {
      _isRefreshingMarkers = false;
    }
  }

  void _refreshPassengerCount() {
    print('Passenger count refresh called - current count: $passengerCount (from Firebase)');
  }

  void _showLocationError(String errorMessage) {
    if (!mounted || _isDisposed) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.location_off, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Location Error',
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600, color: Colors.white)),
                  Text(errorMessage,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _getCurrentLocation,
        ),
      ),
    );
  }

  void _showLocationSuccess() {
    if (!mounted || _isDisposed) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.location_on, color: Colors.white),
            SizedBox(width: 12),
            Text('Location acquired!',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Maps",
            style:
                GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w500)),
        backgroundColor: Color(0xFF0091AD),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          if (_currentPosition != null && !_isDisposed) ...[
            IconButton(
              icon: Icon(Icons.qr_code_scanner),
              onPressed: _openQRScanner,
              tooltip: 'Scan QR Code',
            ),
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _debouncedRefreshMarkers,
              tooltip: 'Refresh Markers',
            ),
          ],
        ],
      ),
      body: _isLoading || _currentPosition == null
          ? _buildLoadingScreen()
          : Stack(
              children: [
                GoogleMap(
                  key: ValueKey('conductor_map_safe'),
                  onMapCreated: (GoogleMapController controller) {
                    if (!_isDisposed) {
                      _mapController = controller;
                      if (_currentPosition != null) {
                        _debouncedRefreshMarkers();
                      }
                    }
                  },
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude,
                            _currentPosition!.longitude)
                        : LatLng(14.1128, 120.9558),
                    zoom: 15.0,
                  ),
                  markers: _buildMarkers(),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                ),
                _buildInfoOverlay(),
              ],
            ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            _isLoading ? 'Getting location...' : 'Location not available',
            style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[600]),
          ),
          if (_isLoading) ...[
            SizedBox(height: 16),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0091AD)),
            ),
            SizedBox(height: 16),
            Text('Please wait...',
                style:
                    GoogleFonts.outfit(fontSize: 14, color: Colors.grey[500])),
          ],
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isDisposed ? null : _getCurrentLocation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0091AD),
              foregroundColor: Colors.white,
            ),
            child: Text('Get Location'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoOverlay() {
    return Positioned(
      top: 16,
      left: 16,
      right: 120,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$passengerCount passengers',
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0091AD))),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!, width: 1),
                  ),
                  child: Text(
                      '${_activeBookings.where((b) => b['status'] == 'paid' && b['isRealTime'] == true).length} waiting (real-time)',
                      style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Colors.red[800])),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!, width: 1),
                  ),
                  child: Text(
                      '${_activeBookings.where((b) => b['status'] == 'boarded').length} boarded',
                      style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Colors.green[700])),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!, width: 1),
                  ),
                  child: Text('${_activePreTickets.length} pre-tickets',
                      style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange[700])),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: Text('${_activeManualTickets.length} manual',
                      style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700])),
                ),
              ],
            ),
            if (_routeDestinations.isNotEmpty) ...[
              SizedBox(height: 4),
              Text('Route: ${widget.route}',
                  style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700])),
              if (_activeTripDirection != null) ...[
                Container(
                  margin: EdgeInsets.only(top: 2),
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _activePlaceCollection == 'Place'
                        ? Colors.blue[100]
                        : Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _activePlaceCollection == 'Place'
                            ? Colors.blue[300]!
                            : Colors.orange[300]!,
                        width: 1),
                  ),
                  child: Text('$_activeTripDirection',
                      style: GoogleFonts.outfit(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: _activePlaceCollection == 'Place'
                              ? Colors.blue[700]
                              : Colors.orange[700])),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _openQRScanner() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => _QRScannerPage(),
      ),
    )
        .then((result) {
      if (result == true) {
        _debouncedRefreshMarkers();
        _refreshPassengerCount();
      }
    });
  }
}

class _QRScannerPage extends StatefulWidget {
  @override
  State<_QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<_QRScannerPage> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan QR Code', style: GoogleFonts.outfit(fontSize: 18)),
        backgroundColor: Color(0xFF0091AD),
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(
        onDetect: (capture) async {
          if (_isProcessing) {
            print('QR scan already in progress, ignoring duplicate detection');
            return;
          }

          setState(() {
            _isProcessing = true;
          });

          final barcode = capture.barcodes.first;
          final qrData = barcode.rawValue;

          if (qrData != null && qrData.isNotEmpty) {
            try {
              final data = parseQRData(qrData);
              await storePreTicketToFirestore(data);
              Navigator.of(context).pop(true);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Scan failed: ${e.toString().replaceAll('Exception: ', '')}'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
              Navigator.of(context).pop(false);
            } finally {
              setState(() {
                _isProcessing = false;
              });
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invalid QR code: No data detected'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
            setState(() {
              _isProcessing = false;
            });
          }
        },
      ),
    );
  }
}

Map<String, dynamic> parseQRData(String qrData) {
  try {
    final Map<String, dynamic> data = jsonDecode(qrData);
    return data;
  } catch (e) {
    throw Exception('Invalid QR code format: $e');
  }
}

Future<void> storePreTicketToFirestore(Map<String, dynamic> data) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('User not authenticated');

  final qrDataString = jsonEncode(data);
  final quantity = data['quantity'] ?? 1;

  final conductorDoc = await FirebaseFirestore.instance
      .collection('conductors')
      .where('uid', isEqualTo: user.uid)
      .get();

  if (conductorDoc.docs.isEmpty) {
    throw Exception('Conductor profile not found');
  }

  final conductorData = conductorDoc.docs.first.data();
  final conductorRoute = conductorData['route'];
  final route = data['route'];

  if (conductorRoute != route) {
    throw Exception(
        'Invalid route. You are a $conductorRoute conductor but trying to scan a $route ticket. Only $conductorRoute tickets can be scanned.');
  }

  final type = data['type'] ?? '';
  if (type == 'preBooking') {
    await _processPreBooking(data, user, conductorDoc, quantity, qrDataString);
  } else {
    if (type == 'preTicket') {
      final passengerDirection = data['direction'];
      final passengerPlaceCollection = data['placeCollection'];

      if (passengerDirection != null && passengerPlaceCollection != null) {
        final isDirectionCompatible = await DirectionValidationService
            .validateDirectionCompatibilityByCollection(
          passengerRoute: route,
          passengerPlaceCollection: passengerPlaceCollection,
          conductorUid: user.uid,
        );

        if (!isDirectionCompatible) {
          final activeTrip = conductorData['activeTrip'];
          final conductorDirection = activeTrip?['direction'] ?? 'Unknown';

          throw Exception(
              'Direction mismatch! Your ticket is for "$passengerDirection" but the conductor is currently on "$conductorDirection" trip. Please wait for the correct direction or contact the conductor.');
        }
      }
    }

    await _processPreTicket(data, user, conductorDoc, quantity, qrDataString);
  }
}

Future<void> _processPreBooking(Map<String, dynamic> data, User user,
    QuerySnapshot conductorDoc, int quantity, String qrDataString) async {
  final preBookingsQuery = await FirebaseFirestore.instance
      .collectionGroup('preBookings')
      .where('qrData', isEqualTo: qrDataString)
      .where('status', isEqualTo: 'paid')
      .get();

  if (preBookingsQuery.docs.isEmpty) {
    throw Exception(
        'No paid pre-booking found with this QR code. Please ensure payment is completed.');
  }

  final paidPreBooking = preBookingsQuery.docs.first;
  final preBookingData = paidPreBooking.data();

  if (preBookingData['status'] == 'boarded' ||
      preBookingData['boardingStatus'] == 'boarded') {
    throw Exception('This pre-booking has already been scanned and boarded.');
  }

  await paidPreBooking.reference.update({
    'status': 'boarded',
    'boardedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'scannedAt': FieldValue.serverTimestamp(),
    'boardingStatus': 'boarded',
    'locationTrackingStopped': true,
    'locationTrackingStoppedAt': FieldValue.serverTimestamp(),
  });

  try {
    final bookingId = paidPreBooking.id;
    final passengerUserId = preBookingData['userId'];
    if (passengerUserId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(passengerUserId)
          .collection('preBookings')
          .doc(bookingId)
          .update({
        'status': 'boarded',
        'boardedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
        'scannedAt': FieldValue.serverTimestamp(),
        'boardingStatus': 'boarded',
      });
    }

    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final ticketsCol = FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorDoc.docs.first.id)
        .collection('remittance')
        .doc(formattedDate)
        .collection('tickets');
    final ticketQuery = await ticketsCol
        .where('documentType', isEqualTo: 'preBooking')
        .where('documentId', isEqualTo: bookingId)
        .limit(1)
        .get();
    if (ticketQuery.docs.isNotEmpty) {
      await ticketsCol.doc(ticketQuery.docs.first.id).update({
        'status': 'boarded',
        'boardedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
      });
    }
  } catch (e) {
    print('⚠️ Conductor maps sync to boarded failed: $e');
  }

  final conductorDocId = conductorDoc.docs.first.id;
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .collection('preBookings')
      .add({
    'qrData': qrDataString,
    'originalDocumentId': paidPreBooking.id,
    'originalCollection': paidPreBooking.reference.parent.path,
    'scannedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'qr': true,
    'status': 'boarded',
    'data': data,
  });
}

Future<void> _processPreTicket(Map<String, dynamic> data, User user,
    QuerySnapshot conductorDoc, int quantity, String qrDataString) async {
  final preTicketsQuery = await FirebaseFirestore.instance
      .collectionGroup('preTickets')
      .where('qrData', isEqualTo: qrDataString)
      .where('status', isEqualTo: 'pending')
      .get();

  if (preTicketsQuery.docs.isEmpty) {
    throw Exception('No pending pre-ticket found with this QR code.');
  }

  final pendingPreTicket = preTicketsQuery.docs.first;
  final preTicketData = pendingPreTicket.data();

  if (preTicketData['status'] == 'boarded') {
    throw Exception('This pre-ticket has already been scanned and boarded.');
  }

  await pendingPreTicket.reference.update({
    'status': 'boarded',
    'boardedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'scannedAt': FieldValue.serverTimestamp(),
  });

  final conductorDocId = conductorDoc.docs.first.id;
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .collection('preTickets')
      .add({
    'qrData': qrDataString,
    'originalDocumentId': pendingPreTicket.id,
    'originalCollection': pendingPreTicket.reference.parent.path,
    'scannedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'qr': true,
    'status': 'boarded',
    'data': data,
  });

  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .update({'passengerCount': FieldValue.increment(quantity)});
}