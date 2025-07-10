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


  final tripsCollection = FirebaseFirestore.instance
      .collection('trips')
      .doc(route)
      .collection('trips');

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
  'farePerPassenger': formattedFares,
  'totalFare': totalFareStr,
  'discountAmount': totalDiscountStr,
  'discountList': discountList,
});

  return tripDocName; 
}

  // To update trip status
  static Future<void> updateTripStatus(String route, String tripDocName, bool isActive) async {
    final tripDoc = FirebaseFirestore.instance
        .collection('trips')
        .doc(route)
        .collection('trips')
        .doc(tripDocName);

    await tripDoc.update({'active': isActive});
  }

  // To fetch trip details for the ticket
  static Future<Map<String, dynamic>?> fetchTrip(String route, String tripDocName) async {
    final doc = await FirebaseFirestore.instance
        .collection('trips')
        .doc(route)
        .collection('trips')
        .doc(tripDocName)
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
      };
    }
    return null;
  }

  // compute total fare


}