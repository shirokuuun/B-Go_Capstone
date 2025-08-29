import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;

class GeofencingService {
  static const double _dropOffRadius = 100.0;
  static const double _readyDropOffRadius = 50.0;
  static const double _geofencingThreshold = 15.0; // Increased threshold
  static const Duration _geofencingCooldown = Duration(minutes: 1); // Longer cooldown
  
  // Batch processing limits
  static const int _maxBatchSize = 5;
  static const Duration _batchDelay = Duration(seconds: 2);

  Position? _lastGeofencingPosition;
  DateTime? _lastGeofencingCheck;
  bool _isActive = false;
  Timer? _batchTimer;
  List<Map<String, dynamic>> _pendingDropOffs = [];

  // Callback functions
  final Function(List<Map<String, dynamic>>) onPassengersNearDropOff;
  final Function(List<Map<String, dynamic>>) onPassengersReadyForDropOff;
  final Function(String, String, String, int) onPassengerDroppedOff;
  final Function(int) onPassengerCountUpdated;

  GeofencingService({
    required this.onPassengersNearDropOff,
    required this.onPassengersReadyForDropOff,
    required this.onPassengerDroppedOff,
    required this.onPassengerCountUpdated,
  });

  void startGeofencing(Position currentPosition) {
    if (_isActive) return;
    
    _isActive = true;
    _lastGeofencingPosition = currentPosition;
    print('🗺️ GeofencingService: Geofencing started');
  }

  void stopGeofencing() {
    _isActive = false;
    _batchTimer?.cancel();
    _batchTimer = null;
    _pendingDropOffs.clear();
    print('🗺️ GeofencingService: Geofencing stopped');
  }

  void pauseGeofencing() {
    _batchTimer?.cancel();
    print('🗺️ GeofencingService: Geofencing paused');
  }

  void resumeGeofencing() {
    if (_isActive && _batchTimer == null) {
      _startBatchTimer();
      print('🗺️ GeofencingService: Geofencing resumed');
    }
  }

  void _startBatchTimer() {
    _batchTimer = Timer.periodic(_batchDelay, (timer) {
      if (_pendingDropOffs.isNotEmpty) {
        _processPendingDropOffs();
      }
    });
  }

  // Optimized geofencing check with better performance
  Future<void> checkPassengerDropOffs({
    required Position currentPosition,
    required List<Map<String, dynamic>> activeBookings,
    required BuildContext context,
  }) async {
    if (!_isActive || activeBookings.isEmpty) return;

    // More aggressive cooldown check
    if (_lastGeofencingCheck != null && 
        DateTime.now().difference(_lastGeofencingCheck!) < _geofencingCooldown) {
      return;
    }

    // Check movement threshold
    if (_lastGeofencingPosition != null) {
      final distanceMoved = _calculateQuickDistance(
        _lastGeofencingPosition!.latitude,
        _lastGeofencingPosition!.longitude,
        currentPosition.latitude,
        currentPosition.longitude,
      );
      
      if (distanceMoved < _geofencingThreshold) {
        return;
      }
    }

    await _performGeofencingCheck(currentPosition, activeBookings);
    
    _lastGeofencingPosition = currentPosition;
    _lastGeofencingCheck = DateTime.now();
  }

  Future<void> _performGeofencingCheck(
    Position currentPosition, 
    List<Map<String, dynamic>> activeBookings
  ) async {
    final conductorLat = currentPosition.latitude;
    final conductorLng = currentPosition.longitude;
    
    List<Map<String, dynamic>> passengersNearDropOff = [];
    List<Map<String, dynamic>> readyForDropOff = [];

    // Pre-filter by rough distance to avoid expensive calculations
    final candidates = activeBookings.where((booking) {
      final toLat = booking['toLatitude'];
      final toLng = booking['toLongitude'];
      
      if (toLat == null || toLng == null) return false;
      
      // Quick bounding box check first
      final latDiff = (toLat - conductorLat).abs();
      final lngDiff = (toLng - conductorLng).abs();
      
      // Rough check: 0.001 degrees ≈ 100m
      return latDiff < 0.002 && lngDiff < 0.002;
    }).toList();

    if (candidates.isEmpty) return;

    print('🗺️ GeofencingService: Checking ${candidates.length} candidates');

    // Process candidates in batches to avoid blocking UI
    for (int i = 0; i < candidates.length; i += _maxBatchSize) {
      final batch = candidates.skip(i).take(_maxBatchSize);
      
      for (final booking in batch) {
        final toLat = booking['toLatitude'];
        final toLng = booking['toLongitude'];
        
        final distance = _calculateQuickDistance(
          conductorLat, conductorLng, toLat, toLng
        );

        if (distance <= _dropOffRadius) {
          if (distance <= _readyDropOffRadius) {
            readyForDropOff.add(booking);
          } else {
            passengersNearDropOff.add(booking);
          }
        }
      }
      
      // Small delay between batches to prevent blocking
      if (i + _maxBatchSize < candidates.length) {
        await Future.delayed(Duration(milliseconds: 50));
      }
    }

    // Update UI
    onPassengersNearDropOff(passengersNearDropOff);

    // Batch process drop-offs
    if (readyForDropOff.isNotEmpty) {
      _pendingDropOffs.addAll(readyForDropOff);
      if (_batchTimer == null) {
        _startBatchTimer();
      }
    }
  }

  void _processPendingDropOffs() async {
    if (_pendingDropOffs.isEmpty) return;
    
    final batch = _pendingDropOffs.take(_maxBatchSize).toList();
    _pendingDropOffs.removeRange(0, math.min(_maxBatchSize, _pendingDropOffs.length));
    
    for (final passenger in batch) {
      final passengerId = passenger['id'];
      final quantity = passenger['quantity'] ?? 1;
      final from = passenger['from'];
      final to = passenger['to'];

      try {
        await _updatePassengerStatus(passengerId, 'dropped_off');
        onPassengerDroppedOff(passengerId, from, to, quantity);
      } catch (e) {
        print('🗺️ GeofencingService: Error processing drop-off: $e');
      }
    }
    
    // Stop timer if no more pending
    if (_pendingDropOffs.isEmpty) {
      _batchTimer?.cancel();
      _batchTimer = null;
    }
  }

  // Optimized distance calculation
  double _calculateQuickDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000;
    
    final dLat = (lat2 - lat1) * 0.017453292519943295; // Convert to radians
    final dLng = (lng2 - lng1) * 0.017453292519943295;
    
    final a = math.sin(dLat * 0.5) * math.sin(dLat * 0.5) +
        math.cos(lat1 * 0.017453292519943295) * 
        math.cos(lat2 * 0.017453292519943295) *
        math.sin(dLng * 0.5) * math.sin(dLng * 0.5);
    
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Future<void> _updatePassengerStatus(String passengerId, String status) async {
    try {
      // Use a more efficient query
      final query = await FirebaseFirestore.instance
          .collectionGroup('preBookings')
          .where(FieldPath.documentId, isEqualTo: passengerId)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({
          'status': status,
          'dropOffTimestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('🗺️ GeofencingService: Error updating status: $e');
      rethrow;
    }
  }

  String getGeofencingStatus(List<Map<String, dynamic>> passengersNearDropOff, Position? currentPosition) {
    if (passengersNearDropOff.isEmpty) return 'No passengers near drop-off';
    if (currentPosition == null) return 'Location not available';
    
    return '${passengersNearDropOff.length} passengers nearby';
  }

  void manualCheck() {
    _lastGeofencingCheck = null;
    print('🗺️ GeofencingService: Manual check triggered');
  }

  void dispose() {
    stopGeofencing();
  }
}