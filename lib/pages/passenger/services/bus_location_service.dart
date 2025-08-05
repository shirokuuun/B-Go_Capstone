import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';

class BusLocation {
  final String conductorId;
  final String conductorName;
  final String route;
  final String busNumber;
  final LatLng location;
  final DateTime timestamp;
  final double speed;
  final double heading;
  final bool isOnline;

  BusLocation({
    required this.conductorId,
    required this.conductorName,
    required this.route,
    required this.busNumber,
    required this.location,
    required this.timestamp,
    required this.speed,
    required this.heading,
    required this.isOnline,
  });

  factory BusLocation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final locationData = data['currentLocation'] as Map<String, dynamic>?;
    
    // Only accept conductors with uid field (created via admin website)
    if (data['uid'] == null) {
      print('❌ Skipping conductor ${doc.id} - no uid field (not created via admin website)');
      return BusLocation(
        conductorId: '',
        conductorName: '',
        route: '',
        busNumber: '',
        location: const LatLng(0, 0),
        timestamp: DateTime.now(),
        speed: 0.0,
        heading: 0.0,
        isOnline: false,
      );
    }
    
    final conductorId = data['uid'] as String;
    
    print('🔍 Processing conductor document: ${doc.id}');
    print('📋 Document data: $data');
    print('📍 Location data: $locationData');
    print('🆔 Using conductor ID: $conductorId');
    
    // Check if location data is valid
    LatLng location;
    if (locationData != null && 
        locationData['latitude'] != null && 
        locationData['longitude'] != null) {
      try {
        // Handle different number types (int, double, etc.)
        final lat = locationData['latitude'];
        final lng = locationData['longitude'];
        
        double latitude, longitude;
        
        if (lat is int) {
          latitude = lat.toDouble();
        } else if (lat is double) {
          latitude = lat;
        } else if (lat is num) {
          latitude = lat.toDouble();
        } else {
          print('❌ Invalid latitude type: ${lat.runtimeType}');
          location = const LatLng(0, 0);
          return BusLocation(
            conductorId: conductorId,
            conductorName: data['name'] ?? 'Unknown',
            route: data['route'] ?? 'Unknown Route',
            busNumber: data['busNumber'] ?? 'Unknown',
            location: location,
            timestamp: locationData?['timestamp']?.toDate() ?? DateTime.now(),
            speed: locationData?['speed']?.toDouble() ?? 0.0,
            heading: locationData?['heading']?.toDouble() ?? 0.0,
            isOnline: data['isOnline'] ?? false,
          );
        }
        
        if (lng is int) {
          longitude = lng.toDouble();
        } else if (lng is double) {
          longitude = lng;
        } else if (lng is num) {
          longitude = lng.toDouble();
        } else {
          print('❌ Invalid longitude type: ${lng.runtimeType}');
          location = const LatLng(0, 0);
          return BusLocation(
            conductorId: conductorId,
            conductorName: data['name'] ?? 'Unknown',
            route: data['route'] ?? 'Unknown Route',
            busNumber: data['busNumber'] ?? 'Unknown',
            location: location,
            timestamp: locationData?['timestamp']?.toDate() ?? DateTime.now(),
            speed: locationData?['speed']?.toDouble() ?? 0.0,
            heading: locationData?['heading']?.toDouble() ?? 0.0,
            isOnline: data['isOnline'] ?? false,
          );
        }
        
        location = LatLng(latitude, longitude);
        print('✅ Valid location found: ${location.latitude}, ${location.longitude}');
      } catch (e) {
        print('❌ Error parsing location data: $e');
        location = const LatLng(0, 0);
      }
    } else {
      location = const LatLng(0, 0);
      print('❌ Invalid location data, using default: ${location.latitude}, ${location.longitude}');
    }
    
    final bus = BusLocation(
      conductorId: conductorId,
      conductorName: data['name'] ?? 'Unknown',
      route: data['route'] ?? 'Unknown Route',
      busNumber: data['busNumber']?.toString() ?? 'Unknown',
      location: location,
      timestamp: locationData?['timestamp']?.toDate() ?? DateTime.now(),
      speed: locationData?['speed']?.toDouble() ?? 0.0,
      heading: locationData?['heading']?.toDouble() ?? 0.0,
      isOnline: data['isOnline'] ?? false,
    );
    
    print('✅ Created bus: ${bus.conductorId} - ${bus.route} at ${bus.location}');
    print('📍 Bus location check: lat=${bus.location.latitude}, lng=${bus.location.longitude}');
    print('📍 Is valid location: ${bus.location.latitude != 0 && bus.location.longitude != 0}');
    return bus;
  }
}

class BusLocationService {
  static final BusLocationService _instance = BusLocationService._internal();
  factory BusLocationService() => _instance;
  BusLocationService._internal();

  // Get stream of all online buses
  Stream<List<BusLocation>> getOnlineBuses() {
    return FirebaseFirestore.instance
        .collection('conductors')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          print('🔍 Found ${snapshot.docs.length} online conductors');
          for (final doc in snapshot.docs) {
            print('  - ${doc.id}: ${doc.data()}');
          }
          
          final allBuses = snapshot.docs.map((doc) => BusLocation.fromFirestore(doc)).toList();
          print('📊 Total buses created: ${allBuses.length}');
          
          final buses = allBuses.where((bus) {
            final isValid = bus.location.latitude != 0 && bus.location.longitude != 0;
            print('🔍 Bus ${bus.conductorId}: lat=${bus.location.latitude}, lng=${bus.location.longitude} - Valid: $isValid');
            return isValid;
          }).toList();
          
          print('✅ Processed ${buses.length} buses with valid location');
          return buses;
        });
  }

  // Get stream of buses by specific route
  Stream<List<BusLocation>> getBusesByRoute(String route) {
    return FirebaseFirestore.instance
        .collection('conductors')
        .where('isOnline', isEqualTo: true)
        .where('route', isEqualTo: route)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BusLocation.fromFirestore(doc))
              .where((bus) => bus.location.latitude != 0 && bus.location.longitude != 0)
              .toList();
        });
  }

  // Get all available routes
  Future<List<String>> getAvailableRoutes() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('conductors')
        .where('isOnline', isEqualTo: true)
        .get();

    final routes = snapshot.docs
        .map((doc) => doc.data()['route'] as String?)
        .where((route) => route != null && route.isNotEmpty)
        .map((route) => route!)
        .toSet()
        .toList();

    return routes;
  }

  // Get bus details by conductor ID
  Future<BusLocation?> getBusByConductorId(String conductorId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .get();

      if (doc.exists) {
        return BusLocation.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting bus by conductor ID: $e');
      return null;
    }
  }

  // Get buses within a certain radius of a location
  Stream<List<BusLocation>> getBusesNearLocation(LatLng center, double radiusKm) {
    return FirebaseFirestore.instance
        .collection('conductors')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => BusLocation.fromFirestore(doc))
              .where((bus) {
                if (bus.location.latitude == 0 || bus.location.longitude == 0) {
                  return false;
                }
                
                // Calculate distance from center
                final distance = _calculateDistance(
                  center.latitude, center.longitude,
                  bus.location.latitude, bus.location.longitude,
                );
                
                return distance <= radiusKm;
              })
              .toList();
        });
  }

  // Calculate distance between two points in kilometers
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        sin(_degreesToRadians(lat1)) * sin(_degreesToRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * asin(sqrt(a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }
} 