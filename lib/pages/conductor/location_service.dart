import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStream;
  Timer? _locationUpdateTimer;
  bool _isTracking = false;

  // Start location tracking for conductor
  Future<void> startLocationTracking() async {
    if (_isTracking) return;

    print('🚀 Starting location tracking...');

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable GPS.');
      }
      print('✅ Location services are enabled');

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied. Please enable location access in settings.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied. Please enable location access in app settings.');
      }
      print('✅ Location permissions granted');

      _isTracking = true;
      print('✅ Location tracking started successfully');

      // Start listening to location updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen(
        (Position position) {
          print('📍 Location update received: ${position.latitude}, ${position.longitude}');
          _updateLocationInFirestore(position);
        },
        onError: (error) {
          print('❌ Location tracking error: $error');
        },
      );

      // Also update location every 30 seconds as backup
      _locationUpdateTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
        try {
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          print('🔄 Periodic location update: ${position.latitude}, ${position.longitude}');
          _updateLocationInFirestore(position);
        } catch (e) {
          print('❌ Error getting current position: $e');
        }
      });
    } catch (e) {
      _isTracking = false;
      print('❌ Failed to start location tracking: $e');
      throw Exception('Failed to start location tracking: ${e.toString()}');
    }
  }

  // Stop location tracking
  Future<void> stopLocationTracking() async {
    _isTracking = false;
    await _positionStream?.cancel();
    _locationUpdateTimer?.cancel();
    
    // Mark conductor as offline
    await _markConductorOffline();
  }

  // Update location in Firestore
  Future<void> _updateLocationInFirestore(Position position) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No current user found');
        return;
      }

      print('🔍 Looking for conductor with email: ${user.email}');

      // Get conductor document ID
      final query = await FirebaseFirestore.instance
          .collection('conductors')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      print('📊 Query results: ${query.docs.length} documents found');

      if (query.docs.isEmpty) {
        print('❌ No conductor document found for email: ${user.email}');
        print('💡 Available conductors:');
        final allConductors = await FirebaseFirestore.instance
            .collection('conductors')
            .get();
        for (final doc in allConductors.docs) {
          print('  - ${doc.id}: ${doc.data()}');
        }
        return;
      }

      final conductorDocId = query.docs.first.id;
      final conductorData = query.docs.first.data();
      
      print('✅ Found conductor document: $conductorDocId');
      print('📋 Conductor data: $conductorData');

      // Update location in Firestore
      final updateData = {
        'currentLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
          'accuracy': position.accuracy,
          'speed': position.speed,
          'heading': position.heading,
        },
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'route': conductorData['route'] ?? '',
        'busNumber': conductorData['busNumber'] ?? '',
        'name': conductorData['name'] ?? 'Unknown Conductor',
      };

      print('🔄 Updating Firestore with data: $updateData');

      await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorDocId)
          .update(updateData);

      print('✅ Successfully updated location in Firestore');
    } catch (e) {
      print('❌ Error updating location in Firestore: $e');
    }
  }

  // Mark conductor as offline
  Future<void> _markConductorOffline() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final query = await FirebaseFirestore.instance
          .collection('conductors')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return;

      final conductorDocId = query.docs.first.id;

      await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorDocId)
          .update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking conductor offline: $e');
    }
  }

  // Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  // Check if location tracking is active
  bool get isTracking => _isTracking;
} 