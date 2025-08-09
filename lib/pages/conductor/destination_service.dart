import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:b_go/config/api_keys.dart';

class DestinationService {
  static String get _geocodingApiKey => ApiKeys.googleGeocodingApiKey;
  
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

      // Sort by kilometer
      destinations.sort((a, b) {
        num akm = a['km'] ?? double.infinity;
        num bkm = b['km'] ?? double.infinity;
        return akm.compareTo(bkm);
      });

      return destinations;
    } catch (e) {
      print('Error fetching route destinations: $e');
      return [];
    }
  }

  // Geocode a location name to get coordinates
  static Future<Map<String, double>?> geocodeLocation(String locationName, String route) async {
    try {
      // First, try to get from Firestore
      final firestoreResult = await _getCoordinatesFromFirestore(locationName, route);
      if (firestoreResult != null) {
        return firestoreResult;
      }

      // If not found in Firestore, use Google Geocoding API
      final query = '$locationName, $route, Philippines';
      final url = 'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(query)}&key=$_geocodingApiKey';
      
      print('🗺️ Geocoding: $locationName in $route');
      print('🗺️ API URL: $url');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🗺️ Geocoding response: ${data['status']}');
        
        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final coordinates = <String, double>{
            'latitude': location['lat'].toDouble(),
            'longitude': location['lng'].toDouble(),
          };
          
          print('🗺️ Geocoding success: ${coordinates['latitude']}, ${coordinates['longitude']}');
          
          // Save to Firestore for future use
          await _saveCoordinatesToFirestore(locationName, route, coordinates);
          
          return coordinates;
        } else {
          print('🗺️ Geocoding failed: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
        }
      } else {
        print('🗺️ Geocoding HTTP error: ${response.statusCode}');
      }
      
      return null;
    } catch (e) {
      print('Error geocoding location: $e');
      return null;
    }
  }

  // Save coordinates to Firestore for future use
  static Future<void> _saveCoordinatesToFirestore(String locationName, String route, Map<String, double> coordinates) async {
    try {
      // Try to save to both forward and reverse collections
      final forwardDoc = FirebaseFirestore.instance
          .collection('Destinations')
          .doc(route.trim())
          .collection('Place')
          .doc(locationName);
      
      await forwardDoc.set({
        'Name': locationName,
        'latitude': coordinates['latitude'],
        'longitude': coordinates['longitude'],
        'geocoded': true,
        'geocodedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('🗺️ Saved coordinates to Firestore for $locationName in $route');
    } catch (e) {
      print('Error saving coordinates to Firestore: $e');
    }
  }

  // Get coordinates from Firestore if available
  static Future<Map<String, double>?> _getCoordinatesFromFirestore(String locationName, String route) async {
    try {
      // Check in both forward and reverse collections
      final forwardDoc = await FirebaseFirestore.instance
          .collection('Destinations')
          .doc(route.trim())
          .collection('Place')
          .where('Name', isEqualTo: locationName)
          .limit(1)
          .get();

             if (forwardDoc.docs.isNotEmpty) {
         final data = forwardDoc.docs.first.data();
         final lat = _convertToDouble(data['latitude']);
         final lng = _convertToDouble(data['longitude']);
         if (lat != null && lng != null) {
           return {
             'latitude': lat,
             'longitude': lng,
           };
         }
       }

       final reverseDoc = await FirebaseFirestore.instance
           .collection('Destinations')
           .doc(route.trim())
           .collection('Place 2')
           .where('Name', isEqualTo: locationName)
           .limit(1)
           .get();

       if (reverseDoc.docs.isNotEmpty) {
         final data = reverseDoc.docs.first.data();
         final lat = _convertToDouble(data['latitude']);
         final lng = _convertToDouble(data['longitude']);
         if (lat != null && lng != null) {
           return {
             'latitude': lat,
             'longitude': lng,
           };
         }
       }

      return null;
    } catch (e) {
      print('Error getting coordinates from Firestore: $e');
      return null;
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
            icon: BitmapDescriptor.defaultMarkerWithHue(
              destination['direction'] == 'forward' 
                ? BitmapDescriptor.hueViolet 
                : BitmapDescriptor.hueOrange
            ),
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
