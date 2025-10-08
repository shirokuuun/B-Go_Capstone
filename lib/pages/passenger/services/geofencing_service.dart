import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'dart:async';

class GeofencingService {
  static final GeofencingService _instance = GeofencingService._internal();
  factory GeofencingService() => _instance;
  GeofencingService._internal();

  StreamSubscription<Position>? _locationSubscription;
  Timer? _geofencingTimer;
  bool _isMonitoring = false;
  bool _isConductorMode = false;
  String? _conductorRoute;
  String? _conductorDocId;
  
  // Configuration
  static const double _geofenceRadius = 250.0; // 250 meters for drop-off detection
  static const Duration _checkInterval = Duration(seconds: 30);
  static const double _locationAccuracyThreshold = 50.0;
  static const Duration _minProcessingInterval = Duration(seconds: 10);

  // Add tracking for last processing times to prevent excessive processing
  final Map<String, DateTime> _lastProcessedDestinations = {};

  /// Start monitoring passenger location for geofencing
  Future<void> startMonitoring() async {
    // CRITICAL: Stop any existing monitoring first
    if (_isMonitoring) {
      print('⚠️ Geofencing already running, stopping first...');
      stopMonitoring();
      await Future.delayed(Duration(milliseconds: 500)); // Wait for cleanup
    }

    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permission permanently denied');
        return;
      }

      // IMPORTANT: Set passenger mode flags BEFORE starting monitoring
      _isConductorMode = false;
      _conductorRoute = null;
      _conductorDocId = null;

      print('🚀 Starting PASSENGER mode geofencing...');
      print('🔧 Mode check: _isConductorMode=$_isConductorMode');

      // Start location monitoring
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5,
          timeLimit: Duration(seconds: 10),
        ),
      ).listen((Position position) {
        if (position.accuracy <= _locationAccuracyThreshold) {
          _checkGeofencing(position);
        }
      });

      // Also check periodically for better reliability
      _geofencingTimer = Timer.periodic(_checkInterval, (timer) async {
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 10),
          );
          if (position.accuracy <= _locationAccuracyThreshold) {
            _checkGeofencing(position);
          }
        } catch (e) {
          print('Error getting current position: $e');
        }
      });

      _isMonitoring = true;
      print('✅ Passenger geofencing monitoring started successfully');
      print('🔧 Final state: _isMonitoring=$_isMonitoring, _isConductorMode=$_isConductorMode');
    } catch (e) {
      print('❌ Error starting passenger geofencing: $e');
    }
  }

  /// Start conductor-based geofencing monitoring
  Future<void> startConductorMonitoring(String route, String conductorDocId) async {
    // CRITICAL: Stop any existing monitoring first
    if (_isMonitoring) {
      print('⚠️ Geofencing already running, stopping first...');
      stopMonitoring();
      await Future.delayed(Duration(milliseconds: 500)); // Wait for cleanup
    }

    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permission permanently denied');
        return;
      }

      // IMPORTANT: Set conductor mode flags BEFORE starting monitoring
      _isConductorMode = true;
      _conductorRoute = route;
      _conductorDocId = conductorDocId;

      print('🚀 Starting CONDUCTOR mode geofencing...');
      print('🔧 Mode check: _isConductorMode=$_isConductorMode, route=$route, docId=$conductorDocId');

      // Start location monitoring
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 10,
          timeLimit: Duration(seconds: 15),
        ),
      ).listen((Position position) {
        print('📍 Geofencing: Received position update - lat: ${position.latitude}, lng: ${position.longitude}, accuracy: ${position.accuracy}m');
        if (position.accuracy <= _locationAccuracyThreshold) {
          print('✅ Geofencing: Position accuracy acceptable (${position.accuracy}m <= ${_locationAccuracyThreshold}m), checking geofencing...');
          _checkConductorGeofencing(position);
        } else {
          print('⚠️ Geofencing: Position accuracy too poor (${position.accuracy}m > ${_locationAccuracyThreshold}m), skipping...');
        }
      });

      // Also check periodically for better reliability
      _geofencingTimer = Timer.periodic(_checkInterval, (timer) async {
        try {
          print('⏰ Geofencing: Periodic check triggered (every ${_checkInterval.inSeconds}s)');
          _cleanupOldProcessedDestinations();

          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 15),
          );
          print('📍 Geofencing: Periodic position - lat: ${position.latitude}, lng: ${position.longitude}, accuracy: ${position.accuracy}m');
          if (position.accuracy <= _locationAccuracyThreshold) {
            print('✅ Geofencing: Periodic position accuracy acceptable, checking geofencing...');
            _checkConductorGeofencing(position);
          } else {
            print('⚠️ Geofencing: Periodic position accuracy too poor, skipping...');
          }
        } catch (e) {
          print('❌ Geofencing: Error getting current position: $e');
        }
      });

      _isMonitoring = true;
      print('✅ Conductor geofencing monitoring started for route: $route');
      print('🔧 Geofencing config: radius=${_geofenceRadius}m, accuracy≤${_locationAccuracyThreshold}m, interval=${_checkInterval.inSeconds}s');
      print('🔧 Final state: _isMonitoring=$_isMonitoring, _isConductorMode=$_isConductorMode');
    } catch (e) {
      print('❌ Error starting conductor geofencing: $e');
    }
  }

  /// Stop monitoring passenger location
  void stopMonitoring() {
    _locationSubscription?.cancel();
    _geofencingTimer?.cancel();
    _isMonitoring = false;
    _isConductorMode = false;
    _conductorRoute = null;
    _conductorDocId = null;
    _lastProcessedDestinations.clear();
    print('🛑 Geofencing monitoring stopped');
  }

  /// Check if passenger has reached any destination (passenger mode)
  Future<void> _checkGeofencing(Position passengerPosition) async {
    // CRITICAL: Double-check we're not in conductor mode
    if (_isConductorMode) {
      print('⚠️ Skipping passenger geofencing - in conductor mode');
      return;
    }
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('⚠️ No user logged in, skipping geofencing');
      return;
    }

    try {
      print('🔍 Passenger geofencing check started');
      print('📍 Position: ${passengerPosition.latitude}, ${passengerPosition.longitude}');
      print('🔧 Mode: _isConductorMode=$_isConductorMode');
      
      // Get all active pre-tickets for the current user - ONLY 'boarded' status
      final preTicketsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preTickets')
          .where('status', isEqualTo: 'boarded')  // CRITICAL: Only boarded
          .get();

      print('🎫 Found ${preTicketsSnapshot.docs.length} boarded pre-tickets');

      for (var doc in preTicketsSnapshot.docs) {
        final ticket = doc.data();
        final destinationName = ticket['to'];
        final route = ticket['route'];
        
        print('🔍 Checking pre-ticket ${doc.id}: to=$destinationName, status=${ticket['status']}');
        
        if (destinationName != null && route != null) {
          final destinationCoords = await _getDestinationCoordinates(destinationName, route);
          
          if (destinationCoords != null) {
            final lat = destinationCoords['latitude'];
            final lng = destinationCoords['longitude'];
            if (lat != null && lng != null) {
              final distance = Geolocator.distanceBetween(
                passengerPosition.latitude,
                passengerPosition.longitude,
                lat,
                lng,
              );

              print('📍 Distance to $destinationName: ${distance.toStringAsFixed(1)}m');

              if (distance <= _geofenceRadius) {
                await _markTicketAccomplished(doc.id, user.uid, passengerPosition);
                print('🎯 Pre-ticket accomplished: Passenger reached ${destinationName} (${distance.toStringAsFixed(1)}m away)');
              }
            }
          }
        }
      }

      // Check pre-bookings - CRITICAL: ONLY 'boarded' status
      final preBookingsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .where('status', isEqualTo: 'boarded')  // CRITICAL: Only boarded, NOT paid
          .get();

      print('📚 Found ${preBookingsSnapshot.docs.length} boarded pre-bookings');

      for (var doc in preBookingsSnapshot.docs) {
        final booking = doc.data();
        final destinationName = booking['to'];
        final route = booking['route'];
        
        print('🔍 Checking pre-booking ${doc.id}: to=$destinationName, status=${booking['status']}');
        
        if (destinationName != null && route != null) {
          final destinationCoords = await _getDestinationCoordinates(destinationName, route);
          
          if (destinationCoords != null) {
            final lat = destinationCoords['latitude'];
            final lng = destinationCoords['longitude'];
            if (lat != null && lng != null) {
              final distance = Geolocator.distanceBetween(
                passengerPosition.latitude,
                passengerPosition.longitude,
                lat,
                lng,
              );

              print('📍 Distance to $destinationName: ${distance.toStringAsFixed(1)}m (threshold: ${_geofenceRadius}m)');

              if (distance <= _geofenceRadius) {
                await _markPreBookingAccomplished(doc.id, user.uid, passengerPosition);
                print('🎯 Pre-booking accomplished: Passenger reached ${destinationName} (${distance.toStringAsFixed(1)}m away)');
              }
            }
          }
        }
      }
      
      print('✅ Passenger geofencing check completed');
    } catch (e) {
      print('❌ Error in passenger geofencing check: $e');
    }
  }

  /// Check conductor geofencing for passenger drop-offs (conductor mode)
  Future<void> _checkConductorGeofencing(Position conductorPosition) async {
    print('🔧 _checkConductorGeofencing called: _isConductorMode=$_isConductorMode, route=$_conductorRoute, docId=$_conductorDocId');

    if (!_isConductorMode || _conductorRoute == null || _conductorDocId == null) {
      print('❌ Geofencing check skipped - not in conductor mode or missing data');
      return;
    }

    try {
      print('🔍 Checking conductor geofencing for route: $_conductorRoute at ${DateTime.now()}');
      print('📍 Conductor position: ${conductorPosition.latitude}, ${conductorPosition.longitude}');
      
      // Get all boarded passengers for this conductor
      final conductorDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(_conductorDocId!)
          .get();

      if (!conductorDoc.exists) {
        print('❌ Conductor document not found');
        return;
      }

      final conductorData = conductorDoc.data() as Map<String, dynamic>;
      final currentPassengerCount = conductorData['passengerCount'] ?? 0;

      print('👥 Current passenger count: $currentPassengerCount');

      if (currentPassengerCount <= 0) {
        print('ℹ️ No passengers to check for drop-off');
        return;
      }

      // Get all active tickets for this conductor from remittance collection
      final remittanceSnapshot = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(_conductorDocId!)
          .collection('remittance')
          .get();

      print('📋 Found ${remittanceSnapshot.docs.length} date documents in remittance');

      // Get the current active trip ID to filter tickets
      final activeTripId = conductorData['activeTrip']?['tripId'];
      print('🔍 Current active trip ID: $activeTripId');

      int totalDecremented = 0;
      Set<String> processedManualDestinations = {};  // Track manual tickets separately
      Set<String> processedPreBookingDestinations = {};  // Track pre-bookings separately

      for (var dateDoc in remittanceSnapshot.docs) {
        final ticketsCollection = dateDoc.reference.collection('tickets');
        final tickets = await ticketsCollection.get();

        for (var ticketDoc in tickets.docs) {
          final ticket = ticketDoc.data();
          final destinationName = ticket['to'];
          final isActive = ticket['active'] ?? false;
          final ticketTripId = ticket['tripId'];  // Get the trip ID from the ticket
          final ticketKey = '${destinationName}_${ticketDoc.id}';  // Unique key per ticket
          
          // CRITICAL FIX: Only process tickets from the current active trip
          if (isActive && 
              destinationName != null && 
              !processedManualDestinations.contains(ticketKey) &&
              ticketTripId == activeTripId) {  // Filter by current trip ID
            final destinationCoords = await _getDestinationCoordinates(destinationName, _conductorRoute!);
            
            if (destinationCoords != null) {
              final lat = destinationCoords['latitude'];
              final lng = destinationCoords['longitude'];
              if (lat != null && lng != null) {
                final distance = Geolocator.distanceBetween(
                  conductorPosition.latitude,
                  conductorPosition.longitude,
                  lat,
                  lng,
                );

                print('🎯 Destination $destinationName: ${distance.toStringAsFixed(1)}m away (tripId: $ticketTripId)');

                if (distance <= _geofenceRadius) {
                  final alreadyProcessed = ticket['active'] == false || ticket['status'] == 'completed';

                  if (alreadyProcessed) {
                    print('⏭️ Skipping $destinationName - already processed (active=${ticket['active']}, status=${ticket['status']})');
                    continue;
                  }

                  if (await _isApproachingDestination(conductorPosition, lat, lng)) {
                    final quantity = (ticket['quantity'] as num?)?.toInt() ?? 1;
                    await _markConductorTicketCompleted(ticketDoc.reference, quantity);
                    totalDecremented += quantity;
                    processedManualDestinations.add(ticketKey);
                    print('🎯 Conductor reached ${destinationName}: ${quantity} passenger(s) dropped off (${distance.toStringAsFixed(1)}m away)');
                  } else {
                    print('⚠️ Within geofence radius but not approaching destination');
                  }
                }
              }
            } else {
              print('❌ Could not get coordinates for destination: $destinationName');
            }
          } else if (isActive && ticketTripId != activeTripId) {
            print('⏭️ Skipping ticket for $destinationName - belongs to different trip (ticket tripId: $ticketTripId, active tripId: $activeTripId)');
          }
        }
      }

      // Check pre-bookings - also filter by current trip
      final preBookingsSnapshot = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(_conductorDocId!)
          .collection('preBookings')
          .where('status', isEqualTo: 'boarded')
          .get();

      print('📚 Found ${preBookingsSnapshot.docs.length} boarded pre-bookings');

      for (var doc in preBookingsSnapshot.docs) {
        final booking = doc.data();
        final destinationName = booking['data']?['to'] ?? booking['to'];
        final bookingKey = '${destinationName}_${doc.id}';  // Unique key per booking
        final bookingTripId = booking['tripId'];  // Get trip ID from booking

        // CRITICAL FIX: Only process pre-bookings from current trip
        if (bookingTripId != activeTripId) {
          print('⏭️ SKIPPING pre-booking ${doc.id} - belongs to different trip (booking tripId: $bookingTripId, active tripId: $activeTripId)');
          continue;
        }

        // CRITICAL FIX: Check if already dropped off by checking for completion timestamps
        final hasDropOffTimestamp = booking['dropOffTimestamp'] != null;
        final hasCompletedAt = booking['completedAt'] != null;
        final currentStatus = booking['status'] ?? '';
        
        if (hasDropOffTimestamp || hasCompletedAt || 
            currentStatus == 'completed' || currentStatus == 'accomplished') {
          print('⏭️ SKIPPING pre-booking ${doc.id} - already dropped off (status=$currentStatus, hasDropOffTimestamp=$hasDropOffTimestamp, hasCompletedAt=$hasCompletedAt)');
          continue;
        }

        // FIXED: Try multiple possible quantity fields
        int quantity = 1;
        if (booking['data']?['quantity'] != null) {
          quantity = (booking['data']['quantity'] as num).toInt();
        } else if (booking['quantity'] != null) {
          quantity = (booking['quantity'] as num).toInt();
        } else if (booking['data']?['numberOfPassengers'] != null) {
          quantity = (booking['data']['numberOfPassengers'] as num).toInt();
        }

        print('📖 Pre-booking ${doc.id}: to=$destinationName, quantity=$quantity, tripId=$bookingTripId (from data: ${booking['data']?['quantity']}, direct: ${booking['quantity']})');
        
        if (destinationName != null && !processedPreBookingDestinations.contains(bookingKey)) {
          final destinationCoords = await _getDestinationCoordinates(destinationName, _conductorRoute!);
          
          if (destinationCoords != null) {
            final lat = destinationCoords['latitude'];
            final lng = destinationCoords['longitude'];
            if (lat != null && lng != null) {
              final distance = Geolocator.distanceBetween(
                conductorPosition.latitude,
                conductorPosition.longitude,
                lat,
                lng,
              );

              print('🎯 Pre-booking destination $destinationName: ${distance.toStringAsFixed(1)}m away');

              if (distance <= _geofenceRadius) {
                if (await _isApproachingDestination(conductorPosition, lat, lng)) {
                  final qty = (quantity as num?)?.toInt() ?? 1;
                  await _markPreBookingCompleted(doc.reference, qty);
                  totalDecremented += qty;
                  processedPreBookingDestinations.add(bookingKey);
                  print('🎯 Pre-booking completed: ${qty} passenger(s) dropped off at ${destinationName} (${distance.toStringAsFixed(1)}m away)');
                } else {
                  print('⚠️ Pre-booking within geofence radius but not approaching destination');
                }
              }
            }
          } else {
            print('❌ Could not get coordinates for pre-booking destination: $destinationName');
          }
        }
      }

      // Check pre-tickets - also filter by current trip
      final preTicketsSnapshot = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(_conductorDocId!)
          .collection('preTickets')
          .where('status', isEqualTo: 'boarded')
          .get();

      print('🎫 Found ${preTicketsSnapshot.docs.length} boarded pre-tickets');

      for (var doc in preTicketsSnapshot.docs) {
        final ticket = doc.data();
        final destinationName = ticket['data']?['to'] ?? ticket['to'];
        final ticketKey = '${destinationName}_${doc.id}';  // Unique key per ticket
        final ticketTripId = ticket['tripId'];  // Get trip ID from ticket

        // CRITICAL FIX: Only process pre-tickets from current trip
        if (ticketTripId != activeTripId) {
          print('⏭️ SKIPPING pre-ticket ${doc.id} - belongs to different trip (ticket tripId: $ticketTripId, active tripId: $activeTripId)');
          continue;
        }

        // CRITICAL FIX: Check if already dropped off by checking for completion timestamps
        final hasDropOffTimestamp = ticket['dropOffTimestamp'] != null;
        final hasCompletedAt = ticket['completedAt'] != null;
        final currentStatus = ticket['status'] ?? '';
        
        if (hasDropOffTimestamp || hasCompletedAt || 
            currentStatus == 'completed' || currentStatus == 'accomplished') {
          print('⏭️ SKIPPING pre-ticket ${doc.id} - already dropped off (status=$currentStatus, hasDropOffTimestamp=$hasDropOffTimestamp, hasCompletedAt=$hasCompletedAt)');
          continue;
        }

        // FIXED: Try multiple possible quantity fields
        int quantity = 1;
        if (ticket['data']?['quantity'] != null) {
          quantity = (ticket['data']['quantity'] as num).toInt();
        } else if (ticket['quantity'] != null) {
          quantity = (ticket['quantity'] as num).toInt();
        } else if (ticket['data']?['numberOfPassengers'] != null) {
          quantity = (ticket['data']['numberOfPassengers'] as num).toInt();
        }

        print('🎫 Pre-ticket ${doc.id}: to=$destinationName, quantity=$quantity, tripId=$ticketTripId (from data: ${ticket['data']?['quantity']}, direct: ${ticket['quantity']})');
        
        if (destinationName != null && !processedPreBookingDestinations.contains(ticketKey)) {
          final destinationCoords = await _getDestinationCoordinates(destinationName, _conductorRoute!);
          
          if (destinationCoords != null) {
            final lat = destinationCoords['latitude'];
            final lng = destinationCoords['longitude'];
            if (lat != null && lng != null) {
              final distance = Geolocator.distanceBetween(
                conductorPosition.latitude,
                conductorPosition.longitude,
                lat,
                lng,
              );

              print('🎯 Pre-ticket destination $destinationName: ${distance.toStringAsFixed(1)}m away');

              if (distance <= _geofenceRadius) {
                if (await _isApproachingDestination(conductorPosition, lat, lng)) {
                  final qty = (quantity as num?)?.toInt() ?? 1;
                  await _markPreTicketCompleted(doc.reference, qty);
                  totalDecremented += qty;
                  processedPreBookingDestinations.add(ticketKey);
                  print('🎯 Pre-ticket completed: ${qty} passenger(s) dropped off at ${destinationName} (${distance.toStringAsFixed(1)}m away)');
                } else {
                  print('⚠️ Pre-ticket within geofence radius but not approaching destination');
                }
              }
            }
          } else {
            print('❌ Could not get coordinates for pre-ticket destination: $destinationName');
          }
        }
      }

      if (totalDecremented > 0) {
        // Calculate new passenger count and ensure it doesn't go negative
        final newPassengerCount = (currentPassengerCount - totalDecremented).clamp(0, double.infinity).toInt();
        final actualDecrement = currentPassengerCount - newPassengerCount;
        
        if (actualDecrement != totalDecremented) {
          print('⚠️ Adjusted decrement from $totalDecremented to $actualDecrement to prevent negative count');
        }
        
        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(_conductorDocId!)
            .update({
          'passengerCount': newPassengerCount,
          'lastDropOff': FieldValue.serverTimestamp(),
        });
        
        print('✅ Total passengers dropped off: $actualDecrement (requested: $totalDecremented)');
        print('✅ Conductor passenger count updated: $currentPassengerCount → $newPassengerCount');
      } else {
        print('ℹ️ No passengers dropped off in this geofencing check');
      }

    } catch (e) {
      print('❌ Error in conductor geofencing check: $e');
    }
  }

  /// Check if the conductor is actually approaching the destination
  Future<bool> _isApproachingDestination(Position currentPosition, double destLat, double destLng) async {
    try {
      final conductorDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(_conductorDocId!)
          .get();
      
      if (!conductorDoc.exists) return true;
      
      final conductorData = conductorDoc.data() as Map<String, dynamic>;
      final lastPosition = conductorData['lastPosition'] as Map<String, dynamic>?;
      
      if (lastPosition == null) return true;
      
      final lastLat = lastPosition['latitude'] as num?;
      final lastLng = lastPosition['longitude'] as num?;
      
      if (lastLat == null || lastLng == null) return true;
      
      final currentDistance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        destLat,
        destLng,
      );
      
      final previousDistance = Geolocator.distanceBetween(
        lastLat.toDouble(),
        lastLng.toDouble(),
        destLat,
        destLng,
      );
      
      final tolerance = 5.0;
      final isApproaching = currentDistance < (previousDistance - tolerance);
      
      final positionChange = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        lastLat.toDouble(),
        lastLng.toDouble(),
      );
      
      if (positionChange > 10.0) {
        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(_conductorDocId!)
            .update({
          'lastPosition': {
            'latitude': currentPosition.latitude,
            'longitude': currentPosition.longitude,
            'timestamp': FieldValue.serverTimestamp(),
          },
        });
      }
      
      return isApproaching;
    } catch (e) {
      print('Error checking if approaching destination: $e');
      return true;
    }
  }

  /// Get destination coordinates from route data or geocoding
  Future<Map<String, double>?> _getDestinationCoordinates(String destinationName, String route) async {
    try {
      final places = await RouteService.fetchPlaces(route, placeCollection: 'Place');
      final places2 = await RouteService.fetchPlaces(route, placeCollection: 'Place 2');

      final allPlaces = [...places, ...places2];

      print('🔍 Looking for coordinates for destination: "$destinationName" in route: $route');

      final destinationPlace = allPlaces.firstWhere(
        (place) => place['name'] == destinationName,
        orElse: () => {},
      );

      if (destinationPlace.isNotEmpty) {
        print('✅ Found destination place: $destinationPlace');

        final lat = destinationPlace['latitude'];
        final lng = destinationPlace['longitude'];

        if (lat != null && lng != null) {
          try {
            final latValue = (lat as num).toDouble();
            final lngValue = (lng as num).toDouble();
            print('✅ Extracted coordinates: lat=$latValue, lng=$lngValue');
            return {
              'latitude': latValue,
              'longitude': lngValue,
            };
          } catch (e) {
            print('❌ Error converting coordinates: $e');
          }
        } else {
          print('⚠️ Destination place found but coordinates are null');
        }
      } else {
        print('❌ Destination "$destinationName" not found in route data');
      }

      if (_isConductorMode) {
        print('❌ No coordinates found in route data, skipping geocoding for conductor mode');
        return null;
      }

      try {
        print('⚠️ Falling back to geocoding for passenger mode...');
        List<Location> locations = await locationFromAddress('$destinationName, Philippines');
        if (locations.isNotEmpty) {
          print('✅ Geocoding succeeded: lat=${locations.first.latitude}, lng=${locations.first.longitude}');
          return {
            'latitude': locations.first.latitude,
            'longitude': locations.first.longitude,
          };
        }
      } catch (e) {
        print('❌ Geocoding failed for $destinationName: $e');
      }

      return null;
    } catch (e) {
      print('❌ Error getting destination coordinates: $e');
      return null;
    }
  }

  /// Mark a ticket as accomplished (passenger mode)
  Future<void> _markTicketAccomplished(String ticketId, String userId, Position position) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('preTickets')
          .doc(ticketId)
          .update({
        'status': 'accomplished',
        'accomplishedAt': DateTime.now(),
        'accomplishedLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      });
      
      print('✅ Ticket $ticketId marked as accomplished at ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('❌ Error marking ticket as accomplished: $e');
    }
  }

  /// Mark a pre-booking as accomplished (passenger mode)
  Future<void> _markPreBookingAccomplished(String bookingId, String userId, Position position) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('preBookings')
          .doc(bookingId)
          .update({
        'status': 'accomplished',
        'boardingStatus': 'completed',
        'accomplishedAt': DateTime.now(),
        'accomplishedLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      });
      
      print('✅ Pre-booking $bookingId marked as accomplished at ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('❌ Error marking pre-booking as accomplished: $e');
    }
  }

  /// Mark conductor ticket as completed (conductor mode)
  Future<void> _markConductorTicketCompleted(DocumentReference ticketRef, int quantity) async {
    try {
      await ticketRef.update({
        'active': false,
        'completedAt': FieldValue.serverTimestamp(),
        'status': 'completed',
      });
      
      print('✅ Conductor ticket ${ticketRef.id} marked as completed for $quantity passenger(s)');
    } catch (e) {
      print('❌ Error marking conductor ticket as completed: $e');
    }
  }

  /// Mark pre-booking as completed (conductor mode)
  Future<void> _markPreBookingCompleted(DocumentReference bookingRef, int quantity) async {
    try {
      // Get the booking data first to find the userId
      final bookingDoc = await bookingRef.get();
      if (!bookingDoc.exists) {
        print('❌ Pre-booking document not found');
        return;
      }
      
      final bookingData = bookingDoc.data() as Map<String, dynamic>;
      final userId = bookingData['userId'] ?? bookingData['data']?['userId'];
      final bookingId = bookingDoc.id;
      final destination = bookingData['to'] ?? bookingData['data']?['to'];
      
      print('🔄 Marking pre-booking as accomplished: userId=$userId, bookingId=$bookingId, destination=$destination');
      
      // Update in conductor's preBookings collection
      await bookingRef.update({
        'status': 'accomplished',
        'boardingStatus': 'accomplished',
        'completedAt': FieldValue.serverTimestamp(),
        'dropOffTimestamp': FieldValue.serverTimestamp(),
        'dropOffLocation': destination,
        'geofenceStatus': 'completed',
        'tripCompleted': true,
      });
      
      print('✅ Updated conductor preBookings collection');
      
      // Update in user's preBookings collection
      if (userId != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('preBookings')
              .doc(bookingId)
              .update({
            'status': 'accomplished',
            'boardingStatus': 'accomplished',
            'dropOffTimestamp': FieldValue.serverTimestamp(),
            'dropOffLocation': destination,
            'geofenceStatus': 'completed',
            'tripCompleted': true,
          });
          print('✅ Updated user preBookings collection');
        } catch (e) {
          print('⚠️ Error updating user preBookings collection: $e');
        }
      }
      
      // Also update in conductor's scannedQRCodes collection if exists
      if (_conductorDocId != null) {
        try {
          // Try multiple query methods to find the scanned QR code
          QuerySnapshot scannedQRQuery;
          
          // First try: search by booking ID
          scannedQRQuery = await FirebaseFirestore.instance
              .collection('conductors')
              .doc(_conductorDocId!)
              .collection('scannedQRCodes')
              .where('id', isEqualTo: bookingId)
              .limit(1)
              .get();
          
          // If not found, try searching by preBookingId field
          if (scannedQRQuery.docs.isEmpty) {
            scannedQRQuery = await FirebaseFirestore.instance
                .collection('conductors')
                .doc(_conductorDocId!)
                .collection('scannedQRCodes')
                .where('preBookingId', isEqualTo: bookingId)
                .limit(1)
                .get();
          }
          
          // If not found, try searching by documentId field
          if (scannedQRQuery.docs.isEmpty) {
            scannedQRQuery = await FirebaseFirestore.instance
                .collection('conductors')
                .doc(_conductorDocId!)
                .collection('scannedQRCodes')
                .where('documentId', isEqualTo: bookingId)
                .limit(1)
                .get();
          }
          
          if (scannedQRQuery.docs.isNotEmpty) {
            await scannedQRQuery.docs.first.reference.update({
              'status': 'accomplished',
              'dropOffTimestamp': FieldValue.serverTimestamp(),
              'dropOffLocation': destination,
              'geofenceStatus': 'completed',
              'tripCompleted': true,
            });
            print('✅ Updated scannedQRCodes collection for booking $bookingId');
          } else {
            print('⚠️ Could not find scannedQR entry for booking $bookingId in scannedQRCodes collection');
          }
        } catch (e) {
          print('⚠️ Error updating scannedQRCodes collection: $e');
        }
      }
      
      print('✅ Pre-booking $bookingId marked as accomplished for $quantity passenger(s)');
    } catch (e) {
      print('❌ Error marking pre-booking as completed: $e');
    }
  }

  /// Mark pre-ticket as completed (conductor mode)
  Future<void> _markPreTicketCompleted(DocumentReference ticketRef, int quantity) async {
    try {
      // Get the ticket data first to find the userId
      final ticketDoc = await ticketRef.get();
      if (!ticketDoc.exists) {
        print('❌ Pre-ticket document not found');
        return;
      }
      
      final ticketData = ticketDoc.data() as Map<String, dynamic>;
      final userId = ticketData['userId'] ?? ticketData['data']?['userId'];
      final ticketId = ticketDoc.id;
      final destination = ticketData['to'] ?? ticketData['data']?['to'];
      
      print('🔄 Marking pre-ticket as accomplished: userId=$userId, ticketId=$ticketId, destination=$destination');
      
      // Update in conductor's preTickets collection
      await ticketRef.update({
        'status': 'accomplished',
        'completedAt': FieldValue.serverTimestamp(),
        'dropOffTimestamp': FieldValue.serverTimestamp(),
        'dropOffLocation': destination,
        'geofenceStatus': 'completed',
        'tripCompleted': true,
      });
      
      print('✅ Updated conductor preTickets collection');
      
      // Update in user's preTickets collection
      if (userId != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('preTickets')
              .doc(ticketId)
              .update({
            'status': 'accomplished',
            'dropOffTimestamp': FieldValue.serverTimestamp(),
            'dropOffLocation': destination,
            'geofenceStatus': 'completed',
            'tripCompleted': true,
          });
          print('✅ Updated user preTickets collection');
        } catch (e) {
          print('⚠️ Error updating user preTickets collection: $e');
        }
      }
      
      print('✅ Pre-ticket $ticketId marked as accomplished for $quantity passenger(s)');
    } catch (e) {
      print('❌ Error marking pre-ticket as completed: $e');
    }
  }

  /// Clean up old processed destinations to prevent memory leaks
  void _cleanupOldProcessedDestinations() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    
    _lastProcessedDestinations.forEach((destination, lastProcessed) {
      if (now.difference(lastProcessed) > Duration(minutes: 5)) {
        keysToRemove.add(destination);
      }
    });
    
    for (final key in keysToRemove) {
      _lastProcessedDestinations.remove(key);
    }
    
    if (keysToRemove.isNotEmpty) {
      print('🧹 Cleaned up ${keysToRemove.length} old processed destinations');
    }
  }

  /// Check if geofencing is currently active
  bool get isMonitoring => _isMonitoring;

  /// Check if in conductor mode
  bool get isConductorMode => _isConductorMode;

  /// Get current geofence radius
  double get geofenceRadius => _geofenceRadius;
}