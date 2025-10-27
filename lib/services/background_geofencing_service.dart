import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'notification_service.dart';

/// Background geofencing service that runs even when app is closed
class BackgroundGeofencingService {
  static final BackgroundGeofencingService _instance = 
      BackgroundGeofencingService._internal();
  factory BackgroundGeofencingService() => _instance;
  BackgroundGeofencingService._internal();
  
  // Shared preferences keys
  static const String _conductorRouteKey = 'conductor_route';
  static const String _conductorDocIdKey = 'conductor_doc_id';
  static const String _isMonitoringKey = 'is_monitoring';
  static const String _destinationsKey = 'geofence_destinations';
  
  // Configuration
  static const double _geofenceRadius = 250.0; // meters
  static const Duration _locationInterval = Duration(seconds: 10);
  
  // Runtime state
  StreamSubscription<Position>? _positionStream;
  Timer? _fallbackTimer;

  /// Initialize background geofencing
  Future<void> initialize() async {
    try {
      await _requestPermissions();
      await NotificationService().initialize();
      await NotificationService().requestPermissions();
      print('✅ BackgroundGeofencingService: Initialized');
    } catch (e) {
      print('❌ BackgroundGeofencingService: Initialization failed: $e');
    }
  }

  /// Request all necessary permissions for background location
  Future<bool> _requestPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('❌ Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('❌ Location permission permanently denied');
      return false;
    }

    if (permission == LocationPermission.whileInUse) {
      print('⚠️ Location permission is "While Using App" - need "Always" for background');
      permission = await Geolocator.requestPermission();
    }

    print('✅ Location permissions granted: $permission');
    return true;
  }

  /// Start background geofencing monitoring
  Future<bool> startMonitoring(String route, String conductorDocId) async {
    try {
      final hasPermissions = await _requestPermissions();
      if (!hasPermissions) {
        print('❌ Cannot start monitoring without permissions');
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_conductorRouteKey, route);
      await prefs.setString(_conductorDocIdKey, conductorDocId);
      await prefs.setBool(_isMonitoringKey, true);

      await _fetchAndStoreDestinations(route, conductorDocId);
      await _startBackgroundLocationMonitoring();

      print('✅ BackgroundGeofencingService: Monitoring started for route: $route');
      return true;
    } catch (e) {
      print('❌ BackgroundGeofencingService: Error starting monitoring: $e');
      return false;
    }
  }

  /// Fetch destinations and store them locally
  Future<void> _fetchAndStoreDestinations(String route, String conductorDocId) async {
    try {
      final conductorRef = FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorDocId);

      final preBookingsQuery = await conductorRef
          .collection('preBookings')
          .where('status', isEqualTo: 'boarded')
          .get();

      final preTicketsQuery = await conductorRef
          .collection('preTickets')
          .where('status', isEqualTo: 'boarded')
          .get();

      final placesQuery = await FirebaseFirestore.instance
          .collection('Place')
          .where('routes', arrayContains: route)
          .get();

      final Map<String, Map<String, dynamic>> destinations = {};

      for (var placeDoc in placesQuery.docs) {
        final data = placeDoc.data();
        final placeName = data['name'] ?? placeDoc.id;
        final location = data['location'] as GeoPoint?;
        
        if (location != null) {
          destinations[placeName] = {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'passengers': 0,
          };
        }
      }

      for (var bookingDoc in preBookingsQuery.docs) {
        final data = bookingDoc.data();
        final destination = data['to'] ?? '';
        final quantity = data['quantity'] ?? 1;
        
        if (destinations.containsKey(destination)) {
          destinations[destination]!['passengers'] = 
              (destinations[destination]!['passengers'] as int) + quantity;
        }
      }

      for (var ticketDoc in preTicketsQuery.docs) {
        final data = ticketDoc.data();
        final destination = data['to'] ?? '';
        final quantity = data['quantity'] ?? 1;
        
        if (destinations.containsKey(destination)) {
          destinations[destination]!['passengers'] = 
              (destinations[destination]!['passengers'] as int) + quantity;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_destinationsKey, json.encode(destinations));

      print('✅ Stored ${destinations.length} destinations for background monitoring');
    } catch (e) {
      print('❌ Error fetching destinations: $e');
    }
  }

  /// Start background location monitoring
  Future<void> _startBackgroundLocationMonitoring() async {
    try {
      await _positionStream?.cancel();
      _fallbackTimer?.cancel();

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        timeLimit: Duration(seconds: 30),
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _processLocationUpdate(position);
        },
        onError: (error) {
          print('❌ Background location stream error: $error');
        },
      );

      _startFallbackTimer();
      print('✅ Background location monitoring started');
    } catch (e) {
      print('❌ Error starting background location monitoring: $e');
    }
  }

  /// Start fallback timer
  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(_locationInterval, (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        );
        _processLocationUpdate(position);
      } catch (e) {
        print('❌ Fallback timer error: $e');
      }
    });
  }

  /// Process location update and check geofences
  Future<void> _processLocationUpdate(Position position) async {
    try {
      print('📍 Background location: ${position.latitude}, ${position.longitude}');

      final prefs = await SharedPreferences.getInstance();
      final destinationsJson = prefs.getString(_destinationsKey);
      
      if (destinationsJson == null) {
        print('⚠️ No destinations stored');
        return;
      }

      final destinations = json.decode(destinationsJson) as Map<String, dynamic>;

      for (var entry in destinations.entries) {
        final destinationName = entry.key;
        final destinationData = entry.value as Map<String, dynamic>;
        final destLat = destinationData['latitude'] as double;
        final destLng = destinationData['longitude'] as double;
        final passengerCount = destinationData['passengers'] as int;

        if (passengerCount <= 0) continue;

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          destLat,
          destLng,
        );

        print('📏 Distance to $destinationName: ${distance.toStringAsFixed(1)}m');

        if (distance <= _geofenceRadius) {
          print('🎯 ENTERED GEOFENCE: $destinationName');
          
          await _handlePassengerDropOff(destinationName, passengerCount);
          
          destinationData['passengers'] = 0;
          await prefs.setString(_destinationsKey, json.encode(destinations));
        }
      }
    } catch (e) {
      print('❌ Error processing location update: $e');
    }
  }

  /// Handle passenger drop-off
  Future<void> _handlePassengerDropOff(String destination, int passengerCount) async {
    try {
      print('🎯 Handling drop-off at $destination for $passengerCount passengers');

      final prefs = await SharedPreferences.getInstance();
      final conductorDocId = prefs.getString(_conductorDocIdKey);
      
      if (conductorDocId == null) {
        print('❌ No conductor doc ID stored');
        return;
      }

      final conductorRef = FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorDocId);

      // Mark pre-bookings as accomplished
      final preBookingsQuery = await conductorRef
          .collection('preBookings')
          .where('status', isEqualTo: 'boarded')
          .where('to', isEqualTo: destination)
          .get();

      for (var doc in preBookingsQuery.docs) {
        final data = doc.data();
        final userId = data['userId'];
        final bookingId = doc.id;

        await doc.reference.update({
          'status': 'accomplished',
          'dropOffTimestamp': FieldValue.serverTimestamp(),
          'dropOffLocation': destination,
          'geofenceStatus': 'completed',
          'tripCompleted': true,
          'accomplishedAt': FieldValue.serverTimestamp(),
        });

        if (userId != null) {
          try {
            final userBookingRef = FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('preBookings')
                .doc(bookingId);

            final userBookingSnap = await userBookingRef.get();
            if (userBookingSnap.exists) {
              await userBookingRef.update({
                'status': 'accomplished',
                'dropOffTimestamp': FieldValue.serverTimestamp(),
                'dropOffLocation': destination,
                'geofenceStatus': 'completed',
                'tripCompleted': true,
                'accomplishedAt': FieldValue.serverTimestamp(),
              });
            }
          } catch (e) {
            print('⚠️ Error updating user booking: $e');
          }
        }

        print('✅ Updated pre-booking: ${doc.id}');
      }

      // Mark pre-tickets as accomplished
      final preTicketsQuery = await conductorRef
          .collection('preTickets')
          .where('status', isEqualTo: 'boarded')
          .where('to', isEqualTo: destination)
          .get();

      for (var doc in preTicketsQuery.docs) {
        final data = doc.data();
        final userId = data['userId'] ?? data['data']?['userId'];
        final ticketId = doc.id;

        await doc.reference.update({
          'status': 'accomplished',
          'completedAt': FieldValue.serverTimestamp(),
          'dropOffTimestamp': FieldValue.serverTimestamp(),
          'dropOffLocation': destination,
          'geofenceStatus': 'completed',
          'tripCompleted': true,
        });

        if (userId != null) {
          try {
            final userTicketRef = FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('preTickets')
                .doc(ticketId);

            final userTicketSnap = await userTicketRef.get();
            if (userTicketSnap.exists) {
              await userTicketRef.update({
                'status': 'accomplished',
                'dropOffTimestamp': FieldValue.serverTimestamp(),
                'dropOffLocation': destination,
                'geofenceStatus': 'completed',
                'tripCompleted': true,
                'accomplishedAt': FieldValue.serverTimestamp(),
              });
            }
          } catch (e) {
            print('⚠️ Error updating user ticket: $e');
          }
        }

        print('✅ Updated pre-ticket: ${doc.id}');
      }

      // Show notification
      await NotificationService().showDropOffNotification(
        destination: destination,
        passengerCount: passengerCount,
      );

      print('✅ Successfully processed drop-off at $destination');
    } catch (e) {
      print('❌ Error handling passenger drop-off: $e');
    }
  }

  /// Stop monitoring
  Future<void> stopMonitoring() async {
    try {
      await _positionStream?.cancel();
      _positionStream = null;
      
      _fallbackTimer?.cancel();
      _fallbackTimer = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isMonitoringKey, false);
      await prefs.remove(_conductorRouteKey);
      await prefs.remove(_conductorDocIdKey);
      await prefs.remove(_destinationsKey);

      print('✅ BackgroundGeofencingService: Monitoring stopped');
    } catch (e) {
      print('❌ Error stopping monitoring: $e');
    }
  }

  /// Check if monitoring
  Future<bool> isMonitoring() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isMonitoringKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Refresh destinations
  Future<void> refreshDestinations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final route = prefs.getString(_conductorRouteKey);
      final conductorDocId = prefs.getString(_conductorDocIdKey);
      
      if (route != null && conductorDocId != null) {
        await _fetchAndStoreDestinations(route, conductorDocId);
        print('✅ Refreshed destinations');
      }
    } catch (e) {
      print('❌ Error refreshing destinations: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _positionStream?.cancel();
    _fallbackTimer?.cancel();
  }
}