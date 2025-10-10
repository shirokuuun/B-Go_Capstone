import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:intl/intl.dart';
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
  static const double _geofenceRadius =
      250.0; // 250 meters for drop-off detection
  static const Duration _checkInterval = Duration(seconds: 20);
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
      print(
          '🔧 Final state: _isMonitoring=$_isMonitoring, _isConductorMode=$_isConductorMode');
    } catch (e) {
      print('❌ Error starting passenger geofencing: $e');
    }
  }

  /// Start conductor-based geofencing monitoring
  Future<void> startConductorMonitoring(
      String route, String conductorDocId) async {
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
      print(
          '🔧 Mode check: _isConductorMode=$_isConductorMode, route=$route, docId=$conductorDocId');

      // Start location monitoring
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 10,
          timeLimit: Duration(seconds: 15),
        ),
      ).listen((Position position) {
        print(
            '📍 Geofencing: Received position update - lat: ${position.latitude}, lng: ${position.longitude}, accuracy: ${position.accuracy}m');
        if (position.accuracy <= _locationAccuracyThreshold) {
          print(
              '✅ Geofencing: Position accuracy acceptable (${position.accuracy}m <= ${_locationAccuracyThreshold}m), checking geofencing...');
          _checkConductorGeofencing(position);
        } else {
          print(
              '⚠️ Geofencing: Position accuracy too poor (${position.accuracy}m > ${_locationAccuracyThreshold}m), skipping...');
        }
      });

      // Also check periodically for better reliability
      _geofencingTimer = Timer.periodic(_checkInterval, (timer) async {
        try {
          print(
              '⏰ Geofencing: Periodic check triggered (every ${_checkInterval.inSeconds}s)');
          _cleanupOldProcessedDestinations();

          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 15),
          );
          print(
              '📍 Geofencing: Periodic position - lat: ${position.latitude}, lng: ${position.longitude}, accuracy: ${position.accuracy}m');
          if (position.accuracy <= _locationAccuracyThreshold) {
            print(
                '✅ Geofencing: Periodic position accuracy acceptable, checking geofencing...');
            _checkConductorGeofencing(position);
          } else {
            print(
                '⚠️ Geofencing: Periodic position accuracy too poor, skipping...');
          }
        } catch (e) {
          print('❌ Geofencing: Error getting current position: $e');
        }
      });

      _isMonitoring = true;
      print('✅ Conductor geofencing monitoring started for route: $route');
      print(
          '🔧 Geofencing config: radius=${_geofenceRadius}m, accuracy≤${_locationAccuracyThreshold}m, interval=${_checkInterval.inSeconds}s');
      print(
          '🔧 Final state: _isMonitoring=$_isMonitoring, _isConductorMode=$_isConductorMode');
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
      print(
          '📍 Position: ${passengerPosition.latitude}, ${passengerPosition.longitude}');

      // 1. Check PRE-TICKETS - ONLY 'boarded' status
      final preTicketsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preTickets')
          .where('status', isEqualTo: 'boarded')
          .get();

      print('🎫 Found ${preTicketsSnapshot.docs.length} boarded pre-tickets');

      for (var doc in preTicketsSnapshot.docs) {
        final ticket = doc.data();
        final destinationName = ticket['to'];
        final route = ticket['route'];

        print(
            '🔍 Checking pre-ticket ${doc.id}: to=$destinationName, status=${ticket['status']}');

        // Skip if already accomplished
        if (ticket['status'] == 'accomplished' ||
            ticket['dropOffTimestamp'] != null ||
            ticket['geofenceStatus'] == 'completed') {
          print('⏭️ Skipping pre-ticket ${doc.id} - already accomplished');
          continue;
        }

        if (destinationName != null && route != null) {
          final destinationCoords =
              await _getDestinationCoordinates(destinationName, route);

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

              print(
                  '📍 Distance to $destinationName: ${distance.toStringAsFixed(1)}m');

              if (distance <= _geofenceRadius) {
                await _markTicketAccomplished(
                    doc.id, user.uid, passengerPosition);
                print(
                    '🎯 Pre-ticket accomplished: Passenger reached ${destinationName} (${distance.toStringAsFixed(1)}m away)');
              }
            }
          }
        }
      }

      // 2. Check PRE-BOOKINGS - ONLY 'boarded' status
      final preBookingsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .where('status', isEqualTo: 'boarded')
          .get();

      print('📚 Found ${preBookingsSnapshot.docs.length} boarded pre-bookings');

      for (var doc in preBookingsSnapshot.docs) {
        final booking = doc.data();
        final destinationName = booking['to'];
        final route = booking['route'];

        print(
            '🔍 Checking pre-booking ${doc.id}: to=$destinationName, status=${booking['status']}');

        // Skip if already accomplished
        if (booking['status'] == 'accomplished' ||
            booking['dropOffTimestamp'] != null ||
            booking['geofenceStatus'] == 'completed') {
          print('⏭️ Skipping pre-booking ${doc.id} - already accomplished');
          continue;
        }

        if (destinationName != null && route != null) {
          final destinationCoords =
              await _getDestinationCoordinates(destinationName, route);

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

              print(
                  '📍 Distance to $destinationName: ${distance.toStringAsFixed(1)}m');

              if (distance <= _geofenceRadius) {
                await _markPreBookingAccomplished(
                    doc.id, user.uid, passengerPosition);
                print(
                    '🎯 Pre-booking accomplished: Passenger reached ${destinationName} (${distance.toStringAsFixed(1)}m away)');
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
    print(
        '🔧 _checkConductorGeofencing called: _isConductorMode=$_isConductorMode, route=$_conductorRoute, docId=$_conductorDocId');

    if (!_isConductorMode ||
        _conductorRoute == null ||
        _conductorDocId == null) {
      print(
          '❌ Geofencing check skipped - not in conductor mode or missing data');
      return;
    }

    try {
      print(
          '🔍 Checking conductor geofencing for route: $_conductorRoute at ${DateTime.now()}');
      print(
          '📍 Conductor position: ${conductorPosition.latitude}, ${conductorPosition.longitude}');

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
      final activeTripId = conductorData['activeTrip']?['tripId'];

      print('👥 Current passenger count: $currentPassengerCount');
      print('🔍 Current active trip ID: $activeTripId');

      if (currentPassengerCount <= 0) {
        print('ℹ️ No passengers to check for drop-off');
        return;
      }

      int totalDecremented = 0;
      Set<String> processedDestinations = {};

      // ✅ NEW: Group tickets by destination
      Map<String, List<Map<String, dynamic>>> ticketsByDestination = {};

      // 1. COLLECT ALL MANUAL TICKETS grouped by destination
      final remittanceSnapshot = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(_conductorDocId!)
          .collection('remittance')
          .get();

      print(
          '📋 Found ${remittanceSnapshot.docs.length} date documents in remittance');

      for (var dateDoc in remittanceSnapshot.docs) {
        final dateId = dateDoc.id;
        final ticketsCollection = dateDoc.reference.collection('tickets');
        final tickets = await ticketsCollection.get();

        for (var ticketDoc in tickets.docs) {
          final ticket = ticketDoc.data();
          final destinationName = ticket['to'];
          final isActive = ticket['active'] ?? false;
          final ticketTripId = ticket['tripId'];
          final status = ticket['status'] ?? '';

          print(
              '🔍 Manual ticket ${ticketDoc.id}: to=$destinationName, active=$isActive, status=$status, tripId=$ticketTripId');

          // Check if should process
          bool shouldProcess = isActive &&
              destinationName != null &&
              status != 'accomplished' &&
              status != 'completed';

          // Check tripId compatibility
          bool tripIdMatches = false;
          if (ticketTripId == null) {
            tripIdMatches = true;
            print(
                '✅ Ticket has null tripId - will process as current trip ticket');
          } else if (ticketTripId == activeTripId) {
            tripIdMatches = true;
            print('✅ Ticket tripId matches active trip');
          } else {
            tripIdMatches = false;
            print(
                '⏭️ Skipping ticket - belongs to different trip: $ticketTripId vs $activeTripId');
          }

          if (shouldProcess && tripIdMatches) {
            // ✅ NEW: Group tickets by destination
            if (!ticketsByDestination.containsKey(destinationName)) {
              ticketsByDestination[destinationName] = [];
            }

            ticketsByDestination[destinationName]!.add({
              'type': 'manual',
              'reference': ticketDoc.reference,
              'dateId': dateId,
              'quantity': (ticket['quantity'] as num?)?.toInt() ?? 1,
              'ticketId': ticketDoc.id,
            });

            print(
                '📦 Grouped manual ticket ${ticketDoc.id} to destination: $destinationName');
          } else {
            if (!isActive) {
              print(
                  '⏭️ Skipping manual ticket ${ticketDoc.id} - not active (already accomplished)');
            } else if (!tripIdMatches) {
              print(
                  '⏭️ Skipping manual ticket ${ticketDoc.id} - tripId mismatch');
            } else if (status == 'accomplished' || status == 'completed') {
              print(
                  '⏭️ Skipping manual ticket ${ticketDoc.id} - status is already $status');
            }
          }
        }
      }

      // 2. COLLECT PRE-BOOKINGS grouped by destination
      final preBookingsSnapshot = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(_conductorDocId!)
          .collection('preBookings')
          .where('status', isEqualTo: 'boarded')
          .get();

      print('📚 Found ${preBookingsSnapshot.docs.length} boarded pre-bookings');

      for (var doc in preBookingsSnapshot.docs) {
        final booking = doc.data();
        final destinationName = booking['to'];
        final bookingTripId = booking['tripId'];

        bool bookingTripMatches =
            (bookingTripId == null || bookingTripId == activeTripId);

        if (!bookingTripMatches) {
          print(
              '⏭️ Skipping pre-booking ${doc.id} - belongs to different trip');
          continue;
        }

        final hasDropOffTimestamp = booking['dropOffTimestamp'] != null;
        final hasCompletedAt = booking['completedAt'] != null;
        final currentStatus = booking['status'] ?? '';

        if (hasDropOffTimestamp ||
            hasCompletedAt ||
            currentStatus == 'completed' ||
            currentStatus == 'accomplished') {
          print('⏭️ Skipping pre-booking ${doc.id} - already completed');
          continue;
        }

        int quantity = 1;
        if (booking['quantity'] != null) {
          quantity = (booking['quantity'] as num).toInt();
        }

        if (destinationName != null) {
          if (!ticketsByDestination.containsKey(destinationName)) {
            ticketsByDestination[destinationName] = [];
          }

          ticketsByDestination[destinationName]!.add({
            'type': 'preBooking',
            'reference': doc.reference,
            'quantity': quantity,
            'bookingId': doc.id,
          });

          print(
              '📦 Grouped pre-booking ${doc.id} to destination: $destinationName');
        }
      }

      // 3. COLLECT PRE-TICKETS grouped by destination
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
        final ticketTripId = ticket['tripId'];

        bool ticketTripMatches =
            (ticketTripId == null || ticketTripId == activeTripId);

        if (!ticketTripMatches) {
          print('⏭️ Skipping pre-ticket ${doc.id} - belongs to different trip');
          continue;
        }

        final hasDropOffTimestamp = ticket['dropOffTimestamp'] != null;
        final hasCompletedAt = ticket['completedAt'] != null;
        final currentStatus = ticket['status'] ?? '';

        if (hasDropOffTimestamp ||
            hasCompletedAt ||
            currentStatus == 'completed' ||
            currentStatus == 'accomplished') {
          print('⏭️ Skipping pre-ticket ${doc.id} - already completed');
          continue;
        }

        int quantity = 1;
        if (ticket['data']?['quantity'] != null) {
          quantity = (ticket['data']['quantity'] as num).toInt();
        } else if (ticket['quantity'] != null) {
          quantity = (ticket['quantity'] as num).toInt();
        }

        if (destinationName != null) {
          if (!ticketsByDestination.containsKey(destinationName)) {
            ticketsByDestination[destinationName] = [];
          }

          ticketsByDestination[destinationName]!.add({
            'type': 'preTicket',
            'reference': doc.reference,
            'quantity': quantity,
            'ticketId': doc.id,
          });

          print(
              '📦 Grouped pre-ticket ${doc.id} to destination: $destinationName');
        }
      }

      // ✅ NOW PROCESS ALL DESTINATIONS
      print(
          '\n🎯 Processing ${ticketsByDestination.length} unique destinations...\n');

      for (var entry in ticketsByDestination.entries) {
        final destinationName = entry.key;
        final ticketsForDestination = entry.value;

        print(
            '🔍 Processing destination: $destinationName with ${ticketsForDestination.length} ticket(s)');

        // Get coordinates for this destination
        final destinationCoords =
            await _getDestinationCoordinates(destinationName, _conductorRoute!);

        if (destinationCoords == null) {
          print(
              '⚠️ Could not get coordinates for $destinationName, skipping all tickets to this destination');
          continue;
        }

        final lat = destinationCoords['latitude'];
        final lng = destinationCoords['longitude'];

        if (lat == null || lng == null) {
          print('⚠️ Invalid coordinates for $destinationName, skipping');
          continue;
        }

        final distance = Geolocator.distanceBetween(
          conductorPosition.latitude,
          conductorPosition.longitude,
          lat,
          lng,
        );

        print(
            '🎯 Destination $destinationName: ${distance.toStringAsFixed(1)}m away (threshold: ${_geofenceRadius}m)');

        if (distance <= _geofenceRadius) {
          print('✅ Conductor is within geofence radius!');
          print('🔍 Checking if approaching destination...');

          if (await _isApproachingDestination(conductorPosition, lat, lng)) {
            print('✅ Conductor IS approaching destination!');
            print(
                '🚀 Processing ALL ${ticketsForDestination.length} ticket(s) to $destinationName');

            // ✅ PROCESS ALL TICKETS TO THIS DESTINATION
            for (var ticketData in ticketsForDestination) {
              final type = ticketData['type'];
              final reference = ticketData['reference'] as DocumentReference;
              final quantity = ticketData['quantity'] as int;

              if (type == 'manual') {
                final dateId = ticketData['dateId'] as String;
                final ticketId = ticketData['ticketId'] as String;

                print(
                    '🚀 MARKING MANUAL TICKET AS COMPLETED: $ticketId (quantity: $quantity)');
                await _markConductorTicketCompleted(
                    reference, quantity, dateId);
                totalDecremented += quantity;
                print(
                    '✅ Manual ticket $ticketId completed: $quantity passenger(s) dropped off');
              } else if (type == 'preBooking') {
                final bookingId = ticketData['bookingId'] as String;

                print(
                    '🚀 MARKING PRE-BOOKING AS COMPLETED: $bookingId (quantity: $quantity)');
                await _markPreBookingCompleted(reference, quantity);
                totalDecremented += quantity;
                print(
                    '✅ Pre-booking $bookingId completed: $quantity passenger(s) dropped off');
              } else if (type == 'preTicket') {
                final ticketId = ticketData['ticketId'] as String;

                print(
                    '🚀 MARKING PRE-TICKET AS COMPLETED: $ticketId (quantity: $quantity)');
                await _markPreTicketCompleted(reference, quantity);
                totalDecremented += quantity;
                print(
                    '✅ Pre-ticket $ticketId completed: $quantity passenger(s) dropped off');
              }
            }

            print('✅ Total decremented so far: $totalDecremented');
            processedDestinations.add(destinationName);
          } else {
            print(
                '⏭️ Conductor is NOT approaching (moving away from destination)');
          }
        } else {
          print(
              '⏭️ Not within geofence radius yet (${distance.toStringAsFixed(1)}m > ${_geofenceRadius}m)');
        }
      }

      // Update passenger count
      if (totalDecremented > 0) {
        final newPassengerCount = (currentPassengerCount - totalDecremented)
            .clamp(0, double.infinity)
            .toInt();

        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(_conductorDocId!)
            .update({
          'passengerCount': newPassengerCount,
          'lastDropOff': FieldValue.serverTimestamp(),
        });

        print('✅ Total passengers dropped off: $totalDecremented');
        print(
            '✅ Conductor passenger count updated: $currentPassengerCount → $newPassengerCount');
      }
    } catch (e) {
      print('❌ Error in conductor geofencing check: $e');
    }
  }

  /// Check if the conductor is actually approaching the destination
  Future<bool> _isApproachingDestination(
      Position currentPosition, double destLat, double destLng) async {
    try {
      final conductorDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(_conductorDocId!)
          .get();

      if (!conductorDoc.exists) {
        print('⚠️ Conductor doc not found, assuming approaching');
        return true; // If no previous position, assume approaching
      }

      final conductorData = conductorDoc.data() as Map<String, dynamic>;
      final lastPosition =
          conductorData['lastPosition'] as Map<String, dynamic>?;

      if (lastPosition == null) {
        print('⚠️ No last position found, assuming approaching');
        // Update current position as last position
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
        return true; // First time, assume approaching
      }

      final lastLat = lastPosition['latitude'] as num?;
      final lastLng = lastPosition['longitude'] as num?;

      if (lastLat == null || lastLng == null) {
        print('⚠️ Invalid last position coordinates, assuming approaching');
        return true;
      }

      // Calculate current distance to destination
      final currentDistance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        destLat,
        destLng,
      );

      // Calculate previous distance to destination
      final previousDistance = Geolocator.distanceBetween(
        lastLat.toDouble(),
        lastLng.toDouble(),
        destLat,
        destLng,
      );

      // ✅ RELAXED TOLERANCE: Allow small variations due to GPS inaccuracy
      final tolerance = 15.0; // Increased from 5.0 to 15.0 meters
      final isApproaching = currentDistance < (previousDistance + tolerance);

      print('📊 Approaching check:');
      print('   Previous distance: ${previousDistance.toStringAsFixed(1)}m');
      print('   Current distance: ${currentDistance.toStringAsFixed(1)}m');
      print(
          '   Difference: ${(previousDistance - currentDistance).toStringAsFixed(1)}m');
      print('   Tolerance: ${tolerance}m');
      print('   Result: ${isApproaching ? "APPROACHING ✅" : "MOVING AWAY ❌"}');

      // Calculate how much conductor has moved since last check
      final positionChange = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        lastLat.toDouble(),
        lastLng.toDouble(),
      );

      // Update lastPosition if conductor has moved significantly (more than 10m)
      if (positionChange > 10.0) {
        print(
            '📍 Updating lastPosition (moved ${positionChange.toStringAsFixed(1)}m)');
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
      print('❌ Error checking if approaching destination: $e');
      return true; // On error, assume approaching to avoid blocking geofencing
    }
  }

  /// Get destination coordinates from route data or geocoding
  Future<Map<String, double>?> _getDestinationCoordinates(
      String destinationName, String route) async {
    try {
      final places =
          await RouteService.fetchPlaces(route, placeCollection: 'Place');
      final places2 =
          await RouteService.fetchPlaces(route, placeCollection: 'Place 2');

      final allPlaces = [...places, ...places2];

      print(
          '🔍 Looking for coordinates for destination: "$destinationName" in route: $route');

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
        print(
            '❌ No coordinates found in route data, skipping geocoding for conductor mode');
        return null;
      }

      try {
        print('⚠️ Falling back to geocoding for passenger mode...');
        List<Location> locations =
            await locationFromAddress('$destinationName, Philippines');
        if (locations.isNotEmpty) {
          print(
              '✅ Geocoding succeeded: lat=${locations.first.latitude}, lng=${locations.first.longitude}');
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
  Future<void> _markTicketAccomplished(
      String ticketId, String userId, Position position) async {
    try {
      // Update in user's collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('preTickets')
          .doc(ticketId)
          .update({
        'status': 'accomplished',
        'accomplishedAt': DateTime.now(),
        'dropOffTimestamp': FieldValue.serverTimestamp(),
        'accomplishedLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        'geofenceStatus': 'completed',
        'tripCompleted': true,
      });

      print('✅ Ticket $ticketId marked as accomplished in user collection');

      // Try to update in conductor's collections if it exists
      try {
        // Search for this pre-ticket in conductor collections
        final conductorsSnapshot =
            await FirebaseFirestore.instance.collection('conductors').get();

        for (var conductorDoc in conductorsSnapshot.docs) {
          // Check in preTickets collection
          final preTicketRef =
              conductorDoc.reference.collection('preTickets').doc(ticketId);

          final preTicketSnap = await preTicketRef.get();
          if (preTicketSnap.exists) {
            await preTicketRef.update({
              'status': 'accomplished',
              'completedAt': FieldValue.serverTimestamp(),
              'dropOffTimestamp': FieldValue.serverTimestamp(),
              'geofenceStatus': 'completed',
              'tripCompleted': true,
            });
            print('✅ Updated pre-ticket in conductor preTickets collection');

            // Also update in remittance if it exists
            final now = DateTime.now();
            final formattedDate =
                "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

            final remittanceTickets = await conductorDoc.reference
                .collection('remittance')
                .doc(formattedDate)
                .collection('tickets')
                .where('documentId', isEqualTo: ticketId)
                .get();

            for (var remittanceTicket in remittanceTickets.docs) {
              await remittanceTicket.reference.update({
                'status': 'accomplished',
                'active': false,
                'completedAt': FieldValue.serverTimestamp(),
              });
              print('✅ Updated pre-ticket in remittance collection');
            }

            break;
          }
        }
      } catch (e) {
        print('⚠️ Could not update conductor collections: $e');
      }

      print('✅ Ticket $ticketId fully marked as accomplished');
    } catch (e) {
      print('❌ Error marking ticket as accomplished: $e');
    }
  }

  /// Mark a pre-booking as accomplished (passenger mode)
  Future<void> _markPreBookingAccomplished(
      String bookingId, String userId, Position position) async {
    try {
      // Update in user's collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('preBookings')
          .doc(bookingId)
          .update({
        'status': 'accomplished',
        'boardingStatus': 'completed',
        'accomplishedAt': DateTime.now(),
        'dropOffTimestamp': FieldValue.serverTimestamp(),
        'accomplishedLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        'geofenceStatus': 'completed',
        'tripCompleted': true,
      });

      print(
          '✅ Pre-booking $bookingId marked as accomplished in user collection');

      // Try to update in conductor's collections if it exists
      try {
        final conductorsSnapshot =
            await FirebaseFirestore.instance.collection('conductors').get();

        for (var conductorDoc in conductorsSnapshot.docs) {
          // Check in preBookings collection
          final preBookingRef =
              conductorDoc.reference.collection('preBookings').doc(bookingId);

          final preBookingSnap = await preBookingRef.get();
          if (preBookingSnap.exists) {
            await preBookingRef.update({
              'status': 'accomplished',
              'boardingStatus': 'accomplished',
              'completedAt': FieldValue.serverTimestamp(),
              'dropOffTimestamp': FieldValue.serverTimestamp(),
              'geofenceStatus': 'completed',
              'tripCompleted': true,
            });
            print('✅ Updated pre-booking in conductor preBookings collection');

            // Also check scannedQRCodes collection
            final scannedQRs = await conductorDoc.reference
                .collection('scannedQRCodes')
                .where('bookingId', isEqualTo: bookingId)
                .get();

            for (var scannedQR in scannedQRs.docs) {
              await scannedQR.reference.update({
                'status': 'accomplished',
                'dropOffTimestamp': FieldValue.serverTimestamp(),
                'geofenceStatus': 'completed',
                'tripCompleted': true,
              });
            }

            break;
          }
        }
      } catch (e) {
        print('⚠️ Could not update conductor collections: $e');
      }

      print('✅ Pre-booking $bookingId fully marked as accomplished');
    } catch (e) {
      print('❌ Error marking pre-booking as accomplished: $e');
    }
  }

  /// Mark conductor ticket as completed (conductor mode)
  Future<void> _markConductorTicketCompleted(
      DocumentReference ticketRef, int quantity, String dateId) async {
    try {
      print(
          '🔄 Starting to mark conductor ticket ${ticketRef.id} as accomplished...');

      // Update the ticket to mark it as accomplished
      await ticketRef.update({
        'active': false, // ✅ CRITICAL: Set to false to mark as accomplished
        'completedAt': FieldValue.serverTimestamp(),
        'status': 'accomplished',
        'dropOffTimestamp': FieldValue.serverTimestamp(),
        'geofenceStatus': 'completed',
        'tripCompleted': true,
      });

      print(
          '✅ Conductor ticket ${ticketRef.id} marked as accomplished for $quantity passenger(s)');
      print(
          '✅ Updated fields: active=false, status=accomplished, completedAt=NOW, dropOffTimestamp=NOW');

      // ✅ CRITICAL FIX: Also update in dailyTrips collection
      try {
        print('🔄 Now updating ticket in dailyTrips collection...');

        // Get conductor document to find current trip
        final conductorDoc = await FirebaseFirestore.instance
            .collection('conductors')
            .doc(_conductorDocId!)
            .get();

        if (conductorDoc.exists) {
          // Get current trip number from dailyTrips
          final dailyTripDoc = await FirebaseFirestore.instance
              .collection('conductors')
              .doc(_conductorDocId!)
              .collection('dailyTrips')
              .doc(dateId)
              .get();

          if (dailyTripDoc.exists) {
            final dailyTripData = dailyTripDoc.data();
            final currentTrip = dailyTripData?['currentTrip'] ?? 1;
            final tripCollection = 'trip$currentTrip';
            final ticketId = ticketRef.id; // e.g., "ticket 5"

            print(
                '🔍 Looking for ticket in dailyTrips/$dateId/$tripCollection/tickets/tickets/$ticketId');

            final dailyTripTicketRef = FirebaseFirestore.instance
                .collection('conductors')
                .doc(_conductorDocId!)
                .collection('dailyTrips')
                .doc(dateId)
                .collection(tripCollection)
                .doc('tickets')
                .collection('tickets')
                .doc(ticketId);

            final dailyTripTicketSnap = await dailyTripTicketRef.get();

            if (dailyTripTicketSnap.exists) {
              await dailyTripTicketRef.update({
                'active': false,
                'completedAt': FieldValue.serverTimestamp(),
                'status': 'accomplished',
                'dropOffTimestamp': FieldValue.serverTimestamp(),
                'geofenceStatus': 'completed',
                'tripCompleted': true,
              });
              print(
                  '✅ Also updated manual ticket in dailyTrips/$dateId/$tripCollection/tickets/tickets/$ticketId');
              print(
                  '✅ DailyTrips ticket updated: active=false, status=accomplished');
            } else {
              print(
                  '⚠️ Manual ticket NOT FOUND in dailyTrips structure at: dailyTrips/$dateId/$tripCollection/tickets/tickets/$ticketId');
              print(
                  '⚠️ This ticket may not appear as accomplished in some views');
            }
          } else {
            print('⚠️ DailyTrip document not found for date: $dateId');
          }
        } else {
          print('⚠️ Conductor document not found');
        }
      } catch (e) {
        print('⚠️ Error updating dailyTrips manual ticket: $e');
        print(
            '⚠️ Remittance ticket was updated successfully, but dailyTrips may not reflect the change');
        // Don't throw - remittance update succeeded
      }

      print(
          '✅ _markConductorTicketCompleted completed successfully for ticket ${ticketRef.id}');
    } catch (e) {
      print('❌ ERROR in _markConductorTicketCompleted: $e');
      print('❌ Failed to mark conductor ticket ${ticketRef.id} as completed');
    }
  }

  /// Mark pre-booking as completed (conductor mode)
  Future<void> _markPreBookingCompleted(
      DocumentReference bookingRef, int quantity) async {
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

      print(
          '🔄 Marking pre-booking as accomplished: userId=$userId, bookingId=$bookingId, destination=$destination');

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
            print(
                '⚠️ Could not find scannedQR entry for booking $bookingId in scannedQRCodes collection');
          }
        } catch (e) {
          print('⚠️ Error updating scannedQRCodes collection: $e');
        }
      }

      print(
          '✅ Pre-booking $bookingId marked as accomplished for $quantity passenger(s)');
    } catch (e) {
      print('❌ Error marking pre-booking as completed: $e');
    }
  }

  /// Mark pre-ticket as completed (conductor mode)
  Future<void> _markPreTicketCompleted(
      DocumentReference ticketRef, int quantity) async {
    try {
      final ticketDoc = await ticketRef.get();
      if (!ticketDoc.exists) {
        print('❌ Pre-ticket document not found');
        return;
      }

      final ticketData = ticketDoc.data() as Map<String, dynamic>;
      final userId = ticketData['userId'] ?? ticketData['data']?['userId'];
      final ticketId = ticketDoc.id;
      final destination = ticketData['to'] ?? ticketData['data']?['to'];

      print(
          '🔄 Marking pre-ticket as accomplished: userId=$userId, ticketId=$ticketId, destination=$destination');

      // CRITICAL FIX: Update user's collection FIRST before conductor's
      if (userId != null) {
        try {
          // Get the user's pre-ticket document first to verify it exists
          final userPreTicketRef = FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('preTickets')
              .doc(ticketId);

          final userPreTicketSnap = await userPreTicketRef.get();

          if (userPreTicketSnap.exists) {
            await userPreTicketRef.update({
              'status': 'accomplished',
              'dropOffTimestamp': FieldValue.serverTimestamp(),
              'dropOffLocation': destination,
              'geofenceStatus': 'completed',
              'tripCompleted': true,
              'accomplishedAt': FieldValue.serverTimestamp(), // Add this field
            });
            print(
                '✅ Updated user preTickets collection for ticketId: $ticketId');
          } else {
            print(
                '⚠️ User pre-ticket document not found: $ticketId for userId: $userId');

            // Try to find it by matching qrData or other fields
            final userPreTicketsQuery = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('preTickets')
                .where('to', isEqualTo: destination)
                .where('status', isEqualTo: 'boarded')
                .limit(1)
                .get();

            if (userPreTicketsQuery.docs.isNotEmpty) {
              final matchedDoc = userPreTicketsQuery.docs.first;
              await matchedDoc.reference.update({
                'status': 'accomplished',
                'dropOffTimestamp': FieldValue.serverTimestamp(),
                'dropOffLocation': destination,
                'geofenceStatus': 'completed',
                'tripCompleted': true,
                'accomplishedAt': FieldValue.serverTimestamp(),
              });
              print(
                  '✅ Found and updated user pre-ticket by matching destination');
            } else {
              print('❌ Could not find matching user pre-ticket document');
            }
          }
        } catch (e) {
          print('⚠️ Error updating user preTickets collection: $e');
          // Don't return - continue to update conductor's collection
        }
      } else {
        print('⚠️ No userId found in pre-ticket data');
      }

      // Now update conductor's preTickets collection
      await ticketRef.update({
        'status': 'accomplished',
        'completedAt': FieldValue.serverTimestamp(),
        'dropOffTimestamp': FieldValue.serverTimestamp(),
        'dropOffLocation': destination,
        'geofenceStatus': 'completed',
        'tripCompleted': true,
      });

      print('✅ Updated conductor preTickets collection');

      print(
          '✅ Pre-ticket $ticketId marked as accomplished for $quantity passenger(s)');
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
