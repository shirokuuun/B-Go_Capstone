import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:b_go/pages/conductor/destination_service.dart';
import 'package:b_go/services/direction_validation_service.dart';
import 'package:b_go/pages/passenger/services/geofencing_service.dart';
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
  List<Map<String, dynamic>> _activePreTickets =
      []; // Separate list for pre-tickets
  List<Map<String, dynamic>> _activeManualTickets = [];
  List<Map<String, dynamic>> _routeDestinations = [];
  Timer? _locationTimer;
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _conductorSubscription;
  StreamSubscription<QuerySnapshot>? _bookingsSubscription;
  StreamSubscription<QuerySnapshot>?
      _preTicketsSubscription; // Separate subscription for pre-tickets
  StreamSubscription<QuerySnapshot>? _manualTicketsSubscription;

  static const int MIN_ROUTE_MARKERS = 12; // Minimum route markers to always show
  static const int MAX_ROUTE_MARKERS = 20; // Increased max route markers
  static const int MAX_PASSENGER_MARKERS = 100; // Allow more passenger markers
  static const int MAX_DESTINATIONS_CACHE = 50;
  static const Duration MARKER_REFRESH_COOLDOWN = Duration(seconds: 2);

  DateTime? _lastMarkerRefresh;

  // Track active trip direction
  String? _activeTripDirection;
  String? _activePlaceCollection;

  // Geofencing variables
  List<Map<String, dynamic>> _passengersNearDropOff = [];
  bool _showDropOffBanner = false;
  DateTime? _lastGeofencingCheck;

  // Optimization variables
  static const int _locationUpdateInterval = 5;
  static const Duration _debounceDelay = Duration(milliseconds: 800);
  static const Duration _geofencingCooldown = Duration(seconds: 10);
  Timer? _debounceTimer;

  // Memory optimization
  Set<Marker> _cachedMarkers = {};
  String _lastMarkerCacheKey = '';

  // Performance flags
  bool _isUpdatingLocation = false;
  bool _isProcessingBookings = false;
  bool _isProcessingPreTickets = false; // Separate flag for pre-tickets
  bool _isRefreshingMarkers = false;
  bool _isDisposed = false;

  // App lifecycle management
  bool _isAppActive = true;

  // Geofencing constants
  static const double _dropOffRadius = 600.0;
  static const double _readyDropOffRadius = 250.0;

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
    if (color == Colors.black) return BitmapDescriptor.hueViolet; // Use violet for black markers
    return BitmapDescriptor.hueAzure;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _safeInitialize();
    _startGeofencingService();
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
        _loadPreTickets(); // Load pre-tickets separately
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
    _passengersNearDropOff.clear();
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
    
    // FIXED: Use separate limits for route and passenger markers
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
    _preTicketsSubscription?.cancel(); // Cancel pre-tickets subscription
    _conductorSubscription?.cancel();
    _manualTicketsSubscription?.cancel();

    // Stop geofencing service
    GeofencingService().stopMonitoring();

    // Dispose map controller safely
    _mapController?.dispose();
    _mapController = null;

    // Clear data structures
    _activeBookings.clear();
    _activePreTickets.clear(); // Clear pre-tickets
    _activeManualTickets.clear();
    _routeDestinations.clear();
    _passengersNearDropOff.clear();
    _cachedMarkers.clear();

    // Reset flags
    _isUpdatingLocation = false;
    _isProcessingBookings = false;
    _isProcessingPreTickets = false; // Reset pre-tickets flag
    _isRefreshingMarkers = false;
  }

  // Start geofencing service for conductor
  Future<void> _startGeofencingService() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get conductor document ID
      final conductorQuery = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (conductorQuery.docs.isNotEmpty) {
        final conductorDocId = conductorQuery.docs.first.id;
        await GeofencingService().startConductorMonitoring(widget.route, conductorDocId);
        print('✅ Started conductor geofencing service for route: ${widget.route}');
      }
    } catch (e) {
      print('❌ Error starting conductor geofencing service: $e');
    }
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
    
    // FIXED: Only check passenger markers for memory pressure, not route markers
    final passengerMarkerCount = _activeBookings.length + _activePreTickets.length + _activeManualTickets.length;
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
        
        _performGeofencingCheck(position);
      }
    } catch (e) {
      print('Location update error: $e');
    } finally {
      _isUpdatingLocation = false;
    }
  }

  // UPDATED: Improved geofencing logic with support for both pre-bookings and pre-tickets
  void _performGeofencingCheck(Position currentPosition) {
    if (_isDisposed ||
        (_activeBookings.isEmpty &&
            _activePreTickets.isEmpty &&
            _activeManualTickets.isEmpty)) return;

    final now = DateTime.now();
    if (_lastGeofencingCheck != null &&
        now.difference(_lastGeofencingCheck!) < _geofencingCooldown) {
      return;
    }
    _lastGeofencingCheck = now;

    try {
      List<Map<String, dynamic>> passengersNear = [];
      List<Map<String, dynamic>> readyForDropOff = [];

      // Check pre-bookings (only boarded ones for geofencing)
      for (final booking in _activeBookings) {
        if (_isDisposed) return;

        // Only process boarded passengers for geofencing
        final status = booking['status'] ?? '';
        if (status != 'boarded') continue;

        final toLat = _convertToDouble(booking['toLatitude']);
        final toLng = _convertToDouble(booking['toLongitude']);

        if (toLat != null && toLng != null) {
          final distance = Geolocator.distanceBetween(
            currentPosition.latitude,
            currentPosition.longitude,
            toLat,
            toLng,
          );

          if (distance <= _dropOffRadius) {
            if (distance <= _readyDropOffRadius) {
              readyForDropOff.add({...booking, 'ticketType': 'preBooking'});
            } else {
              passengersNear.add({...booking, 'ticketType': 'preBooking'});
            }
          }
        }
      }

      // Check pre-tickets (scanned from PreTicket page)
      for (final ticket in _activePreTickets) {
        if (_isDisposed) return;

        double? toLat = _convertToDouble(ticket['toLatitude']);
        double? toLng = _convertToDouble(ticket['toLongitude']);

        // If coordinates are missing, try to get them from the destination name
        if ((toLat == null || toLng == null) && ticket['to'] != null) {
          final coords = _getCoordinatesForPlace(ticket['to']);
          if (coords != null) {
            toLat = coords['latitude'];
            toLng = coords['longitude'];
            // Update the ticket with coordinates for future use
            ticket['toLatitude'] = toLat;
            ticket['toLongitude'] = toLng;
          }
        }

        if (toLat != null && toLng != null) {
          final distance = Geolocator.distanceBetween(
            currentPosition.latitude,
            currentPosition.longitude,
            toLat,
            toLng,
          );

          if (distance <= _dropOffRadius) {
            if (distance <= _readyDropOffRadius) {
              readyForDropOff.add({...ticket, 'ticketType': 'preTicket'});
            } else {
              passengersNear.add({...ticket, 'ticketType': 'preTicket'});
            }
          }
        }
      }

      // Check manual tickets
      for (final ticket in _activeManualTickets) {
        if (_isDisposed) return;

        double? toLat = _convertToDouble(ticket['toLatitude']);
        double? toLng = _convertToDouble(ticket['toLongitude']);

        // If coordinates are missing, try to get them from the destination name
        if ((toLat == null || toLng == null) && ticket['to'] != null) {
          final coords = _getCoordinatesForPlace(ticket['to']);
          if (coords != null) {
            toLat = coords['latitude'];
            toLng = coords['longitude'];
            // Update the ticket with coordinates for future use
            ticket['toLatitude'] = toLat;
            ticket['toLongitude'] = toLng;
          }
        }

        if (toLat != null && toLng != null) {
          final distance = Geolocator.distanceBetween(
            currentPosition.latitude,
            currentPosition.longitude,
            toLat,
            toLng,
          );

          if (distance <= _dropOffRadius) {
            if (distance <= _readyDropOffRadius) {
              readyForDropOff.add({...ticket, 'ticketType': 'manual'});
            } else {
              passengersNear.add({...ticket, 'ticketType': 'manual'});
            }
          }
        }
      }

      print(
          'Geofencing check: ${_activeBookings.length} pre-bookings, ${_activePreTickets.length} pre-tickets, ${_activeManualTickets.length} manual tickets');
      print(
          'Found ${passengersNear.length} passengers near drop-off, ${readyForDropOff.length} ready for drop-off');

      // Update UI safely
      if (mounted && !_isDisposed) {
        setState(() {
          _passengersNearDropOff = passengersNear + readyForDropOff;
          _showDropOffBanner = _passengersNearDropOff.isNotEmpty;
        });
      }

      // Process ready passengers for automatic drop-off
      if (readyForDropOff.isNotEmpty) {
        _processReadyPassengers(readyForDropOff);
      }
    } catch (e) {
      print('Error in geofencing check: $e');
      // Don't crash the app, just log the error
    }
  }

  // UPDATED: Process passengers ready for drop-off with support for pre-tickets
  void _processReadyPassengers(List<Map<String, dynamic>> readyPassengers) {
    if (_isDisposed || readyPassengers.isEmpty) return;

    // Process passengers one by one to avoid overwhelming the system
    _processPassengerBatch(readyPassengers, 0);
  }

  // NEW: Process passengers in batches to prevent crashes
  void _processPassengerBatch(
      List<Map<String, dynamic>> passengers, int startIndex) {
    if (_isDisposed || startIndex >= passengers.length) return;

    final batchSize = 2; // Process 2 passengers at a time
    final endIndex = math.min(startIndex + batchSize, passengers.length);
    final currentBatch = passengers.sublist(startIndex, endIndex);

    print(
        'Processing passenger batch ${startIndex + 1}-$endIndex of ${passengers.length}');

    for (final passenger in currentBatch) {
      if (_isDisposed) return;

      try {
        final passengerId = passenger['id'];
        final userId = passenger['userId'];
        final quantity = passenger['quantity'] ?? 1;
        final from = passenger['from'];
        final to = passenger['to'];
        final ticketType = passenger['ticketType'];

        print(
            'Auto-dropping off passenger: $passengerId (quantity: $quantity) from $from to $to (type: $ticketType)');

        // Update status and decrement count based on ticket type
        if (ticketType == 'preBooking') {
          // Remove from active bookings
          if (mounted && !_isDisposed) {
            setState(() {
              _activeBookings
                  .removeWhere((booking) => booking['id'] == passengerId);
              passengerCount = math.max(
                  0,
                  passengerCount -
                      (quantity is int ? quantity : (quantity as num).toInt()));
            });
          }
          _updatePreBookingStatus(passengerId, 'accomplished');
        } else if (ticketType == 'preTicket') {
          // Remove from active pre-tickets
          if (mounted && !_isDisposed) {
            setState(() {
              _activePreTickets
                  .removeWhere((ticket) => ticket['id'] == passengerId);
              passengerCount = math.max(
                  0,
                  passengerCount -
                      (quantity is int ? quantity : (quantity as num).toInt()));
            });
          }
          _updatePreTicketStatus(passengerId, userId, 'accomplished');
        } else if (ticketType == 'manual') {
          // Remove from active manual tickets
          if (mounted && !_isDisposed) {
            setState(() {
              _activeManualTickets
                  .removeWhere((ticket) => ticket['id'] == passengerId);
              passengerCount = math.max(
                  0,
                  passengerCount -
                      (quantity is int ? quantity : (quantity as num).toInt()));
            });
          }
          _updateManualTicketStatus(passengerId, 'dropped_off', passenger);
        }

        _showDropOffNotification(passengerId, from, to, quantity);
        print('Passenger count after drop-off: $passengerCount');
      } catch (e) {
        print('Error processing passenger drop-off: $e');
        // Continue with next passenger instead of crashing
      }
    }

    // Process next batch after a delay
    if (endIndex < passengers.length && !_isDisposed) {
      Timer(Duration(milliseconds: 500), () {
        if (!_isDisposed) {
          _processPassengerBatch(passengers, endIndex);
        }
      });
    } else {
      // All passengers processed, update conductor count and refresh markers
      if (!_isDisposed) {
        _updateConductorPassengerCount();
        _debouncedRefreshMarkers();
      }
    }
  }

  // Update the _updatePreBookingStatus method
  Future<void> _updatePreBookingStatus(
      String passengerId, String status) async {
    if (_isDisposed) return;

    try {
      final query = await FirebaseFirestore.instance
          .collectionGroup('preBookings')
          .where(FieldPath.documentId, isEqualTo: passengerId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty && !_isDisposed) {
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
        print('Updated pre-booking $passengerId status to $status');
      }
    } catch (e) {
      print('Error updating pre-booking status: $e');
      // Don't crash the app, just log the error
    }
  }

  // Update manual ticket status
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
      // Don't crash the app, just log the error
    }
  }

  // Update pre-ticket status
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
      // Don't crash the app, just log the error
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
      // Don't crash the app, just log the error
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      print('Error showing drop-off notification: $e');
      // Don't crash the app, just log the error
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

        // Sync passenger count from Firebase
        final firebasePassengerCount = conductorData['passengerCount'] ?? 0;
        if (passengerCount != firebasePassengerCount) {
          setState(() {
            passengerCount = firebasePassengerCount;
          });
          print(
              'Synced passenger count from Firebase: $firebasePassengerCount');
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

  // Load manual tickets with proper status filtering
  void _loadManualTickets() {
    if (_isDisposed) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Get conductor ID first
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

            // Get coordinates for the destination if not present
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
            print(
                'Loaded ${_activeManualTickets.length} active manual tickets for geofencing');
          }
        } catch (e) {
          print('Error processing manual tickets: $e');
        }
      });
    }).catchError((e) {
      print('Error getting conductor ID for manual tickets: $e');
    });
  }

  // UPDATED: Load pre-bookings only (separate from pre-tickets)
  void _loadBookings() {
    if (_isProcessingBookings || _isDisposed) return;
    _isProcessingBookings = true;

    _bookingsSubscription?.cancel();

    // Load pre-bookings with 'paid' status for real-time tracking
    // 'paid' = waiting to be picked up with real-time location updates
    // 'boarded' = on the bus for geofencing (no longer tracked)
    final preBookingsStream = FirebaseFirestore.instance
        .collectionGroup('preBookings')
        .where('route', isEqualTo: widget.route)
        .where('status', whereIn: ['paid', 'boarded'])
        .snapshots();

    _bookingsSubscription = preBookingsStream.listen((preBookingsSnapshot) {
      if (_isDisposed || !mounted || !_isAppActive) {
        _isProcessingBookings = false;
        return;
      }

      try {
        List<Map<String, dynamic>> activeBookings = [];

        // Process pre-bookings with both 'paid' and 'boarded' status
        for (var doc in preBookingsSnapshot.docs) {
          final data = doc.data();
          final status = data['status'] ?? '';

          if (status == 'paid' || status == 'boarded') {
            // For 'paid' status, use real-time passenger location
            // For 'boarded' status, use destination location for geofencing
            double? passengerLat, passengerLng;
            
            if (status == 'paid') {
              // Use real-time passenger location for waiting passengers
              passengerLat = _convertToDouble(data['passengerLatitude']);
              passengerLng = _convertToDouble(data['passengerLongitude']);
            } else {
              // For boarded passengers, use destination for geofencing
              passengerLat = _convertToDouble(data['toLatitude']);
              passengerLng = _convertToDouble(data['toLongitude']);
            }

            activeBookings.add({
              'id': doc.id,
              'userId': data['userId'],
              'from': data['from'],
              'to': data['to'],
              'quantity': data['quantity'] ?? 1,
              'fromLatitude': _convertToDouble(data['fromLatitude']),
              'fromLongitude': _convertToDouble(data['fromLongitude']),
              'toLatitude': _convertToDouble(data['toLatitude']),
              'toLongitude': _convertToDouble(data['toLongitude']),
              'passengerLatitude': passengerLat,
              'passengerLongitude': passengerLng,
              'status': status,
              'ticketType': 'preBooking',
              'qrData': data['qrData'], // Include QR data for scanning
              'isRealTime': status == 'paid', // Flag for real-time tracking
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

          print(
              'Loaded ${_activeBookings.length} active pre-bookings for geofencing');
        });
      } catch (e) {
        print('Error processing pre-bookings: $e');
        _isProcessingBookings = false;
      }
    });
  }

  // NEW: Load pre-tickets separately
  void _loadPreTickets() {
    if (_isProcessingPreTickets || _isDisposed) return;
    _isProcessingPreTickets = true;

    _preTicketsSubscription?.cancel();

    // Load pre-tickets (created from PreTicket page)
    final preTicketsStream = FirebaseFirestore.instance
        .collectionGroup('preTickets')
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

        // Process pre-tickets (created from PreTicket page)
        for (var doc in preTicketsSnapshot.docs) {
          final data = doc.data();
          final status = data['status'] ?? '';

          if (status == 'boarded') {
            // Get coordinates from route destinations if not present
            Map<String, double>? fromCoords;
            Map<String, double>? toCoords;

            if (data['fromLatitude'] == null || data['fromLongitude'] == null) {
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
              'toLatitude':
                  toCoords?['latitude'] ?? _convertToDouble(data['toLatitude']),
              'toLongitude': toCoords?['longitude'] ??
                  _convertToDouble(data['toLongitude']),
              'passengerLatitude': _convertToDouble(data['passengerLatitude']),
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

          print(
              'Loaded ${_activePreTickets.length} active pre-tickets for geofencing');
        });
      } catch (e) {
        print('Error processing pre-tickets: $e');
        _isProcessingPreTickets = false;
      }
    });
  }

  // Add helper method to extract userId from document path
  String _getUserIdFromPath(String documentPath) {
    // Path format: users/{userId}/preTickets/{ticketId}
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
      
      // Try to get route ID from conductor data first
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
      
      final destinations = await DestinationService.fetchRouteDestinations(routeId);
      
      if (mounted && !_isDisposed) {
        setState(() {
          // Limit cached destinations to prevent memory issues
          _routeDestinations = destinations.take(MAX_DESTINATIONS_CACHE).toList();
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

        // Process Place collection
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

        // Process Place 2 collection
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
    
    final cacheKey = '${_currentPosition?.latitude}_${_currentPosition?.longitude}_${_activeBookings.length}_${_activePreTickets.length}_${_routeDestinations.length}_$_activePlaceCollection';
    
    if (cacheKey == _lastMarkerCacheKey && _cachedMarkers.isNotEmpty) {
      return _cachedMarkers;
    }
    
    _cachedMarkers.clear();
    final Set<Marker> markers = {};

    // 1. Add conductor marker (always include)
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: MarkerId('conductor'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: InfoWindow(
            title: 'Conductor Location',
            snippet: 'Route: ${widget.route} - Passengers: $passengerCount',
          ),
          icon: _getSmallCircularMarker(Colors.blue),
        ),
      );
    }
    // 2. FIXED: Always add route markers first (minimum guaranteed)
    if (_routeDestinations.isNotEmpty) {
      final routeMarkers = _createGuaranteedRouteMarkers();
      markers.addAll(routeMarkers);
      print('Added ${routeMarkers.length} route markers (guaranteed)');
    }

    // 3. Add passenger markers (unlimited but with memory awareness)
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
  
  // Filter by active trip direction if available
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

  // Ensure we always show at least MIN_ROUTE_MARKERS, but cap at MAX_ROUTE_MARKERS
  int targetRouteMarkers = math.min(filteredDestinations.length, MAX_ROUTE_MARKERS);
  targetRouteMarkers = math.max(targetRouteMarkers, math.min(MIN_ROUTE_MARKERS, filteredDestinations.length));
  
  // If we have more destinations than our target, sample them evenly
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
  
  // Create markers for selected destinations
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
  
  // Calculate available memory budget for passenger markers
  final availableSlots = MAX_PASSENGER_MARKERS; // Don't reduce based on route markers
  
  print('Creating smart passenger markers with ${availableSlots} available slots');
  
  List<Map<String, dynamic>> allPassengers = [
    ..._activeBookings.map((b) => {...b, 'ticketType': 'preBooking'}),
    ..._activePreTickets.map((t) => {...t, 'ticketType': 'preTicket'}),
    ..._activeManualTickets.map((m) => {...m, 'ticketType': 'manual'}),
  ];
  
  print('Total passengers: ${allPassengers.length}');
  
  // If we have more passengers than slots, prioritize by importance and distance
  List<Map<String, dynamic>> prioritizedPassengers;
  if (allPassengers.length > availableSlots && _currentPosition != null) {
    // Sort by priority: waiting passengers first, then by distance
    allPassengers.sort((a, b) {
      // Priority 1: Waiting passengers (paid pre-bookings)
      final aWaiting = a['status'] == 'paid' && a['ticketType'] == 'preBooking';
      final bWaiting = b['status'] == 'paid' && b['ticketType'] == 'preBooking';
      
      if (aWaiting && !bWaiting) return -1;
      if (!aWaiting && bWaiting) return 1;
      
      // Priority 2: Distance to passenger location (for waiting) or destination (for boarded)
      final aLat = aWaiting ? 
        (_convertToDouble(a['passengerLatitude']) ?? 0.0) :
        (_convertToDouble(a['toLatitude']) ?? 0.0);
      final aLng = aWaiting ? 
        (_convertToDouble(a['passengerLongitude']) ?? 0.0) :
        (_convertToDouble(a['toLongitude']) ?? 0.0);
      
      final bLat = bWaiting ? 
        (_convertToDouble(b['passengerLatitude']) ?? 0.0) :
        (_convertToDouble(b['toLatitude']) ?? 0.0);
      final bLng = bWaiting ? 
        (_convertToDouble(b['passengerLongitude']) ?? 0.0) :
        (_convertToDouble(b['toLongitude']) ?? 0.0);
      
      if (aLat == 0.0 || aLng == 0.0) return 1;
      if (bLat == 0.0 || bLng == 0.0) return -1;
      
      final aDist = Geolocator.distanceBetween(
        _currentPosition!.latitude, _currentPosition!.longitude,
        aLat, aLng,
      );
      final bDist = Geolocator.distanceBetween(
        _currentPosition!.latitude, _currentPosition!.longitude,
        bLat, bLng,
      );
      
      return aDist.compareTo(bDist);
    });
    
    prioritizedPassengers = allPassengers.take(availableSlots).toList();
    print('Prioritized ${prioritizedPassengers.length} passengers out of ${allPassengers.length}');
  } else {
    prioritizedPassengers = allPassengers;
  }
  
  // Create markers for prioritized passengers
  for (final passenger in prioritizedPassengers) {
    final passengerLat = _convertToDouble(passenger['passengerLatitude']) ?? 0.0;
    final passengerLng = _convertToDouble(passenger['passengerLongitude']) ?? 0.0;

    if (passengerLat != 0.0 && passengerLng != 0.0) {
      final ticketType = passenger['ticketType'] ?? 'unknown';
      final status = passenger['status'] ?? 'unknown';
      final isRealTime = passenger['isRealTime'] ?? false;
      BitmapDescriptor icon;
      String title;
      
      switch (ticketType) {
        case 'preBooking':
          if (status == 'paid' && isRealTime) {
            icon = _getSmallCircularMarker(Colors.red); // Red for waiting passengers with real-time tracking
            title = 'Pre-booked Passenger (Waiting - Real-time)';
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
            snippet: '${passenger['from']} → ${passenger['to']} (${passenger['quantity']} pax)',
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
        setState(() {
          // Trigger rebuild
        });
      }
    } finally {
      _isRefreshingMarkers = false;
    }
  }

  void _refreshPassengerCount() {
    // Passenger count comes from Firebase conductor document
    print(
        'Passenger count refresh called - current count: $passengerCount (from Firebase)');
  }

  String _getGeofencingStatus() {
    if (_passengersNearDropOff.isEmpty) return 'No passengers near drop-off';

    final readyCount = _passengersNearDropOff.where((p) {
      if (_currentPosition == null) return false;
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        p['toLatitude'] ?? 0,
        p['toLongitude'] ?? 0,
      );
      return distance <= 50;
    }).length;

    final approachingCount = _passengersNearDropOff.length - readyCount;

    if (readyCount > 0 && approachingCount > 0) {
      return '$readyCount ready, $approachingCount approaching';
    } else if (readyCount > 0) {
      return '$readyCount ready for drop-off';
    } else {
      return '$approachingCount approaching drop-off';
    }
  }

  void _manualGeofencingCheck() {
    if (_currentPosition != null &&
        (_activeBookings.isNotEmpty ||
            _activePreTickets.isNotEmpty ||
            _activeManualTickets.isNotEmpty) &&
        _isAppActive &&
        !_isDisposed) {
      _performGeofencingCheck(_currentPosition!);
      _refreshPassengerCount();
    }
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
              icon: Icon(Icons.location_on),
              onPressed: _manualGeofencingCheck,
              tooltip: 'Check Geofencing',
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
                if (_showDropOffBanner && !_isDisposed) _buildDropOffBanner(),
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

  // UPDATED: Build info overlay with three separate sections
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

            // Separate sections for different ticket types and statuses
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                // Paid pre-bookings (waiting to be picked up) - Red markers with real-time tracking
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!, width: 1),
                  ),
                  child: Text('${_activeBookings.where((b) => b['status'] == 'paid' && b['isRealTime'] == true).length} waiting (real-time)',
                      style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Colors.red[800])),
                ),

                // Boarded pre-bookings (on the bus)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!, width: 1),
                  ),
                  child: Text('${_activeBookings.where((b) => b['status'] == 'boarded').length} boarded',
                      style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Colors.green[700])),
                ),

                // Pre-tickets section
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

                // Manual tickets section
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
              if (_showDropOffBanner) ...[
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[300]!, width: 1),
                  ),
                  child: Text(_getGeofencingStatus(),
                      style: GoogleFonts.outfit(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700])),
                ),
              ],
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

  Widget _buildDropOffBanner() {
    return Positioned(
      top: 120,
      left: 16,
      right: 16,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green[400]!, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.green[700], size: 20),
                SizedBox(width: 8),
                Text('Passengers Near Drop-off',
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[800])),
              ],
            ),
            SizedBox(height: 8),
            ..._passengersNearDropOff.take(3).map((passenger) {
              final distance = _currentPosition != null
                  ? Geolocator.distanceBetween(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                      passenger['toLatitude'] ?? 0,
                      passenger['toLongitude'] ?? 0,
                    )
                  : 0.0;

              final ticketType = passenger['ticketType'] ?? 'unknown';
              Color badgeColor = Colors.grey;
              String typeLabel = 'Unknown';

              switch (ticketType) {
                case 'preBooking':
                  badgeColor = Colors.blue;
                  typeLabel = 'Pre-book';
                  break;
                case 'preTicket':
                  badgeColor = Colors.orange;
                  typeLabel = 'Pre-ticket';
                  break;
                case 'manual':
                  badgeColor = Colors.grey;
                  typeLabel = 'Manual';
                  break;
              }

              return Container(
                margin: EdgeInsets.only(bottom: 4),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.green[600], size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${passenger['from']} → ${passenger['to']} (${passenger['quantity']} pax)',
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: Colors.green[700]),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(typeLabel,
                                    style: GoogleFonts.outfit(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            badgeColor.withValues(alpha: 0.7))),
                              ),
                              Spacer(),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('${distance.toStringAsFixed(0)}m',
                                    style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[800])),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            if (_passengersNearDropOff.length > 3) ...[
              Text('... and ${_passengersNearDropOff.length - 3} more',
                  style: GoogleFonts.outfit(
                      fontSize: 10, color: Colors.green[600])),
            ],
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isDisposed
                      ? null
                      : () => setState(() => _showDropOffBanner = false),
                  child: Text('Dismiss',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: Colors.grey[600])),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Add QR scanner method
  void _openQRScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _QRScannerPage(),
      ),
    ).then((result) {
      if (result == true) {
        // Refresh markers and passenger count after successful scan
        _debouncedRefreshMarkers();
        _refreshPassengerCount();
      }
    });
  }
}

// QR Scanner page for conductor maps
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
                  content: Text('Scan failed: ${e.toString().replaceAll('Exception: ', '')}'),
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

// Helper functions for QR code processing (reused from conductor_from.dart)
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

  // Get conductor document
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

  // Validate route match
  if (conductorRoute != route) {
    throw Exception(
        'Invalid route. You are a $conductorRoute conductor but trying to scan a $route ticket. Only $conductorRoute tickets can be scanned.');
  }

  // Check if this is a pre-booking or pre-ticket
  final type = data['type'] ?? '';
  if (type == 'preBooking') {
    await _processPreBooking(data, user, conductorDoc, quantity, qrDataString);
  } else {
    // Validate direction compatibility for pre-tickets
    if (type == 'preTicket') {
      final passengerDirection = data['direction'];
      final passengerPlaceCollection = data['placeCollection'];
      
      if (passengerDirection != null && passengerPlaceCollection != null) {
        final isDirectionCompatible = await DirectionValidationService.validateDirectionCompatibilityByCollection(
          passengerRoute: route,
          passengerPlaceCollection: passengerPlaceCollection,
          conductorUid: user.uid,
        );
        
        if (!isDirectionCompatible) {
          // Get conductor's active trip direction for better error message
          final activeTrip = conductorData['activeTrip'];
          final conductorDirection = activeTrip?['direction'] ?? 'Unknown';
          
          throw Exception(
            'Direction mismatch! Your ticket is for "$passengerDirection" but the conductor is currently on "$conductorDirection" trip. Please wait for the correct direction or contact the conductor.'
          );
        }
      }
    }
    
    await _processPreTicket(data, user, conductorDoc, quantity, qrDataString);
  }
}

Future<void> _processPreBooking(Map<String, dynamic> data, User user, QuerySnapshot conductorDoc, int quantity, String qrDataString) async {
  
  // Find the paid pre-booking
  final preBookingsQuery = await FirebaseFirestore.instance
      .collectionGroup('preBookings')
      .where('qrData', isEqualTo: qrDataString)
      .where('status', isEqualTo: 'paid')
      .get();

  if (preBookingsQuery.docs.isEmpty) {
    throw Exception('No paid pre-booking found with this QR code. Please ensure payment is completed.');
  }

  final paidPreBooking = preBookingsQuery.docs.first;
  final preBookingData = paidPreBooking.data();

  // Check if already boarded
  if (preBookingData['status'] == 'boarded' || preBookingData['boardingStatus'] == 'boarded') {
    throw Exception('This pre-booking has already been scanned and boarded.');
  }

  // Update pre-booking status to "boarded"
  await paidPreBooking.reference.update({
    'status': 'boarded',
    'boardedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'scannedAt': FieldValue.serverTimestamp(),
    'boardingStatus': 'boarded',
    // Stop real-time location tracking by removing location update fields
    'locationTrackingStopped': true,
    'locationTrackingStoppedAt': FieldValue.serverTimestamp(),
  });

  // Store in conductor's preBookings collection
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

  // Increment passenger count
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .update({'passengerCount': FieldValue.increment(quantity)});
}

Future<void> _processPreTicket(Map<String, dynamic> data, User user, QuerySnapshot conductorDoc, int quantity, String qrDataString) async {
  
  // Find the pending pre-ticket
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

  // Check if already boarded
  if (preTicketData['status'] == 'boarded') {
    throw Exception('This pre-ticket has already been scanned and boarded.');
  }

  // Update pre-ticket status to "boarded"
  await pendingPreTicket.reference.update({
    'status': 'boarded',
    'boardedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'scannedAt': FieldValue.serverTimestamp(),
  });

  // Store in conductor's preTickets collection
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

  // Increment passenger count
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .update({'passengerCount': FieldValue.increment(quantity)});
}
