import 'package:cloud_firestore/cloud_firestore.dart';

class RouteService {
  // Get ROUTE place name
  static Future<String> fetchRoutePlaceName(String route) async {
    final doc = await FirebaseFirestore.instance
        .collection('Destinations')
        .doc(route.trim()) 
        .collection('Place')
        .doc('${route.trim()} City')
        .get();

    if (doc.exists) {
      final data = doc.data();
      final name = data?['Name'] ?? '${route.trim()} City Proper';

      // Custom display if Batangas City Proper is detected
      if (name == '${route.trim()} City Proper') {
        return 'SM City Lipa - ${route.trim()} City';
      }
      // Default for other names
      return '${route.trim()} - $name';
    } else {
      return 'Route not found';
    }
  }

  // Get PLACES from route
  static Future<List<Map<String, dynamic>>> fetchPlaces(String route) async {
    var snapshot = await FirebaseFirestore.instance
        .collection('Destinations')
        .doc(route.trim())
        .collection('Place')
        .get();

    List<Map<String, dynamic>> places = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'name': data['Name']?.toString() ?? doc.id,
        'km': data['km'],
      };
    }).toList();

    places.sort((a, b) {
      num akm = a['km'] ?? double.infinity;
      num bkm = b['km'] ?? double.infinity;
      return akm.compareTo(bkm);
    });

    return places;
  }

  //To save trip details
   static Future<void> saveTrip({
    required String route,
    required String from,
    required String to,
    required num startKm,
    required num endKm,
    required int quantity,
    required double discount,
  }) async {
    final totalKm = endKm - startKm;

    //customize trip document name
    final tripsCollection = FirebaseFirestore.instance
      .collection('trips')
      .doc(route)
      .collection('trips');

      final snapshot = await tripsCollection.get();
      final tripNumber = snapshot.docs.length + 1;
      final tripDocName = "trip $tripNumber";

    await tripsCollection.doc(tripDocName).set({
      'from': from,
      'to': to,
      'startKm': startKm,
      'endKm': endKm,
      'totalKm': totalKm,
      'timestamp': FieldValue.serverTimestamp(),
      'active': true,
      'quantity': quantity,
      'discount': discount.toStringAsFixed(2),
    });
  }

}