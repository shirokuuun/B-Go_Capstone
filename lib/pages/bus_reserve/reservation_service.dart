import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationService {
  // Add a new bus to the database
  static Future<void> addBus({
    required String busName,
    required String route,
    required String plateNumber,
    required List<String> codingDays,
  }) async {
    final busData = {
      'busId': plateNumber,
      'name': busName,
      'route': route,
      'plateNumber': plateNumber,
      'codingDays': codingDays,
      'status': 'active',
    };

    await FirebaseFirestore.instance
        .collection('buses')
        .doc(plateNumber)
        .set(busData);
  }

  // Fetch available buses excluding those with coding today
   static Future<List<Map<String, dynamic>>> getAvailableBuses() async {
    final now = DateTime.now();
    final todayName = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][now.weekday - 1];

    final snapshot = await FirebaseFirestore.instance
        .collection('buses')
        .get();

    return snapshot.docs
        .where((doc) {
          final data = doc.data();
          final codingDays = List<String>.from(data['codingDays'] ?? []);
          return !codingDays.contains(todayName);
        })
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }
}