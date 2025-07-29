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
      .where('status', isEqualTo: 'active')
      .get();

  const allWeekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'
  ];

  final today = DateTime.now();
  final todayIndex = today.weekday - 1;
  final remainingDays = allWeekdays.sublist(todayIndex);

  final availableBuses = snapshot.docs.where((doc) {
    final data = doc.data();
    final List<String> codingDays = List<String>.from(data['codingDays'] ?? []);
    final List<String> reservedDays = List<String>.from(data['reservedDays'] ?? []);

    final unreservedDays = codingDays.where((day) => !reservedDays.contains(day)).toList();

    return unreservedDays.any((day) => remainingDays.contains(day));
  }).map((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final List<String> codingDays = List<String>.from(data['codingDays'] ?? []);
    final List<String> reservedDays = List<String>.from(data['reservedDays'] ?? []);

    final unreservedDays = codingDays.where((day) => !reservedDays.contains(day)).toList();
    data['codingDays'] = unreservedDays;

    data['id'] = doc.id;
    return data;
  }).toList();

  return availableBuses;
}


// Save a reservation with the selected buses and reservation details
static Future<void> saveReservation({
  required List<String> selectedBusIds,
  required String from,
  required String to,
  required bool isRoundTrip,
  required String fullName,
  required String email,
  required String reservationDay,
}) async {
  final firestore = FirebaseFirestore.instance;
  final reservationsRef = firestore.collection('reservations');
  final counterRef = firestore.collection('counters').doc('reservations');

  // Get current reservation count from the counter document
  final counterSnap = await counterRef.get();
  int newCount = 1;
  if (counterSnap.exists) {
    newCount = (counterSnap.data()?['count'] ?? 0) + 1;
  }

  // Create a unique reservation ID like 'reservation 12'
  final newReservationId = 'reservation $newCount';

  // Save the reservation
  await reservationsRef.doc(newReservationId).set({
    'reservationId': newReservationId,
    'selectedBusIds': selectedBusIds,
    'from': from,
    'to': to,
    'isRoundTrip': isRoundTrip,
    'fullName': fullName,
    'email': email,
    'reservationDay': reservationDay,
    'timestamp': FieldValue.serverTimestamp(),
  });

  // Update the reservation counter
  await counterRef.set({'count': newCount});

  // Update reservedDays for each bus
  for (String busDocId in selectedBusIds) {
    final busRef = firestore.collection('AvailableBuses').doc(busDocId);
    final busDoc = await busRef.get();

    if (busDoc.exists) {
      final data = busDoc.data()!;
      List<String> codingDays = List<String>.from(data['codingDays'] ?? []);
      List<String> reservedDays = List<String>.from(data['reservedDays'] ?? []);

      // Add the new reserved day if it's not already in the list
      if (!reservedDays.contains(reservationDay)) {
        reservedDays.add(reservationDay);
      }

      // Check if all coding days are now reserved
      final isFullyReserved = codingDays.toSet().difference(reservedDays.toSet()).isEmpty;

      // Update the reservedDays and status fields in the bus document
      await busRef.update({
        'reservedDays': reservedDays,
        'status': isFullyReserved ? 'reserved' : 'active',
      });
    }
  }
}

  // Get available reservation days for selected buses
static Future<List<String>> getAvailableReservationDays(List<String> selectedBusIds) async {
  final firestore = FirebaseFirestore.instance;
  final Set<String> availableDays = {};

  for (String busId in selectedBusIds) {
    final doc = await firestore.collection('AvailableBuses').doc(busId).get();
    if (doc.exists) {
      final data = doc.data();
      final List<String> codingDays = List<String>.from(data?['codingDays'] ?? []);
      final List<String> reservedDays = List<String>.from(data?['reservedDays'] ?? []);

      // Only include days that are in codingDays but NOT in reservedDays
      final filteredDays = codingDays.where((day) => !reservedDays.contains(day));
      availableDays.addAll(filteredDays);
    }
  }

  return _sortDays(availableDays.toList());
}

  static List<String> _sortDays(List<String> days) {
    const order = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    days.sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    return days;
  }


// delete and manually update the bus status to active (dito muna habang wala pang admin)
// Get all reservations
static Future<List<Map<String, dynamic>>> getAllReservations() async {
  final snapshot = await FirebaseFirestore.instance.collection('reservations').get();
  return snapshot.docs.map((doc) {
    final data = doc.data();
    data['id'] = doc.id;
    return data;
  }).toList();
}

// Cancel a reservation
static Future<void> cancelReservation(
  String reservationId,
  List<String> busIds,
  String reservationDay,
) async {
  final firestore = FirebaseFirestore.instance;

  // Delete the reservation document
  await firestore.collection('reservations').doc(reservationId).delete();

  for (String busId in busIds) {
    final busRef = firestore.collection('AvailableBuses').doc(busId);
    final doc = await busRef.get();

    if (doc.exists) {
      final data = doc.data()!;

      // Safely extract and convert lists
      List<String> reservedDays = List<String>.from(data['reservedDays'] ?? []);
      List<String> codingDays = List<String>.from(data['codingDays'] ?? []);

      // Remove the reservation day
      reservedDays.remove(reservationDay);

      // Check if the bus is now available again
      final isFullyReserved = codingDays.toSet().difference(reservedDays.toSet()).isEmpty;

      // Update bus status and reservedDays
      await busRef.update({
        'reservedDays': reservedDays,
        'status': isFullyReserved ? 'reserved' : 'active',
      });
    }
  }
}


}