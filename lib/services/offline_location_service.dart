import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline-capable location service that stores locations locally when offline
class OfflineLocationService {
  static final OfflineLocationService _instance = OfflineLocationService._internal();
  factory OfflineLocationService() => _instance;
  OfflineLocationService._internal();

  Timer? _locationTimer;
  bool _isTracking = false;
  String? _currentBookingId;
  Position? _lastKnownPosition;
  StreamSubscription<Position>? _positionStream;

  // Configuration
  static const Duration _updateInterval = Duration(seconds: 10);
  static const double _minDistanceForUpdate = 10.0; // meters
  static const Duration _locationTimeout = Duration(seconds: 15);
  
  // Persistent storage key for offline locations
  static const String _offlineLocationsKey = 'offline_locations';

  /// Start location tracking with offline capability
  Future<bool> startTracking(String bookingId) async {
    if (_isTracking) {
      print('📍 OfflineLocationService: Already tracking, stopping previous instance');
      await stopTracking();
    }

    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ OfflineLocationService: Location permission denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ OfflineLocationService: Location permission permanently denied');
        return false;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ OfflineLocationService: Location services disabled');
        return false;
      }

      _currentBookingId = bookingId;
      _isTracking = true;

      // Start position stream for more accurate tracking
      _positionStream = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: _minDistanceForUpdate.toInt(),
          timeLimit: _locationTimeout,
        ),
      ).listen(
        (Position position) {
          _updateLocationWithOfflineSupport(position);
        },
        onError: (error) {
          print('❌ OfflineLocationService: Position stream error: $error');
          // Fallback to timer-based updates
          _startFallbackTimer();
        },
      );

      // Fallback timer in case position stream fails
      _startFallbackTimer();

      print('✅ OfflineLocationService: Location tracking started successfully');
      return true;
    } catch (e) {
      print('❌ OfflineLocationService: Error starting tracking: $e');
      _isTracking = false;
      _currentBookingId = null;
      return false;
    }
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    print('📍 OfflineLocationService: Stopping location tracking');

    _isTracking = false;
    _currentBookingId = null;

    // Cancel position stream
    await _positionStream?.cancel();
    _positionStream = null;

    // Cancel timer
    _locationTimer?.cancel();
    _locationTimer = null;

    print('✅ OfflineLocationService: Location tracking stopped');
  }

  /// Start fallback timer for location updates
  void _startFallbackTimer() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(_updateInterval, (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: _locationTimeout,
        );
        _updateLocationWithOfflineSupport(position);
      } catch (e) {
        print('❌ OfflineLocationService: Fallback timer error: $e');
      }
    });
  }

  /// Update location with offline support
  Future<void> _updateLocationWithOfflineSupport(Position position) async {
    if (!_isTracking || _currentBookingId == null) return;

    // Check if position has changed significantly
    if (_lastKnownPosition != null) {
      double distance = Geolocator.distanceBetween(
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

    try {
      // Try to update Firestore first
      bool firestoreUpdated = await _updateLocationInFirestore(position);
      
      if (firestoreUpdated) {
        print('📍 OfflineLocationService: Updated location in Firestore: ${position.latitude}, ${position.longitude}');
        // Clear any offline locations since we successfully updated Firestore
        await _clearOfflineLocations();
      } else {
        // Store location offline for later sync
        await _storeLocationOffline(position);
        print('📍 OfflineLocationService: Stored location offline: ${position.latitude}, ${position.longitude}');
      }
    } catch (e) {
      print('❌ OfflineLocationService: Error updating location: $e');
      // Store location offline as fallback
      await _storeLocationOffline(position);
    }
  }

  /// Update location in Firestore
  Future<bool> _updateLocationInFirestore(Position position) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Check if location tracking has been stopped (passenger boarded)
      final bookingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .doc(_currentBookingId!);

      final bookingDoc = await bookingRef.get();
      if (!bookingDoc.exists) {
        print('📍 OfflineLocationService: Booking document not found, stopping tracking');
        await stopTracking();
        return false;
      }

      final bookingData = bookingDoc.data()!;
      final status = bookingData['status'] ?? '';
      final locationTrackingStopped = bookingData['locationTrackingStopped'] ?? false;

      // Stop tracking if passenger is boarded or location tracking is explicitly stopped
      if (status == 'boarded' || locationTrackingStopped) {
        print('📍 OfflineLocationService: Passenger boarded or tracking stopped, stopping location updates');
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
      print('❌ OfflineLocationService: Error updating location in Firestore: $e');
      return false;
    }
  }

  /// Store location offline for later sync
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
      print('❌ OfflineLocationService: Error storing location offline: $e');
    }
  }

  /// Sync offline locations to Firestore
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
      
      print('🔄 OfflineLocationService: Syncing ${offlineLocations.length} offline locations');
      
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
          print('❌ OfflineLocationService: Error syncing individual location: $e');
        }
      }
      
      // Clear offline locations after successful sync
      await _clearOfflineLocations();
      print('✅ OfflineLocationService: Successfully synced offline locations');
      
    } catch (e) {
      print('❌ OfflineLocationService: Error syncing offline locations: $e');
    }
  }

  /// Clear offline locations
  Future<void> _clearOfflineLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_offlineLocationsKey);
    } catch (e) {
      print('❌ OfflineLocationService: Error clearing offline locations: $e');
    }
  }

  /// Check if currently tracking
  bool get isTracking => _isTracking;

  /// Get current booking ID being tracked
  String? get currentBookingId => _currentBookingId;

  /// Get last known position
  Position? get lastKnownPosition => _lastKnownPosition;

  /// Check if a booking is being tracked
  bool isTrackingBooking(String bookingId) {
    return _isTracking && _currentBookingId == bookingId;
  }
}
