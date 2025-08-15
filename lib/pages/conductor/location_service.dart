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
    
    // Debug authentication state
    await debugAuthState();

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

      print('🔍 Looking for conductor with UID: ${user.uid}');
      print('📧 Current user email: ${user.email}');
      print('🆔 Current user display name: ${user.displayName}');

      // Only work with conductors that have uid field (created via admin website)
      final query = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      print('📊 Query results: ${query.docs.length} documents found');
      
      if (query.docs.isEmpty) {
        print('❌ No conductor document found with UID: ${user.uid}');
        print('💡 This conductor must be created via the admin website to have a uid field');
        print('💡 Available conductors:');
        final allConductors = await FirebaseFirestore.instance
            .collection('conductors')
            .get();
        for (final doc in allConductors.docs) {
          final data = doc.data();
          print('    ${doc.id}: uid=${data['uid']}, email=${data['email']}');
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
        // Ensure uid field is set for consistency
        'uid': conductorData['uid'] ?? conductorDocId,
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
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final conductorDocId = query.docs.first.id;
        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorDocId)
            .update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
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
  
  // Debug method to check current authentication state
  Future<void> debugAuthState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user is currently authenticated');
      return;
    }
    
    print('🔍 Current authentication state:');
    print('  - UID: ${user.uid}');
    print('  - Email: ${user.email}');
    print('  - Display Name: ${user.displayName}');
    print('  - Email Verified: ${user.emailVerified}');
    print('  - Is Anonymous: ${user.isAnonymous}');
    
    // Check if this user exists in the conductors collection
    final query = await FirebaseFirestore.instance
        .collection('conductors')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();
    
    if (query.docs.isEmpty) {
      print('❌ No conductor document found for this user');
    } else {
      final data = query.docs.first.data();
      print('✅ Found conductor document:');
      print('  - Document ID: ${query.docs.first.id}');
      print('  - Name: ${data['name']}');
      print('  - Email: ${data['email']}');
      print('  - Route: ${data['route']}');
      print('  - Is Online: ${data['isOnline']}');
    }
  }
  
  // Force sign out to clear any cached authentication state
  Future<void> forceSignOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      print('✅ Successfully signed out');
    } catch (e) {
      print('❌ Error signing out: $e');
    }
  }
} 