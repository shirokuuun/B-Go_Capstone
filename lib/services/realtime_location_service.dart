import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:b_go/services/offline_location_service.dart';
import 'package:b_go/services/background_location_service.dart';

class RealtimeLocationService {
  static final RealtimeLocationService _instance = RealtimeLocationService._internal();
  factory RealtimeLocationService() => _instance;
  RealtimeLocationService._internal();

  Timer? _locationTimer;
  bool _isTracking = false;
  String? _currentBookingId;
  Position? _lastKnownPosition;
  StreamSubscription<Position>? _positionStream;

  // Configuration
  static const Duration _updateInterval = Duration(seconds: 5);
  static const double _minDistanceForUpdate = 10.0; // meters
  static const Duration _locationTimeout = Duration(seconds: 15);

  /// Start real-time location tracking for a specific booking
  Future<bool> startTracking(String bookingId) async {
    if (_isTracking && _currentBookingId == bookingId) {
      print('📍 RealtimeLocationService: Already tracking booking $bookingId');
      return true;
    }

    try {
      // Stop any existing tracking
      await stopTracking();

      print('📍 RealtimeLocationService: Starting location tracking for booking $bookingId');

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ RealtimeLocationService: Location permission denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ RealtimeLocationService: Location permission permanently denied');
        return false;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ RealtimeLocationService: Location services disabled');
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
          _updateLocationInFirestore(position);
        },
        onError: (error) {
          print('❌ RealtimeLocationService: Position stream error: $error');
          // Fallback to timer-based updates
          _startFallbackTimer();
        },
      );

      // Fallback timer in case position stream fails
      _startFallbackTimer();

      print('✅ RealtimeLocationService: Location tracking started successfully');
      return true;
    } catch (e) {
      print('❌ RealtimeLocationService: Error starting tracking: $e');
      _isTracking = false;
      _currentBookingId = null;
      return false;
    }
  }

  /// Stop real-time location tracking
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    print('📍 RealtimeLocationService: Stopping location tracking');

    _isTracking = false;
    _currentBookingId = null;

    // Cancel position stream
    await _positionStream?.cancel();
    _positionStream = null;

    // Cancel timer
    _locationTimer?.cancel();
    _locationTimer = null;

    print('✅ RealtimeLocationService: Location tracking stopped');
  }

  /// Stop tracking for a specific booking (called when passenger is scanned)
  Future<void> stopTrackingForBooking(String bookingId) async {
    if (_currentBookingId == bookingId) {
      print('📍 RealtimeLocationService: Stopping tracking for specific booking: $bookingId');
      await stopTracking();
    }
  }

  /// Start fallback timer for location updates
  void _startFallbackTimer() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(_updateInterval, (timer) async {
      if (!_isTracking) {
        timer.cancel();
        return;
      }

      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: _locationTimeout,
        );
        _updateLocationInFirestore(position);
      } catch (e) {
        print('❌ RealtimeLocationService: Fallback timer error: $e');
      }
    });
  }

  /// Update location in Firestore
  Future<void> _updateLocationInFirestore(Position position) async {
    if (!_isTracking || _currentBookingId == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if location tracking has been stopped (passenger boarded)
      final bookingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .doc(_currentBookingId!);

      final bookingDoc = await bookingRef.get();
      if (!bookingDoc.exists) {
        print('📍 RealtimeLocationService: Booking document not found, stopping tracking');
        await stopTracking();
        return;
      }

      final bookingData = bookingDoc.data()!;
      final status = bookingData['status'] ?? '';
      final locationTrackingStopped = bookingData['locationTrackingStopped'] ?? false;

      // Stop tracking if passenger is boarded or location tracking is explicitly stopped
      if (status == 'boarded' || locationTrackingStopped) {
        print('📍 RealtimeLocationService: Passenger boarded or tracking stopped, stopping location updates');
        await stopTracking();
        return;
      }

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

      // Update the booking document with current location
      await bookingRef.update({
        'passengerLatitude': position.latitude,
        'passengerLongitude': position.longitude,
        'passengerLocationTimestamp': FieldValue.serverTimestamp(),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });

      print('📍 RealtimeLocationService: Updated location: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('❌ RealtimeLocationService: Error updating location in Firestore: $e');
    }
  }

  /// Check if currently tracking
  bool get isTracking => _isTracking;

  /// Get current booking ID being tracked
  String? get currentBookingId => _currentBookingId;

  /// Get tracking status for debugging
  Map<String, dynamic> get trackingStatus => {
    'isTracking': _isTracking,
    'currentBookingId': _currentBookingId,
    'lastKnownPosition': _lastKnownPosition != null ? {
      'latitude': _lastKnownPosition!.latitude,
      'longitude': _lastKnownPosition!.longitude,
    } : null,
  };

  /// Get last known position
  Position? get lastKnownPosition => _lastKnownPosition;

  /// Check if a booking is being tracked
  bool isTrackingBooking(String bookingId) {
    return _isTracking && _currentBookingId == bookingId;
  }

  /// Handle app going to background - switch to background service
  Future<void> handleAppBackgrounded() async {
    if (_isTracking && _currentBookingId != null) {
      print('🔄 RealtimeLocationService: App backgrounded, switching to background service');
      
      // Start background service for location tracking
      final backgroundService = BackgroundLocationService();
      await backgroundService.startTracking(_currentBookingId!);
      
      // Stop realtime tracking to avoid conflicts
      await stopTracking();
    }
  }

  /// Handle app coming to foreground - sync offline locations and resume realtime tracking
  Future<void> handleAppForegrounded() async {
    print('🔄 RealtimeLocationService: App foregrounded, syncing offline locations');
    
    // Sync any offline locations that were stored while app was backgrounded
    final offlineService = OfflineLocationService();
    await offlineService.syncOfflineLocations();
    
    // Sync offline locations from background service
    final backgroundService = BackgroundLocationService();
    await backgroundService.syncOfflineLocations();
    
    // Check if background service is tracking and resume realtime tracking
    final isBackgroundTracking = await backgroundService.isTracking();
    if (isBackgroundTracking) {
      final bookingId = await backgroundService.getCurrentBookingId();
      if (bookingId != null) {
        print('🔄 RealtimeLocationService: Resuming realtime tracking for booking $bookingId');
        await startTracking(bookingId);
        
        // Stop background service to avoid conflicts
        await backgroundService.stopTracking();
      }
    }
  }

  /// Check if there's an active booking that should be tracked (for app startup)
  Future<void> checkForActiveTracking() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Check if there's a paid pre-booking that should be tracked
      final preBookingsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .where('status', isEqualTo: 'paid')
          .where('locationTrackingStopped', isEqualTo: false)
          .get();

      if (preBookingsQuery.docs.isNotEmpty) {
        final booking = preBookingsQuery.docs.first;
        final bookingId = booking.id;
        final bookingData = booking.data();
        
        // Check if location tracking should be active
        final lastLocationUpdate = bookingData['lastLocationUpdate'] as Timestamp?;
        if (lastLocationUpdate != null) {
          final timeSinceLastUpdate = DateTime.now().difference(lastLocationUpdate.toDate());
          
          // If last update was within 30 minutes, resume tracking
          if (timeSinceLastUpdate.inMinutes < 30) {
            print('🔄 RealtimeLocationService: Resuming tracking for active booking: $bookingId');
            await startTracking(bookingId);
          }
        }
      }
    } catch (e) {
      print('❌ RealtimeLocationService: Error checking for active tracking: $e');
    }
  }

  /// Force update location (for manual refresh)
  Future<void> forceLocationUpdate() async {
    if (!_isTracking) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: _locationTimeout,
      );
      _updateLocationInFirestore(position);
    } catch (e) {
      print('❌ RealtimeLocationService: Error in force update: $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    stopTracking();
  }
}
