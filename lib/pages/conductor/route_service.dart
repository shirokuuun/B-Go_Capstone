import 'package:cloud_firestore/cloud_firestore.dart';

class RouteService {
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
}