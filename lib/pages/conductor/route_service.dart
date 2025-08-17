import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'remittance_service.dart';

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
        'latitude': data['latitude'] ?? 0.0,
        'longitude': data['longitude'] ?? 0.0,
      };
    }).toList();

    places.sort((a, b) {
      num akm = a['km'] ?? double.infinity;
      num bkm = b['km'] ?? double.infinity;
      return akm.compareTo(bkm);
    });

    return places;
  }

  // Calculate distance between two coordinates in kilometers
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(lat1 * math.pi / 180) * math.sin(lat2 * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

   // Get conductor document ID from email (e.g., for dynamic document access)
  static Future<String?> getConductorDocIdFromUid(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('conductors')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.id; 
    }
    return null; // Not found
  }

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

    // discount breakdown
    List<String> discountBreakdown = [];
    for (int i = 0; i < discountList.length; i++) {
      final discount = discountList[i];
      final type = fareTypes[i];
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

    final user = FirebaseAuth.instance.currentUser;
          final conductorId = await RouteService.getConductorDocIdFromUid(user?.uid ?? '');
    if (conductorId == null) {
      throw Exception('Conductor not found for email ${user?.email}');
    }

     try {
     await FirebaseFirestore.instance
     .collection('conductors')
     .doc(conductorId)
     .collection('remittance')
     .doc(formattedDate)
     .set({'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
   } catch (e) {
     print('Failed to ensure date document exists: $e');
   }

         final tripsCollection = FirebaseFirestore.instance
         .collection('conductors')
         .doc(conductorId)
         .collection('remittance')
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

         // Also save to daily trip structure (trip1 or trip2)
     try {
       final dailyTripDoc = await FirebaseFirestore.instance
           .collection('conductors')
           .doc(conductorId)
           .collection('dailyTrips')
           .doc(formattedDate)
           .get();
       
       if (dailyTripDoc.exists) {
         final dailyTripData = dailyTripDoc.data();
         final currentTrip = dailyTripData?['currentTrip'] ?? 1;
         final tripCollection = 'trip$currentTrip';
         
         await FirebaseFirestore.instance
             .collection('conductors')
             .doc(conductorId)
             .collection('dailyTrips')
             .doc(formattedDate)
             .collection(tripCollection)
             .doc('tickets')
             .collection('tickets')
             .doc(tripDocName)
             .set({
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
       }
     } catch (e) {
       print('Failed to save to daily trip structure: $e');
       // Continue with normal operation even if daily trip structure fails
     }

    // Increment passenger count
    await FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorId)
        .update({
          'passengerCount': FieldValue.increment(quantity)
        });

    // Calculate and save remittance summary
    Map<String, dynamic>? remittanceSummary;
    try {
      remittanceSummary = await RemittanceService.calculateDailyRemittance(conductorId, formattedDate);
      await RemittanceService.saveRemittanceSummary(conductorId, formattedDate, remittanceSummary);
      print('✅ Remittance summary updated for $formattedDate');
    } catch (e) {
      print('Error updating remittance summary: $e');
    }

    // Also update the remittance summary in the daily trip document
    if (remittanceSummary != null) {
      try {
        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorId)
            .collection('dailyTrips')
            .doc(formattedDate)
            .update({
              'ticketCount': remittanceSummary['ticketCount'],
              'totalPassengers': remittanceSummary['totalPassengers'],
              'totalFare': remittanceSummary['totalFare'],
              'totalFareFormatted': remittanceSummary['totalFareFormatted'],
              'lastRemittanceUpdate': FieldValue.serverTimestamp(),
            });
        print('✅ Daily trip remittance summary updated');
      } catch (e) {
        print('Error updating daily trip remittance summary: $e');
      }
    }

    return tripDocName;
  }

  // ✅ Update trip status (active/inactive)
static Future<void> updateTripStatus(
  String conductorId,
  String date,
  String ticketDocName,
  bool isActive,
) async {
  final tripDoc = FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorId)
      .collection('trips')
      .doc(date)
      .collection('tickets')
      .doc(ticketDocName);

  await tripDoc.update({'active': isActive});
}

//  Fetch trip details for a ticket
static Future<Map<String, dynamic>?> fetchTrip(
  String route,
  String date,
  String ticketDocName,
) async {
  final user = FirebaseAuth.instance.currentUser;
          final conductorId = await getConductorDocIdFromUid(user?.uid ?? '');
  if (conductorId == null) return null;

  final doc = await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorId)
      .collection('trips')
      .doc(date)
      .collection('tickets')
      .doc(ticketDocName)
      .get();

  if (!doc.exists) return null;
  return doc.data();
}

// Fetch available trip dates for a conductor
static Future<List<String>> fetchAvailableTripDates(String conductorId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorId)
      .collection('trips')
      .get();

  return snapshot.docs.map((doc) => doc.id).toList();
}

// Same as above, but with debug prints (optional)
static Future<List<String>> fetchAvailableDates(String conductorId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorId)
        .collection('trips')
        .get();

    print("Fetched ${snapshot.docs.length} date documents for $conductorId");

    List<String> dates = snapshot.docs.map((doc) {
      print("Found date doc: ${doc.id}");
      return doc.id;
    }).toList();

    dates.sort((a, b) => b.compareTo(a)); // newest first
    return dates;
  } catch (e) {
    print('Error fetching dates: $e');
    return [];
  }
}

// Fetch all tickets for a specific conductor and date
static Future<List<Map<String, dynamic>>> fetchTickets({
  required String conductorId,
  required String date,
}) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorId)
      .collection('trips')
      .doc(date)
      .collection('tickets')
      .get();

  return snapshot.docs.map((doc) {
    final data = doc.data();
    return {
      'id': doc.id,
      'from': data['from'],
      'to': data['to'],
      'totalFare': data['totalFare'],
      'quantity': data['quantity'],
      'discountAmount': data['discountAmount'],
      'discountBreakdown': data['discountBreakdown'],
      'farePerPassenger': data['farePerPassenger'],
      'startKm': data['startKm'],
      'endKm': data['endKm'],
      'timestamp': data['timestamp'],
    };
  }).toList();
}


// Fetch tickets for specific date (
Future<List<Map<String, dynamic>>> fetchTicketsForDate(
  String conductorId,
  String date,
) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorId)
      .collection('trips')
      .doc(date)
      .collection('tickets')
      .get();

  return snapshot.docs.map((doc) {
    final data = doc.data();
    return {
      'id': doc.id,
      'from': data['from'],
      'to': data['to'],
      'totalFare': data['totalFare'],
      'quantity': data['quantity'],
      'discountAmount': data['discountAmount'],
      'timestamp': data['timestamp'],
    };
  }).toList();
}

//  Delete a ticket
static Future<void> deleteTicket(
  String conductorId,
  String date,
  String ticketId,
) async {
  // First, get the ticket data to know how many passengers to decrement
  final ticketDoc = await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorId)
      .collection('trips')
      .doc(date)
      .collection('tickets')
      .doc(ticketId)
      .get();

  if (!ticketDoc.exists) {
    throw Exception('Ticket not found');
  }

  final ticketData = ticketDoc.data()!;
  final quantity = ticketData['quantity'] ?? 0;

  // Delete the ticket
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorId)
      .collection('trips')
      .doc(date)
      .collection('tickets')
      .doc(ticketId)
      .delete();

  // Decrement the passenger count
  if (quantity > 0) {
    await FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorId)
        .update({
          'passengerCount': FieldValue.increment(-quantity)
        });
  }
}

  // sos saving details
    Future<void> sendSOS({
    required String emergencyType,
    required String description,
    required double lat,  
    required double lng,
    required String route,
    required bool isActive, 
  }) async {
    final counterDocRef = FirebaseFirestore.instance.collection('counters').doc('sos');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterDocRef);

      int currentCount = 0;
      if (snapshot.exists) {
        currentCount = snapshot.data()!['count'] ?? 0;
      }

      final newCount = currentCount + 1;
      final paddedCount = newCount.toString().padLeft(3, '0'); // sos_001, sos_002, etc.
      final newDocId = 'sos_$paddedCount';
      final newDocRef = FirebaseFirestore.instance.collection('sosRequests').doc(newDocId);

      final status = isActive ? 'Pending' : 'Received';

      transaction.set(counterDocRef, {'count': newCount});

      // Save SOS request
      transaction.set(newDocRef, {
        'route': route,
        'emergencyType': emergencyType,
        'description': description.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': status,
        'isActive' : isActive,
        'location': {
          'lat': lat,
          'lng': lng,
        },
        'docPath': newDocRef.path,
      });
    });
  }

    //fetch lastest SOS
  Future<Map<String, dynamic>?> fetchLatestSOS(String routeLabel) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('sosRequests')
          .where('route', isEqualTo: routeLabel)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        data['id'] = doc.id;

        if (data['status'] == 'Pending') {
          return data;
        } else {
          return null; 
        }
      }

      return null;
    } catch (e) {
      print('Error fetching SOS: $e');
      return null;
    }
  }

 // Helper to update SOS status based on document path
  Future<void> _updateSOSStatus(String docPath, bool isActive) async {
    final docRef = FirebaseFirestore.instance.doc(docPath);
    final newStatus = isActive ? 'Pending' : 'Received';

    await docRef.update({
      'isActive': isActive,
      'status': newStatus,
    });

    print('✅ Updated SOS: $docPath → isActive=$isActive, status=$newStatus');
  }

// Find latest SOS by route and update its status
  Future<void> updateSOSStatusByRoute(String routeLabel, bool isActive) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('sosRequests')
          .where('route', isEqualTo: routeLabel)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        print("⚠️ No SOS document found for route: $routeLabel");
        return;
      }

      final docPath = query.docs.first.reference.path;
      await _updateSOSStatus(docPath, isActive);
    } catch (e) {
      print("❌ Error updating SOS: $e");
    }
  }

  Future<void> cancelSOS(String docId) async {
    final docRef = FirebaseFirestore.instance.collection('sosRequests').doc(docId);
    await docRef.update({
      'status': 'Cancelled',
      'isActive': false,
    });
  }

  }