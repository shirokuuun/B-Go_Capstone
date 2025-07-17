import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RouteService {


  static Future<String> fetchRoutePlaceName(String route) async {

    final doc = await FirebaseFirestore.instance
        .collection('Destinations')
        .doc(route.trim()) 
        .collection('Place')
        .doc('${route.trim()} City Proper') 
        .get();

    if (doc.exists) {
      final data = doc.data();
      final name = data?['Name'] ?? '${route.trim()} City Proper';

      // Custom display if Batangas City Proper is detected
      if (name == '${route.trim()} City Proper') {
        return 'SM City Lipa - ${route.trim()} City';
      } else if (name == '${route.trim()} Proper') {
        return 'SM City Lipa - ${route.trim()}';
      } else if (name ==  'Mataas na Kahoy Terminal') {
        return 'SM City Lipa - Mataas na Kahoy Terminal';
      }
      // Default for other names
      return '${route.trim()} - $name';
    } else {
      return 'Route not found';
    }
  }

  // Get PLACES from route
  static Future<List<Map<String, dynamic>>> fetchPlaces(String route, {String placeCollection = 'Place'}) async {
    var snapshot = await FirebaseFirestore.instance
        .collection('Destinations')
        .doc(route.trim())
        .collection(placeCollection)
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
  static Future<String> saveTrip({
  required String route,
  required String from,
  required String to,
  required num startKm,
  required num endKm,
  required int quantity,
  required List<double> discountList,
  required List<String> fareTypes, 
  String? date,
}) async {
  final totalKm = endKm - startKm;

  // base fare calculation, isa isa
  double baseFare = 15.0;
  if (totalKm > 4) {
    baseFare += (totalKm - 4) * 2.20;
  }

  // Calculate discounted fare per passenger
  List<double> discountedFares = discountList.map((discount) {
    return baseFare * (1 - discount);
  }).toList();

  // Total fare
  double totalFare = discountedFares.fold(0.0, (sum, fare) => sum + fare);

  // Total discount amount
  double totalDiscountAmount = discountList.fold(0.0, (sum, discount) {
    return sum + (baseFare * discount);
  });

  // Convert for Firestore storage
  List<String> formattedFares = discountedFares.map((f) => f.toStringAsFixed(2)).toList();
  String totalDiscountStr = totalDiscountAmount.toStringAsFixed(2);
  String totalFareStr = totalFare.toStringAsFixed(2);

  //discount breakdown
  List<String> discountBreakdown = [];

  for (int i = 0; i < discountList.length; i++) {
    final discount = discountList[i];
    final type = fareTypes[i]; // e.g. 'regular', 'student', etc.

    if (discount > 0) {
      final discountAmount = baseFare * discount;
      discountBreakdown.add(
        'Passenger ${i + 1}: $type (₱${discountAmount.toStringAsFixed(2)} discount)',
      );
    } else {
      discountBreakdown.add(
        'Passenger ${i + 1}: Regular (No discount)',
      );
    }
  }

  final now = DateTime.now();
  String formattedDate = date ?? DateFormat('yyyy-MM-dd').format(now);

  final tripsCollection = FirebaseFirestore.instance
      .collection('trips')
      .doc(route)
      .collection('trips')
      .doc(formattedDate)
      .collection('tickets');

  final snapshot = await tripsCollection.get();
  int maxTripNumber = 0;
  for (var doc in snapshot.docs) {
    final tripName = doc.id; 
    final parts = tripName.split(' ');
    if (parts.length == 2 && int.tryParse(parts[1]) != null) {
      final num = int.parse(parts[1]);
      if (num > maxTripNumber) maxTripNumber = num;
    }
  }
  final tripNumber = maxTripNumber + 1;
  final tripDocName = "ticket $tripNumber";

  await tripsCollection.doc(tripDocName).set({
  'from': from,
  'to': to,
  'startKm': startKm,
  'endKm': endKm,
  'totalKm': totalKm,
  'timestamp': FieldValue.serverTimestamp(),
  'active': true,
  'quantity': quantity,
  'farePerPassenger': formattedFares,
  'totalFare': totalFareStr,
  'discountAmount': totalDiscountStr,
  'discountList': discountList,
  'discountBreakdown': discountBreakdown, 
});

  return tripDocName; 
}

  // To update trip status
  static Future<void> updateTripStatus(String route, String date, String ticketDocName, bool isActive) async {
    final tripDoc = FirebaseFirestore.instance
      .collection('trips')
      .doc(route)
      .collection('trips')
      .doc(date)
      .collection('tickets')
      .doc(ticketDocName);


    await tripDoc.update({'active': isActive});
  }

  // To fetch trip details for the ticket
  static Future<Map<String, dynamic>?> fetchTrip(String route, String date, String ticketDocName) async {
    final doc = await FirebaseFirestore.instance
      .collection('trips')
      .doc(route)
      .collection('trips')
      .doc(date)
      .collection('tickets')
      .doc(ticketDocName)
      .get();

    if (doc.exists) {
      final data = doc.data();
      return {
        'from': data?['from'],
        'to': data?['to'],
        'startKm': data?['startKm'],
        'endKm': data?['endKm'],
        'totalKm': data?['totalKm'],
        'timestamp': data?['timestamp'],
        'discountAmount': data?['discountAmount'],
        'quantity': data?['quantity'],
        'farePerPassenger': data?['farePerPassenger'],
        'totalFare': data?['totalFare'],
        'discountBreakdown': List<String>.from(data?['discountBreakdown'] ?? []),
      };
    }
    return null;
  }

  // compute total fare


}