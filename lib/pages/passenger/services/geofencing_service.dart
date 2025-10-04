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
  static const double _geofenceRadius = 50.0; // 50 meters for more accurate detection
  static const Duration _checkInterval = Duration(seconds: 30); // Increased to reduce excessive checks
  static const double _locationAccuracyThreshold = 20.0; // Only process locations with accuracy better than 20m
  static const Duration _minProcessingInterval = Duration(seconds: 10); // Minimum time between processing same destination

  // Add tracking for last processing times to prevent excessive processing
  final Map<String, DateTime> _lastProcessedDestinations = {};

  /// Start monitoring passenger location for geofencing
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

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

      // Start location monitoring
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 5, // Update every 5 meters for more precise tracking
          timeLimit: Duration(seconds: 10), // Time limit for location updates
        ),
      ).listen((Position position) {
        // Only process positions with good accuracy
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
          // Only process positions with good accuracy
          if (position.accuracy <= _locationAccuracyThreshold) {
            _checkGeofencing(position);
          }
        } catch (e) {
          print('Error getting current position: $e');
        }
      });

      _isMonitoring = true;
      print('✅ Geofencing monitoring started');
    } catch (e) {
      print('Error starting geofencing: $e');
    }
  }

  /// Start conductor-based geofencing monitoring
  Future<void> startConductorMonitoring(String route, String conductorDocId) async {
    if (_isMonitoring) return;

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

      _isConductorMode = true;
      _conductorRoute = route;
      _conductorDocId = conductorDocId;

      // Start location monitoring
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 10, // Increased to reduce excessive updates
          timeLimit: Duration(seconds: 15), // Increased time limit
        ),
      ).listen((Position position) {
        // Only process positions with good accuracy
        if (position.accuracy <= _locationAccuracyThreshold) {
          _checkConductorGeofencing(position);
        }
      });

      // Also check periodically for better reliability
      _geofencingTimer = Timer.periodic(_checkInterval, (timer) async {
        try {
          // Clean up old processed destinations
          _cleanupOldProcessedDestinations();
          
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 15),
          );
          // Only process positions with good accuracy
          if (position.accuracy <= _locationAccuracyThreshold) {
            _checkConductorGeofencing(position);
          }
        } catch (e) {
          print('Error getting current position: $e');
        }
      });

      _isMonitoring = true;
      print('✅ Conductor geofencing monitoring started for route: $route');
    } catch (e) {
      print('Error starting conductor geofencing: $e');
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
    _lastProcessedDestinations.clear(); // Clear processed destinations
    print('🛑 Geofencing monitoring stopped');
  }

  /// Check if passenger has reached any destination (passenger mode)
  Future<void> _checkGeofencing(Position passengerPosition) async {
    if (_isConductorMode) return; // Skip if in conductor mode
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get all active pre-tickets for the current user
      final preTicketsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preTickets')
          .where('status', whereIn: ['pending', 'boarded'])
          .get();

      for (var doc in preTicketsSnapshot.docs) {
        final ticket = doc.data();
        final destinationName = ticket['to'];
        final route = ticket['route'];
        
        if (destinationName != null && route != null) {
          // Get destination coordinates
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

              // If passenger is within geofence radius, mark as accomplished
              if (distance <= _geofenceRadius) {
                await _markTicketAccomplished(doc.id, user.uid, passengerPosition);
                print('🎯 Pre-ticket accomplished: Passenger reached ${destinationName} (${distance.toStringAsFixed(1)}m away)');
              }
            }
          }
        }
      }

      // Also check pre-bookings
      final preBookingsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .where('status', whereIn: ['paid', 'boarded'])
          .get();

      for (var doc in preBookingsSnapshot.docs) {
        final booking = doc.data();
        final destinationName = booking['to'];
        final route = booking['route'];
        
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

              if (distance <= _geofenceRadius) {
                await _markPreBookingAccomplished(doc.id, user.uid, passengerPosition);
                print('🎯 Pre-booking accomplished: Passenger reached ${destinationName} (${distance.toStringAsFixed(1)}m away)');
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error in passenger geofencing check: $e');
    }
  }

  /// Check conductor geofencing for passenger drop-offs (conductor mode)
  Future<void> _checkConductorGeofencing(Position conductorPosition) async {
    if (!_isConductorMode || _conductorRoute == null || _conductorDocId == null) return;

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

      int totalDecremented = 0;
      Set<String> processedDestinations = {}; // Prevent duplicate processing in single check

      for (var dateDoc in remittanceSnapshot.docs) {
        final ticketsCollection = dateDoc.reference.collection('tickets');
        final tickets = await ticketsCollection.get();

        for (var ticketDoc in tickets.docs) {
          final ticket = ticketDoc.data();
          final destinationName = ticket['to'];
          final isActive = ticket['active'] ?? false;
          
          if (isActive && destinationName != null && !processedDestinations.contains(destinationName)) {
            // Check if we've processed this destination recently to prevent excessive processing
            final lastProcessed = _lastProcessedDestinations[destinationName];
            if (lastProcessed != null && 
                DateTime.now().difference(lastProcessed) < _minProcessingInterval) {
              print('⏰ Skipping $destinationName - processed too recently');
              continue; // Skip if processed too recently
            }
            
            // Get destination coordinates
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

                print('🎯 Destination $destinationName: ${distance.toStringAsFixed(1)}m away');

                // Enhanced geofencing: Check if conductor is approaching and within radius
                if (distance <= _geofenceRadius && await _isApproachingDestination(conductorPosition, lat, lng)) {
                  final quantity = (ticket['quantity'] as num?)?.toInt() ?? 1;
                  await _markConductorTicketCompleted(ticketDoc.reference, quantity);
                  totalDecremented += quantity;
                  processedDestinations.add(destinationName);
                  _lastProcessedDestinations[destinationName] = DateTime.now(); // Track processing time
                  print('🎯 Conductor reached ${destinationName}: ${quantity} passenger(s) dropped off (${distance.toStringAsFixed(1)}m away)');
                } else if (distance <= _geofenceRadius) {
                  print('⚠️ Within geofence radius but not approaching destination');
                }
              }
            } else {
              print('❌ Could not get coordinates for destination: $destinationName');
            }
          }
        }
      }

      // Also check pre-bookings and pre-tickets
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
        final quantity = booking['data']?['quantity'] ?? 1;
        
        print('📖 Pre-booking ${doc.id}: to=$destinationName, quantity=$quantity');
        
        if (destinationName != null && !processedDestinations.contains(destinationName)) {
          // Check if we've processed this destination recently
          final lastProcessed = _lastProcessedDestinations[destinationName];
          if (lastProcessed != null && 
              DateTime.now().difference(lastProcessed) < _minProcessingInterval) {
            print('⏰ Skipping pre-booking $destinationName - processed too recently');
            continue; // Skip if processed too recently
          }
          
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

              if (distance <= _geofenceRadius && await _isApproachingDestination(conductorPosition, lat, lng)) {
                final qty = (quantity as num?)?.toInt() ?? 1;
                await _markPreBookingCompleted(doc.reference, qty);
                totalDecremented += qty;
                processedDestinations.add(destinationName);
                _lastProcessedDestinations[destinationName] = DateTime.now(); // Track processing time
                print('🎯 Pre-booking completed: ${qty} passenger(s) dropped off at ${destinationName} (${distance.toStringAsFixed(1)}m away)');
              } else if (distance <= _geofenceRadius) {
                print('⚠️ Pre-booking within geofence radius but not approaching destination');
              }
            }
          } else {
            print('❌ Could not get coordinates for pre-booking destination: $destinationName');
          }
        }
      }

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
        final quantity = ticket['data']?['quantity'] ?? 1;
        
        print('🎫 Pre-ticket ${doc.id}: to=$destinationName, quantity=$quantity');
        
        if (destinationName != null && !processedDestinations.contains(destinationName)) {
          // Check if we've processed this destination recently
          final lastProcessed = _lastProcessedDestinations[destinationName];
          if (lastProcessed != null && 
              DateTime.now().difference(lastProcessed) < _minProcessingInterval) {
            print('⏰ Skipping pre-ticket $destinationName - processed too recently');
            continue; // Skip if processed too recently
          }
          
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

              if (distance <= _geofenceRadius && await _isApproachingDestination(conductorPosition, lat, lng)) {
                final qty = (quantity as num?)?.toInt() ?? 1;
                await _markPreTicketCompleted(doc.reference, qty);
                totalDecremented += qty;
                processedDestinations.add(destinationName);
                _lastProcessedDestinations[destinationName] = DateTime.now(); // Track processing time
                print('🎯 Pre-ticket completed: ${qty} passenger(s) dropped off at ${destinationName} (${distance.toStringAsFixed(1)}m away)');
              } else if (distance <= _geofenceRadius) {
                print('⚠️ Pre-ticket within geofence radius but not approaching destination');
              }
            }
          } else {
            print('❌ Could not get coordinates for pre-ticket destination: $destinationName');
          }
        }
      }

      if (totalDecremented > 0) {
        // Update conductor's passenger count
        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(_conductorDocId!)
            .update({
          'passengerCount': FieldValue.increment(-totalDecremented),
          'lastDropOff': FieldValue.serverTimestamp(),
        });
        
        print('✅ Total passengers dropped off: $totalDecremented');
        print('✅ Conductor passenger count updated');
      } else {
        print('ℹ️ No passengers dropped off in this geofencing check');
      }

    } catch (e) {
      print('Error in conductor geofencing check: $e');
    }
  }

  /// Check if the conductor is actually approaching the destination
  /// This helps prevent false positives when the bus is just passing by
  Future<bool> _isApproachingDestination(Position currentPosition, double destLat, double destLng) async {
    try {
      // Get the last known position from the conductor document
      final conductorDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(_conductorDocId!)
          .get();
      
      if (!conductorDoc.exists) return true; // If no previous position, allow processing
      
      final conductorData = conductorDoc.data() as Map<String, dynamic>;
      final lastPosition = conductorData['lastPosition'] as Map<String, dynamic>?;
      
      if (lastPosition == null) return true; // If no previous position, allow processing
      
      final lastLat = lastPosition['latitude'] as num?;
      final lastLng = lastPosition['longitude'] as num?;
      
      if (lastLat == null || lastLng == null) return true;
      
      // Calculate distances
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
      
      // Check if we're getting closer to the destination
      // Allow some tolerance to account for GPS accuracy
      final tolerance = 5.0; // 5 meters tolerance
      final isApproaching = currentDistance < (previousDistance - tolerance);
      
      // Only update the last position if we're significantly different
      final positionChange = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        lastLat.toDouble(),
        lastLng.toDouble(),
      );
      
      if (positionChange > 10.0) { // Only update if moved more than 10 meters
        // Update the last position
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
      return true; // If there's an error, allow processing to be safe
    }
  }

  /// Get destination coordinates from route data or geocoding
  Future<Map<String, double>?> _getDestinationCoordinates(String destinationName, String route) async {
    try {
      // Try to get coordinates from the route places first
      final places = await RouteService.fetchPlaces(route, placeCollection: 'Place');
      final places2 = await RouteService.fetchPlaces(route, placeCollection: 'Place 2');
      
      // Combine both collections
      final allPlaces = [...places, ...places2];
      
      // Find the destination place
      final destinationPlace = allPlaces.firstWhere(
        (place) => place['name'] == destinationName,
        orElse: () => {},
      );
      
      if (destinationPlace.isNotEmpty && destinationPlace['coordinates'] != null) {
        final coords = destinationPlace['coordinates'];
        if (coords is Map) {
          final lat = coords['latitude'];
          final lng = coords['longitude'];
          if (lat != null && lng != null) {
            try {
              final latValue = (lat as num).toDouble();
              final lngValue = (lng as num).toDouble();
              return {
                'latitude': latValue,
                'longitude': lngValue,
              };
            } catch (e) {
              print('Error converting coordinates: $e');
            }
          }
        }
      }
      
      // If no coordinates found in route data, try geocoding
      try {
        List<Location> locations = await locationFromAddress('$destinationName, Philippines');
        if (locations.isNotEmpty) {
          return {
            'latitude': locations.first.latitude,
            'longitude': locations.first.longitude,
          };
        }
      } catch (e) {
        print('Geocoding failed for $destinationName: $e');
      }
      
      return null;
    } catch (e) {
      print('Error getting destination coordinates: $e');
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
      print('Error marking ticket as accomplished: $e');
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
      print('Error marking pre-booking as accomplished: $e');
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
      print('Error marking conductor ticket as completed: $e');
    }
  }

  /// Mark pre-booking as completed (conductor mode)
  Future<void> _markPreBookingCompleted(DocumentReference bookingRef, int quantity) async {
    try {
      await bookingRef.update({
        'status': 'completed',
        'boardingStatus': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Pre-booking ${bookingRef.id} marked as completed for $quantity passenger(s)');
    } catch (e) {
      print('Error marking pre-booking as completed: $e');
    }
  }

  /// Mark pre-ticket as completed (conductor mode)
  Future<void> _markPreTicketCompleted(DocumentReference ticketRef, int quantity) async {
    try {
      await ticketRef.update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Pre-ticket ${ticketRef.id} marked as completed for $quantity passenger(s)');
    } catch (e) {
      print('Error marking pre-ticket as completed: $e');
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
