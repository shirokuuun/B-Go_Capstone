import 'package:cloud_firestore/cloud_firestore.dart';

class RouteService {

  // get ROUTE
  static Future<String> fetchRoutePlaceName() async {
    final doc = await FirebaseFirestore.instance
        .collection('Destinations')
        .doc('Batangas')
        .collection('Place')
        .doc('Batangas City')
        .get();

    if (doc.exists) {
      final data = doc.data();
      final name = data?['Name'] ?? 'Batangas City Proper';

      // Custom display if Batangas City Proper is detected
      if (name == 'Batangas City Proper') {
        return 'SM City Lipa - Batangas City';
      }
      // Default for other names
      return 'Batangas - $name';
    } else {
      return 'Route not found';
    }
  }

  // get PLACES
  static Future<List<Map<String, dynamic>>> fetchPlaces() async {
    var snapshot = await FirebaseFirestore.instance
        .collection('Destinations')
        .doc('Batangas')
        .collection('Place')
        .get();

    List<Map<String, dynamic>> places = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'name': data['Name']?.toString() ?? doc.id,
        'km': data['km'], // keep as number if possible
      };
    }).toList();

    // Sort by 'km', treating null or missing as a high value (so they go last)
    places.sort((a, b) {
      num akm = a['km'] ?? double.infinity;
      num bkm = b['km'] ?? double.infinity;
      return akm.compareTo(bkm);
    });

    return places;
  }
}