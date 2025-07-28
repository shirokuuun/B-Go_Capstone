import 'package:cloud_firestore/cloud_firestore.dart';

class ReservationService {
  // Add a new bus to the database
  static Future<void> addBus({
    required String busName,
    required String plateNumber,
    required List<String> codingDays,
  }) async {
    final busData = {
      'busId': plateNumber,
      'name': busName,
      'plateNumber': plateNumber,
      'codingDays': codingDays,
      'status': 'active',
      'Price': 2000, // Default price
    };

    await FirebaseFirestore.instance
        .collection('AvailableBuses')
        .doc(busName)
        .set(busData);
  }

  // Fetch buses with coding days that match this week (e.g., Monday, Tuesday, etc.)
  static Future<List<Map<String, dynamic>>> getAvailableBuses() async {
  final snapshot = await FirebaseFirestore.instance
    .collection('AvailableBuses')
    .where('status', isEqualTo: 'active') // Only active buses
    .get();


  print('📦 Fetched ${snapshot.docs.length} bus docs from Firestore');

  const allWeekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  final today = DateTime.now();
  final todayIndex = today.weekday - 1; 
  final remainingDays = allWeekdays.sublist(todayIndex); 

  print('📅 Remaining days this week: $remainingDays');

  final availableBuses = snapshot.docs.where((doc) {
  final data = doc.data();
  final codingDays = List<String>.from(data['codingDays'] ?? []);
  return codingDays.any((day) => remainingDays.contains(day));
}).map((doc) {
  final data = doc.data() as Map<String, dynamic>;
  data['id'] = doc.id; // <- Save Firestore doc ID (busName)
  return data;
}).toList();


  print('✅ Available (Coded) Buses for the rest of this week: ${availableBuses.length}');
  return availableBuses;
}

 static Future<void> saveReservation({
  required List<String> selectedBusIds,
  required String from,
  required String to,
  required bool isRoundTrip,
  required String fullName,
  required String email,
}) async {
  final firestore = FirebaseFirestore.instance;
  final reservationsRef = firestore.collection('reservations');

  // Get current number of reservations
  final snapshot = await reservationsRef.get();
  final newReservationId = 'reservation ${snapshot.docs.length + 1}';

  // Save reservation with custom ID
  await reservationsRef.doc(newReservationId).set({
    'selectedBusIds': selectedBusIds,
    'from': from,
    'to': to,
    'isRoundTrip': isRoundTrip,
    'fullName': fullName,
    'email': email,
    'timestamp': FieldValue.serverTimestamp(),
  });

  // Mark selected buses as reserved
  for (String busDocId in selectedBusIds) {
  final busRef = firestore.collection('AvailableBuses').doc(busDocId);
  await busRef.update({'status': 'reserved'});
}

}

}