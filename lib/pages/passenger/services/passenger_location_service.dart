import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/material.dart';

class PassengerLocationService {
  static final PassengerLocationService _instance = PassengerLocationService._internal();
  factory PassengerLocationService() => _instance;
  PassengerLocationService._internal();

  StreamSubscription<Position>? _positionStream;
  Timer? _locationUpdateTimer;
  bool _isTracking = false;

  // Show permission request dialog
  Future<bool> _showPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'This app needs access to your location to help conductors find you when you pre-book a ride. '
            'Your location will only be shared with the conductor of your chosen route.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Deny'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  // Get passenger's current location with explicit permission request
  Future<Position?> getCurrentLocation({BuildContext? context}) async {
    try {
      print('📍 Starting passenger location request...');
      
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('📍 Location services enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        print('❌ Location services are disabled');
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable GPS/Location services in your device settings.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        throw Exception('Location services are disabled. Please enable GPS.');
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      print('📍 Current permission status: $permission');
      
      if (permission == LocationPermission.denied) {
        print('📍 Requesting location permission...');
        
        // Show custom dialog if context is provided
        if (context != null) {
          bool userAllowed = await _showPermissionDialog(context);
          if (!userAllowed) {
            print('❌ User denied location permission through dialog');
            return null;
          }
        }
        
        permission = await Geolocator.requestPermission();
        print('📍 Permission after request: $permission');
        
        if (permission == LocationPermission.denied) {
          print('❌ Location permission denied by user');
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied. Please enable location access in settings.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          throw Exception('Location permission denied. Please enable location access in settings.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permissions permanently denied');
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied. Please enable location access in app settings.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        throw Exception('Location permissions are permanently denied. Please enable location access in app settings.');
      }

      print('📍 Getting current position with high accuracy...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // Add timeout
      );
      
      print('✅ Location captured successfully: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('❌ Error getting passenger location: $e');
      return null;
    }
  }

  // Start continuous location tracking for passengers (optional)
  Future<void> startLocationTracking({BuildContext? context}) async {
    if (_isTracking) return;

    try {
      final position = await getCurrentLocation(context: context);
      if (position == null) return;

      _isTracking = true;
      print('📍 Started passenger location tracking');

      // Update location in Firestore for conductors to see
      _positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50, // Update every 50 meters
        ),
      ).listen(
        (Position position) {
          _updatePassengerLocationInFirestore(position);
        },
        onError: (error) {
          print('❌ Passenger location tracking error: $error');
        },
      );

      // Also update location every 2 minutes as backup
      _locationUpdateTimer = Timer.periodic(Duration(minutes: 2), (timer) async {
        try {
          Position? position = await getCurrentLocation(context: context);
          if (position != null) {
            _updatePassengerLocationInFirestore(position);
          }
        } catch (e) {
          print('❌ Error getting passenger position: $e');
        }
      });
    } catch (e) {
      _isTracking = false;
      print('❌ Failed to start passenger location tracking: $e');
      throw Exception('Failed to start passenger location tracking: ${e.toString()}');
    }
  }

  // Stop location tracking
  Future<void> stopLocationTracking() async {
    _isTracking = false;
    await _positionStream?.cancel();
    _locationUpdateTimer?.cancel();
    print('📍 Stopped passenger location tracking');
  }

  // Update passenger location in Firestore
  Future<void> _updatePassengerLocationInFirestore(Position position) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No current user found for passenger location update');
        return;
      }

      final updateData = {
        'passengerLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
          'accuracy': position.accuracy,
        },
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updateData);

      print('✅ Updated passenger location in Firestore');
    } catch (e) {
      print('❌ Error updating passenger location in Firestore: $e');
    }
  }

  // Check if passenger has active pre-bookings
  Future<bool> hasActivePreBookings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .where('status', isEqualTo: 'paid')
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking active pre-bookings: $e');
      return false;
    }
  }

  // Get distance between two points
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  // Check if passenger is near a specific location
  static bool isNearLocation(double passengerLat, double passengerLon, 
                           double targetLat, double targetLon, double radiusInMeters) {
    final distance = calculateDistance(passengerLat, passengerLon, targetLat, targetLon);
    return distance <= radiusInMeters;
  }
}
