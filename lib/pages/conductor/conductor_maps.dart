import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:b_go/pages/conductor/destination_service.dart';
import 'package:b_go/pages/conductor/passenger_status_service.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/services.dart';

class ConductorMaps extends StatefulWidget {
  final String route;
  final String role;

  const ConductorMaps({super.key, required this.route, required this.role});

  @override
  State<ConductorMaps> createState() => _ConductorMapsState();
}

class _ConductorMapsState extends State<ConductorMaps> with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  int passengerCount = 0;
  List<Map<String, dynamic>> _activeBookings = [];
  List<Map<String, dynamic>> _activeManualTickets = [];
  List<Map<String, dynamic>> _routeDestinations = [];
  Timer? _locationTimer;
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _conductorSubscription;
  StreamSubscription<QuerySnapshot>? _bookingsSubscription;
  StreamSubscription<QuerySnapshot>? _manualTicketsSubscription;
  
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
  static const Duration _geofencingCooldown = Duration(seconds: 10); // Reduced cooldown
  Timer? _debounceTimer;
  
  // Memory optimization
  Set<Marker> _cachedMarkers = {};
  String _lastMarkerCacheKey = '';
  
  // Performance flags
  bool _isUpdatingLocation = false;
  bool _isProcessingBookings = false;
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
    _cleanupResources();
    super.dispose();
  }

  void _cleanupResources() {
    _isDisposed = true;
    
    // Cancel all timers and subscriptions
    _locationTimer?.cancel();
    _debounceTimer?.cancel();
    _bookingsSubscription?.cancel();
    _conductorSubscription?.cancel();
    _manualTicketsSubscription?.cancel();
    
    // Dispose map controller safely
    _mapController?.dispose();
    _mapController = null;
    
    // Clear data structures
    _activeBookings.clear();
    _activeManualTickets.clear();
    _routeDestinations.clear();
    _passengersNearDropOff.clear();
    _cachedMarkers.clear();
    
    // Reset flags
    _isUpdatingLocation = false;
    _isProcessingBookings = false;
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
      _updateCurrentLocation();
    });
  }

  Future<void> _updateCurrentLocation() async {
    if (_isUpdatingLocation || !_isAppActive || _isDisposed) return;
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
        
        // Perform geofencing check with cooldown
        _performGeofencingCheck(position);
      }
    } catch (e) {
      print('Location update error: $e');
    } finally {
      _isUpdatingLocation = false;
    }
  }

  // FIXED: Improved geofencing logic with proper coordinate lookup
  void _performGeofencingCheck(Position currentPosition) {
    if (_isDisposed || (_activeBookings.isEmpty && _activeManualTickets.isEmpty)) return;
    
    final now = DateTime.now();
    if (_lastGeofencingCheck != null && 
        now.difference(_lastGeofencingCheck!) < _geofencingCooldown) {
      return;
    }
    _lastGeofencingCheck = now;
    
    List<Map<String, dynamic>> passengersNear = [];
    List<Map<String, dynamic>> readyForDropOff = [];
    
    // Check pre-bookings
    for (final booking in _activeBookings) {
      final toLat = booking['toLatitude'];
      final toLng = booking['toLongitude'];
      
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
    
    // FIXED: Check manual tickets with coordinate lookup
    for (final ticket in _activeManualTickets) {
      double? toLat = ticket['toLatitude'];
      double? toLng = ticket['toLongitude'];
      
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
    
    print('Geofencing check: ${_activeBookings.length} pre-bookings, ${_activeManualTickets.length} manual tickets');
    print('Found ${passengersNear.length} passengers near drop-off, ${readyForDropOff.length} ready for drop-off');
    
    // Update UI
    if (mounted && !_isDisposed) {
      setState(() {
        _passengersNearDropOff = passengersNear + readyForDropOff;
        _showDropOffBanner = _passengersNearDropOff.isNotEmpty;
      });
    }
    
    // Process ready passengers for automatic drop-off
    _processReadyPassengers(readyForDropOff);
  }

  // FIXED: Process passengers ready for drop-off
  void _processReadyPassengers(List<Map<String, dynamic>> readyPassengers) {
    if (_isDisposed || readyPassengers.isEmpty) return;
    
    for (final passenger in readyPassengers) {
      final passengerId = passenger['id'];
      final quantity = passenger['quantity'] ?? 1;
      final from = passenger['from'];
      final to = passenger['to'];
      final ticketType = passenger['ticketType'];

      print('Auto-dropping off passenger: $passengerId (quantity: $quantity) from $from to $to (type: $ticketType)');

      // Update status and decrement count
      if (ticketType == 'preBooking') {
        // Remove from active bookings
        if (mounted && !_isDisposed) {
          setState(() {
            _activeBookings.removeWhere((booking) => booking['id'] == passengerId);
            passengerCount = math.max(0, passengerCount - (quantity is int ? quantity : (quantity as num).toInt()));
          });
        }
        _updatePreBookingStatus(passengerId, 'dropped_off');
      } else if (ticketType == 'manual') {
        // Remove from active manual tickets  
        if (mounted && !_isDisposed) {
          setState(() {
            _activeManualTickets.removeWhere((ticket) => ticket['id'] == passengerId);
            passengerCount = math.max(0, passengerCount - (quantity is int ? quantity : (quantity as num).toInt()));
          });
        }
        _updateManualTicketStatus(passengerId, 'dropped_off', passenger);
      }
      
      _showDropOffNotification(passengerId, from, to, quantity);
      print('Passenger count after drop-off: $passengerCount');
    }
    
    // Update conductor passenger count in Firebase
    _updateConductorPassengerCount();
    _debouncedRefreshMarkers();
  }

  // FIXED: Update pre-booking status
  Future<void> _updatePreBookingStatus(String passengerId, String status) async {
    if (_isDisposed) return;
    
    try {
      final query = await FirebaseFirestore.instance
          .collectionGroup('preBookings')
          .where(FieldPath.documentId, isEqualTo: passengerId)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({
          'status': status,
          'dropOffTimestamp': FieldValue.serverTimestamp(),
          'dropOffLocation': _currentPosition != null ? {
            'latitude': _currentPosition!.latitude,
            'longitude': _currentPosition!.longitude,
          } : null,
        });
      }
    } catch (e) {
      print('Error updating pre-booking status: $e');
    }
  }

  // FIXED: Update manual ticket status
  Future<void> _updateManualTicketStatus(String ticketId, String status, Map<String, dynamic> ticketData) async {
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
          'dropOffLocation': _currentPosition != null ? {
            'latitude': _currentPosition!.latitude,
            'longitude': _currentPosition!.longitude,
          } : null,
        });
      }
    } catch (e) {
      print('Error updating manual ticket status: $e');
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
          
      if (query.docs.isNotEmpty) {
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

  void _showDropOffNotification(String passengerId, String from, String to, int quantity) {
    if (!mounted || _isDisposed) return;
    
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
                  Text('$from → $to (${quantity > 1 ? '$quantity passengers' : '1 passenger'})',
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70)),
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
  }

  void _showErrorNotification(String message) {
    if (!mounted || _isDisposed) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
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
          print('Synced passenger count from Firebase: $firebasePassengerCount');
        }
        
        bool shouldRefresh = false;
        if (activeTrip != null && activeTrip['isActive'] == true) {
          final newDirection = activeTrip['direction'];
          final newPlaceCollection = activeTrip['placeCollection'];
          
          if (_activeTripDirection != newDirection || _activePlaceCollection != newPlaceCollection) {
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

  // FIXED: Load manual tickets with proper status filtering
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
      final formattedDate = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      _manualTicketsSubscription?.cancel();
      _manualTicketsSubscription = FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('remittance')
          .doc(formattedDate)
          .collection('tickets')
          .where('ticketType', isEqualTo: 'manual')
          .where('status', isEqualTo: 'boarded') // FIXED: Only get boarded tickets
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
              'toLatitude': toCoords?['latitude'] ?? _convertToDouble(data['toLatitude']),
              'toLongitude': toCoords?['longitude'] ?? _convertToDouble(data['toLongitude']),
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
    _bookingsSubscription = FirebaseFirestore.instance
        .collectionGroup('preBookings')
        .where('route', isEqualTo: widget.route)
        .where('status', whereIn: ['paid', 'pending_payment', 'boarded', 'dropped_off', 'accomplished'])
        .snapshots()
        .listen((snapshot) {
      if (_isDisposed || !mounted || !_isAppActive) {
        _isProcessingBookings = false;
        return;
      }
      
      try {
        // FIXED: Only include bookings that are currently "boarded" status for geofencing
        final preBookings = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? '';
          
          // Only include boarded passengers for geofencing
          return status == 'boarded';
        }).toList();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isDisposed || !mounted || !_isAppActive) {
            _isProcessingBookings = false;
            return;
          }
          
          setState(() {
            _activeBookings = preBookings.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final quantity = (data['quantity'] ?? 1) as int;

              return {
                'id': doc.id,
                'from': data['from'],
                'to': data['to'],
                'quantity': quantity,
                'fromLatitude': _convertToDouble(data['fromLatitude']),
                'fromLongitude': _convertToDouble(data['fromLongitude']),
                'toLatitude': _convertToDouble(data['toLatitude']),
                'toLongitude': _convertToDouble(data['toLongitude']),
                'passengerLatitude': _convertToDouble(data['passengerLatitude']),
                'passengerLongitude': _convertToDouble(data['passengerLongitude']),
                'status': data['status'] ?? 'boarded',
              };
            }).toList();
          });
          
          _debouncedRefreshMarkers();
          _isProcessingBookings = false;
        });
      } catch (e) {
        print('Error processing bookings: $e');
        _isProcessingBookings = false;
      }
    });
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
          _routeDestinations = destinations;
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
    
    final cacheKey = '${_currentPosition?.latitude}_${_currentPosition?.longitude}_${_activeBookings.length}_${_routeDestinations.length}_$_activePlaceCollection';
    
    if (cacheKey == _lastMarkerCacheKey && _cachedMarkers.isNotEmpty) {
      return _cachedMarkers;
    }
    
    final Set<Marker> markers = {};

    // Add conductor marker
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

    // Add route markers
    if (_routeDestinations.isNotEmpty) {
      final routeMarkers = _createRouteMarkers();
      markers.addAll(routeMarkers);
    }

    // Add passenger markers (limited)
    int passengerMarkerCount = 0;
    const maxPassengerMarkers = 15;
    
    for (final booking in _activeBookings) {
      if (passengerMarkerCount >= maxPassengerMarkers) break;
      
      final passengerLat = booking['passengerLatitude'] ?? 0.0;
      final passengerLng = booking['passengerLongitude'] ?? 0.0;

      if (passengerLat != 0.0 && passengerLng != 0.0) {
        markers.add(
          Marker(
            markerId: MarkerId('passenger_${booking['id']}'),
            position: LatLng(passengerLat, passengerLng),
            infoWindow: InfoWindow(
              title: 'Pre-booked Passenger',
              snippet: '${booking['from']} → ${booking['to']} (${booking['quantity']} passengers)',
            ),
            icon: _getHumanIcon(),
          ),
        );
        passengerMarkerCount++;
      }
    }
    
    _cachedMarkers = markers;
    _lastMarkerCacheKey = cacheKey;
    
    return markers;
  }

  Set<Marker> _createRouteMarkers() {
    final Set<Marker> markers = {};
    const maxRouteMarkers = 25;
    
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

    final limitedDestinations = filteredDestinations.take(maxRouteMarkers).toList();
    
    for (final destination in limitedDestinations) {
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
    print('Passenger count refresh called - current count: $passengerCount (from Firebase)');
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
    if (_currentPosition != null && (_activeBookings.isNotEmpty || _activeManualTickets.isNotEmpty) && _isAppActive && !_isDisposed) {
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
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70)),
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
        title: Text("Maps", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w500)),
        backgroundColor: Color(0xFF0091AD),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          if (_currentPosition != null && !_isDisposed) ...[
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
                      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
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
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[500])),
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
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$passengerCount passengers',
                style: GoogleFonts.outfit(
                    fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0091AD))),
            Text('${_activeBookings.length} pre-bookings, ${_activeManualTickets.length} manual',
                style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey[600])),
            if (_routeDestinations.isNotEmpty) ...[
              SizedBox(height: 4),
              Text('Route: ${widget.route}',
                  style: GoogleFonts.outfit(
                      fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey[700])),
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
                          fontSize: 8, fontWeight: FontWeight.w600, color: Colors.green[700])),
                ),
              ],
              if (_activeTripDirection != null) ...[
                Container(
                  margin: EdgeInsets.only(top: 2),
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _activePlaceCollection == 'Place' ? Colors.blue[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _activePlaceCollection == 'Place' ? Colors.blue[300]! : Colors.orange[300]!,
                        width: 1),
                  ),
                  child: Text('$_activeTripDirection',
                      style: GoogleFonts.outfit(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: _activePlaceCollection == 'Place' ? Colors.blue[700] : Colors.orange[700])),
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
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
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
                        fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green[800])),
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
                      child: Text(
                        '${passenger['from']} → ${passenger['to']} (${passenger['quantity']} pax)',
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.green[700]),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${distance.toStringAsFixed(0)}m',
                          style: GoogleFonts.outfit(
                              fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green[800])),
                    ),
                  ],
                ),
              );
            }).toList(),
            if (_passengersNearDropOff.length > 3) ...[
              Text('... and ${_passengersNearDropOff.length - 3} more',
                  style: GoogleFonts.outfit(fontSize: 10, color: Colors.green[600])),
            ],
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isDisposed ? null : () => setState(() => _showDropOffBanner = false),
                  child: Text('Dismiss',
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600])),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}