import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DestinationService {
  
  // Helper method to convert any numeric value to double
  static double? _convertToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed;
    }
    return null;
  }
  
  // Fetch all destinations for a route with coordinates
  static Future<List<Map<String, dynamic>>> fetchRouteDestinations(String route) async {
    try {
      // Get both forward and reverse routes
      final forwardSnapshot = await FirebaseFirestore.instance
          .collection('Destinations')
          .doc(route.trim())
          .collection('Place')
          .get();

      final reverseSnapshot = await FirebaseFirestore.instance
          .collection('Destinations')
          .doc(route.trim())
          .collection('Place 2')
          .get();

      List<Map<String, dynamic>> destinations = [];

             // Process forward route
       for (var doc in forwardSnapshot.docs) {
         final data = doc.data();
         destinations.add({
           'name': data['Name']?.toString() ?? doc.id,
           'km': data['km'] ?? 0.0,
           'latitude': _convertToDouble(data['latitude']) ?? 0.0,
           'longitude': _convertToDouble(data['longitude']) ?? 0.0,
           'direction': 'forward',
         });
       }

       // Process reverse route
       for (var doc in reverseSnapshot.docs) {
         final data = doc.data();
         destinations.add({
           'name': data['Name']?.toString() ?? doc.id,
           'km': data['km'] ?? 0.0,
           'latitude': _convertToDouble(data['latitude']) ?? 0.0,
           'longitude': _convertToDouble(data['longitude']) ?? 0.0,
           'direction': 'reverse',
         });
       }

      // Don't sort by kilometer - maintain the order as they appear in Firestore
      // This preserves the actual road route sequence

      return destinations;
    } catch (e) {
      print('Error fetching route destinations: $e');
      return [];
    }
  }



  // Create destination markers for the map
  static Set<Marker> createDestinationMarkers(List<Map<String, dynamic>> destinations) {
    final Set<Marker> markers = {};
    
    for (int i = 0; i < destinations.length; i++) {
      final destination = destinations[i];
      final latitude = _convertToDouble(destination['latitude']) ?? 0.0;
      final longitude = _convertToDouble(destination['longitude']) ?? 0.0;
      
      if (latitude != 0.0 && longitude != 0.0) {
        final markerId = 'destination_${destination['name']}_${destination['direction']}';
        
        markers.add(
          Marker(
            markerId: MarkerId(markerId),
            position: LatLng(latitude, longitude),
            infoWindow: InfoWindow(
              title: destination['name'],
              snippet: '${destination['km']} km - ${destination['direction']} route',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
        );
      }
    }
    
    return markers;
  }

  // Get route range (first km to last km)
  static Map<String, dynamic> getRouteRange(List<Map<String, dynamic>> destinations) {
    if (destinations.isEmpty) {
      return {'firstKm': 0.0, 'lastKm': 0.0};
    }

    double firstKm = double.infinity;
    double lastKm = 0.0;

    for (final destination in destinations) {
      final km = _convertToDouble(destination['km']) ?? 0.0;
      if (km < firstKm) firstKm = km;
      if (km > lastKm) lastKm = km;
    }

    return {
      'firstKm': firstKm == double.infinity ? 0.0 : firstKm,
      'lastKm': lastKm,
    };
  }


}
