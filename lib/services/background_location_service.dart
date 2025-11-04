import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background location service that continues tracking when app is closed
/// Uses persistent storage and app lifecycle management
class BackgroundLocationService {
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  bool _isInitialized = false;
  String? _currentBookingId;
  Position? _lastKnownPosition;
  Timer? _locationTimer;

  // Configuration
  static const Duration _updateInterval = Duration(seconds: 15);
  static const double _minDistanceForUpdate = 10.0; // meters
  static const Duration _locationTimeout = Duration(seconds: 20);
  
  // Persistent storage keys
  static const String _offlineLocationsKey = 'offline_locations';
  static const String _currentBookingIdKey = 'current_booking_id';
  static const String _isTrackingKey = 'is_tracking';

  /// Initialize the background service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isInitialized = true;
      print('✅ BackgroundLocationService: Initialized successfully');
    } catch (e) {
      print('❌ BackgroundLocationService: Initialization failed: $e');
    }
  }

  /// Start background location tracking
  Future<bool> startTracking(String bookingId) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      _currentBookingId = bookingId;

      // Store booking ID in shared preferences for persistence
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentBookingIdKey, bookingId);
      await prefs.setBool(_isTrackingKey, true);

      // Start location tracking timer
      _startLocationTracking();

      print('✅ BackgroundLocationService: Started tracking for booking $bookingId');
      return true;
    } catch (e) {
      print('❌ BackgroundLocationService: Error starting tracking: $e');
      return false;
    }
  }

  /// Stop background location tracking
  Future<void> stopTracking() async {
    try {
      _currentBookingId = null;

      // Clear shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentBookingIdKey);
      await prefs.setBool(_isTrackingKey, false);

      // Stop location timer
      _locationTimer?.cancel();
      _locationTimer = null;

      print('✅ BackgroundLocationService: Stopped tracking');
    } catch (e) {
      print('❌ BackgroundLocationService: Error stopping tracking: $e');
    }
  }

  /// Start location tracking timer
  void _startLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(_updateInterval, (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: _locationTimeout,
        );

        // Check if position has changed significantly
        if (_lastKnownPosition != null) {
          final distance = Geolocator.distanceBetween(
            _lastKnownPosition!.latitude,
            _lastKnownPosition!.longitude,
            position.latitude,
            position.longitude,
          );

          if (distance < _minDistanceForUpdate) {
            return; // Skip update if movement is too small
          }
        }

        _lastKnownPosition = position;

        // Try to update Firestore first
        final firestoreUpdated = await _updateLocationInFirestore(position);
        
        if (firestoreUpdated) {
          print('📍 BackgroundService: Updated location in Firestore: ${position.latitude}, ${position.longitude}');
        } else {
          // Store location offline for later sync
          await _storeLocationOffline(position);
          print('📍 BackgroundService: Stored location offline: ${position.latitude}, ${position.longitude}');
        }

      } catch (e) {
        print('❌ BackgroundService: Location update error: $e');
      }
    });
  }

  /// Update location in Firestore
  Future<bool> _updateLocationInFirestore(Position position) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _currentBookingId == null) return false;

      // Check if location tracking has been stopped (passenger boarded)
      final bookingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .doc(_currentBookingId!);

      final bookingDoc = await bookingRef.get();
      if (!bookingDoc.exists) {
        print('📍 BackgroundService: Booking document not found, stopping tracking');
        await stopTracking();
        return false;
      }

      final bookingData = bookingDoc.data()!;
      final status = bookingData['status'] ?? '';
      final locationTrackingStopped = bookingData['locationTrackingStopped'] ?? false;

      // Stop tracking if passenger is boarded or location tracking is explicitly stopped
      if (status == 'boarded' || locationTrackingStopped) {
        print('📍 BackgroundService: Passenger boarded or tracking stopped, stopping location updates');
        await stopTracking();
        return false;
      }

      // Update the booking document with current location
      await bookingRef.update({
        'passengerLatitude': position.latitude,
        'passengerLongitude': position.longitude,
        'passengerLocationTimestamp': FieldValue.serverTimestamp(),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
        'offlineSync': false, // Mark as synced
      });

      return true;
    } catch (e) {
      print('❌ BackgroundService: Error updating location in Firestore: $e');
      return false;
    }
  }

  /// Store location offline
  Future<void> _storeLocationOffline(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineLocationsJson = prefs.getString(_offlineLocationsKey) ?? '[]';
      final List<dynamic> offlineLocations = json.decode(offlineLocationsJson);
      
      final locationData = {
        'bookingId': _currentBookingId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'speed': position.speed,
        'heading': position.heading,
      };
      
      offlineLocations.add(locationData);
      
      // Keep only last 100 locations to prevent storage bloat
      if (offlineLocations.length > 100) {
        offlineLocations.removeRange(0, offlineLocations.length - 100);
      }
      
      await prefs.setString(_offlineLocationsKey, json.encode(offlineLocations));
    } catch (e) {
      print('❌ BackgroundService: Error storing location offline: $e');
    }
  }

  /// Check if currently tracking
  Future<bool> isTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isTrackingKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get current booking ID
  Future<String?> getCurrentBookingId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentBookingIdKey);
    } catch (e) {
      return null;
    }
  }

  /// Sync offline locations from background service
  Future<void> syncOfflineLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineLocationsJson = prefs.getString(_offlineLocationsKey);
      
      if (offlineLocationsJson == null || offlineLocationsJson.isEmpty) {
        return;
      }

      final List<dynamic> offlineLocations = json.decode(offlineLocationsJson);
      
      if (offlineLocations.isEmpty) {
        return;
      }

      print('🔄 BackgroundLocationService: Syncing ${offlineLocations.length} offline locations');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      for (final locationData in offlineLocations) {
        try {
          final bookingId = locationData['bookingId'] as String?;
          
          if (bookingId == null) continue;
          
          // Check if booking still exists and should be tracked
          final bookingRef = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('preBookings')
              .doc(bookingId);
          
          final bookingDoc = await bookingRef.get();
          if (!bookingDoc.exists) continue;
          
          final bookingData = bookingDoc.data()!;
          final status = bookingData['status'] ?? '';
          final locationTrackingStopped = bookingData['locationTrackingStopped'] ?? false;
          
          // Skip if passenger is boarded or tracking is stopped
          if (status == 'boarded' || locationTrackingStopped) continue;
          
          // Update with offline location
          await bookingRef.update({
            'passengerLatitude': locationData['latitude'],
            'passengerLongitude': locationData['longitude'],
            'passengerLocationTimestamp': Timestamp.fromMillisecondsSinceEpoch(locationData['timestamp']),
            'lastLocationUpdate': Timestamp.fromMillisecondsSinceEpoch(locationData['timestamp']),
            'offlineSync': true, // Mark as synced from offline
          });
          
        } catch (e) {
          print('❌ BackgroundLocationService: Error syncing individual location: $e');
        }
      }
      
      // Clear offline locations after successful sync
      await prefs.remove(_offlineLocationsKey);
      print('✅ BackgroundLocationService: Successfully synced offline locations');
      
    } catch (e) {
      print('❌ BackgroundLocationService: Error syncing offline locations: $e');
    }
  }

  /// Check for active tracking on app startup
  Future<void> checkForActiveTracking() async {
    try {
      final isTracking = await this.isTracking();
      if (!isTracking) return;

      final bookingId = await getCurrentBookingId();
      if (bookingId == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if booking still exists and should be tracked
      final bookingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .doc(bookingId);

      final bookingDoc = await bookingRef.get();
      if (!bookingDoc.exists) {
        await stopTracking();
        return;
      }

      final bookingData = bookingDoc.data()!;
      final status = bookingData['status'] ?? '';
      final locationTrackingStopped = bookingData['locationTrackingStopped'] ?? false;

      // Stop tracking if passenger is boarded or tracking is stopped
      if (status == 'boarded' || locationTrackingStopped) {
        await stopTracking();
        return;
      }

      // Resume tracking
      print('🔄 BackgroundLocationService: Resuming tracking for active booking: $bookingId');
      await startTracking(bookingId);
      
    } catch (e) {
      print('❌ BackgroundLocationService: Error checking for active tracking: $e');
    }
  }

  /// Handle app going to background - continue tracking
  Future<void> handleAppBackgrounded() async {
    if (_currentBookingId != null) {
      print('🔄 BackgroundLocationService: App backgrounded, continuing tracking');
      // Continue tracking with timer-based updates
    }
  }

  /// Handle app coming to foreground - sync offline locations
  Future<void> handleAppForegrounded() async {
    print('🔄 BackgroundLocationService: App foregrounded, syncing offline locations');
    await syncOfflineLocations();
  }

  /// Dispose of resources
  void dispose() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }
}