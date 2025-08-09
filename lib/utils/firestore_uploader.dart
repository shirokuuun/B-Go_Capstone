import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/conductor/route_coordinates.dart';

class FirestoreUploader {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload Rosario route coordinates to Firestore
  static Future<void> uploadRosarioCoordinates() async {
    try {
      print('🚀 Starting Rosario coordinates upload...');
      
      final rosarioCoordinates = RouteCoordinates.rosarioPlaces;
      final reverseCoordinates = RouteCoordinates.getReverseCoordinatesForRoute('Rosario');
      
      // Upload forward route (Place collection)
      await uploadRouteCoordinates('Rosario', 'Place', rosarioCoordinates);
      
      // Upload reverse route (Place 2 collection)
      await uploadRouteCoordinates('Rosario', 'Place 2', reverseCoordinates);
      
      print('✅ Successfully uploaded Rosario coordinates to Firestore!');
      print('📊 Forward route: ${rosarioCoordinates.length} locations');
      print('📊 Reverse route: ${reverseCoordinates.length} locations');
      
    } catch (e) {
      print('❌ Error uploading Rosario coordinates: $e');
    }
  }

  /// Upload coordinates for any route
  static Future<void> uploadRouteCoordinates(String routeName, String collectionName, Map<String, Map<String, dynamic>> coordinates) async {
    try {
      final batch = _firestore.batch();
      
      for (final entry in coordinates.entries) {
        final locationName = entry.key;
        final locationData = entry.value;
        
        final docRef = _firestore
            .collection('Destinations')
            .doc(routeName)
            .collection(collectionName)
            .doc(locationName);
        
        batch.set(docRef, locationData);
      }
      
      await batch.commit();
      print('✅ Uploaded ${coordinates.length} locations to $routeName/$collectionName');
      
    } catch (e) {
      print('❌ Error uploading to $routeName/$collectionName: $e');
      rethrow;
    }
  }

  /// Upload all route coordinates
  static Future<void> uploadAllRouteCoordinates() async {
    try {
      print('🚀 Starting upload of all route coordinates...');
      
      // Upload Rosario route
      await uploadRosarioCoordinates();
      
      // Upload other routes
      final routes = ['Batangas', 'Mataas na Kahoy', 'Tiaong', 'San Juan'];
      
      for (final route in routes) {
        final coordinates = RouteCoordinates.getCoordinatesForRoute(route);
        final reverseCoordinates = RouteCoordinates.getReverseCoordinatesForRoute(route);
        
        if (coordinates.isNotEmpty) {
          await uploadRouteCoordinates(route, 'Place', coordinates);
          await uploadRouteCoordinates(route, 'Place 2', reverseCoordinates);
        }
      }
      
      print('✅ Successfully uploaded all route coordinates!');
      
    } catch (e) {
      print('❌ Error uploading all route coordinates: $e');
    }
  }

  /// Verify coordinates in Firestore
  static Future<void> verifyRosarioCoordinates() async {
    try {
      print('🔍 Verifying Rosario coordinates in Firestore...');
      
      final forwardSnapshot = await _firestore
          .collection('Destinations')
          .doc('Rosario')
          .collection('Place')
          .get();
      
      final reverseSnapshot = await _firestore
          .collection('Destinations')
          .doc('Rosario')
          .collection('Place 2')
          .get();
      
      print('📊 Forward route locations: ${forwardSnapshot.docs.length}');
      print('📊 Reverse route locations: ${reverseSnapshot.docs.length}');
      
      for (final doc in forwardSnapshot.docs) {
        final data = doc.data();
        print('📍 ${data['Name']}: ${data['latitude']}, ${data['longitude']} (${data['km']} km)');
      }
      
    } catch (e) {
      print('❌ Error verifying coordinates: $e');
    }
  }
}
