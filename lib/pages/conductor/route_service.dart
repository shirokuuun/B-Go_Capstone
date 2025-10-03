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
      } else if (route.trim() == 'Mataas Na Kahoy Palengke' && name == 'Mataas na Kahoy Terminal') {
        return 'SM City Lipa - Mataas na Kahoy Terminal';
      }
      // Default for other names
      return '${route.trim()} - $name';
    } else {
      return 'Route not found';
    }
  }

  // Get PLACES from route - optimized with reduced logging
  static Future<List<Map<String, dynamic>>> fetchPlaces(
      String route, {String? placeCollection}) async {
    try {
      
      // Get the Firestore instance
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      // Reference to the Destinations collection
      CollectionReference destinationsRef = firestore.collection('Destinations');
      
      // Get the specific route document
      DocumentReference routeDocRef = destinationsRef.doc(route);
      
      // Get the places subcollection based on the placeCollection parameter
      String collectionName = placeCollection ?? 'Place';
      CollectionReference placesRef = routeDocRef.collection(collectionName);
      
      // Fetch all documents in the places subcollection
      QuerySnapshot querySnapshot = await placesRef.get();
      
      
      // Reduced debug logging for performance
      if (querySnapshot.docs.length > 10) {
        print('🔍 RouteService: Large dataset detected (${querySnapshot.docs.length} docs) - reducing debug output');
      } else {
        // Only log details for small datasets
        for (var doc in querySnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
        }
      }
      
      // Convert the documents to a list of maps, properly handling the data
      List<Map<String, dynamic>> places = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Extract and convert distance properly
        double distance = 0;
        if (data['km'] != null) {
          if (data['km'] is String) {
            distance = double.tryParse(data['km'].toString()) ?? 0;
          } else if (data['km'] is num) {
            distance = data['km'].toDouble();
          }
        }
        
            // Special handling for Mataas Na Kahoy Palengke route (both display name and Firestore name)
            if (route == 'Mataas Na Kahoy Palengke') {
              String placeName = data['Name']?.toString() ?? doc.id;
              
              if (collectionName == 'Place') {
                // Forward direction: Lipa Palengke to Mataas na Kahoy
                if (placeName == 'Lipa Palengke') {
                  distance = 0.0; // Starting point
                } else if (placeName == 'Mataas na Kahoy Terminal') {
                  distance = 8.0; // End point
                }
                // For other places, keep original distance calculation from database
              } else if (collectionName == 'Place 2') {
                // Reverse direction: Mataas na Kahoy to Lipa Palengke
                if (placeName == 'Mataas na Kahoy Terminal') {
                  distance = 0.0; // Starting point
                } else if (placeName == 'Lipa Palengke') {
                  distance = 8.0; // End point
                }
                // For intermediate stops, the distance should already be correct in the database
                // as they are stored relative to the route direction
              }
            }
        
        return {
          'name': data['Name']?.toString() ?? doc.id, // Use 'Name' field or doc.id as fallback
          'km': distance,
          'latitude': data['latitude'] ?? 0,
          'longitude': data['longitude'] ?? 0,
        };
      }).toList();

      // Sort places by distance (0km to highest)
      places.sort((a, b) {
        double distanceA = a['km'] ?? 0;
        double distanceB = b['km'] ?? 0;
        return distanceA.compareTo(distanceB);
      });
      return places;
    } catch (e) {
      print('❌ RouteService: Error fetching places for route "$route": $e');
      return [];
    }
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
      'status': 'boarded', // Add status for manually ticketed passengers
      'ticketType': 'manual', // Distinguish from QR-scanned tickets
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
               'status': 'boarded', // Add status for manually ticketed passengers
               'ticketType': 'manual', // Distinguish from QR-scanned tickets
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

// ✅ Update manually ticketed passenger status to accomplished
static Future<void> updateManualTicketStatus(
  String conductorId,
  String date,
  String ticketDocName,
  String newStatus,
) async {
  try {
    // Update in remittance collection
    final remittanceDoc = FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorId)
        .collection('remittance')
        .doc(date)
        .collection('tickets')
        .doc(ticketDocName);

    final remittanceData = await remittanceDoc.get();
    if (!remittanceData.exists) {
      throw Exception('Ticket not found in remittance collection');
    }

    final ticketData = remittanceData.data() as Map<String, dynamic>;
    final quantity = ticketData['quantity'] ?? 0;
    final currentStatus = ticketData['status'] ?? 'boarded';

    // Only allow status changes from "boarded" to "accomplished"
    if (currentStatus == 'boarded' && newStatus == 'accomplished') {
      await remittanceDoc.update({
        'status': newStatus,
        'accomplishedAt': FieldValue.serverTimestamp(),
      });

      // Also update in daily trip structure
      try {
        final dailyTripDoc = await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorId)
            .collection('dailyTrips')
            .doc(date)
            .get();

        if (dailyTripDoc.exists) {
          final dailyTripData = dailyTripDoc.data();
          final currentTrip = dailyTripData?['currentTrip'] ?? 1;
          final tripCollection = 'trip$currentTrip';

          final dailyTripTicketDoc = FirebaseFirestore.instance
              .collection('conductors')
              .doc(conductorId)
              .collection('dailyTrips')
              .doc(date)
              .collection(tripCollection)
              .doc('tickets')
              .collection('tickets')
              .doc(ticketDocName);

          await dailyTripTicketDoc.update({
            'status': newStatus,
            'accomplishedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        print('Failed to update daily trip structure: $e');
        // Continue with normal operation even if daily trip structure fails
      }

      // Decrement passenger count when status changes to accomplished
      if (quantity > 0) {
        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorId)
            .update({
              'passengerCount': FieldValue.increment(-quantity)
            });
        print('✅ Passenger count decremented by $quantity');
      }

      // Update remittance summary
      try {
        Map<String, dynamic> remittanceSummary = await RemittanceService.calculateDailyRemittance(conductorId, date);
        await RemittanceService.saveRemittanceSummary(conductorId, date, remittanceSummary);
        print('✅ Remittance summary updated for $date');
      } catch (e) {
        print('Error updating remittance summary: $e');
      }

      print('✅ Ticket status updated to $newStatus successfully');
    } else {
      throw Exception('Invalid status transition from $currentStatus to $newStatus');
    }
  } catch (e) {
    print('❌ Error updating ticket status: $e');
    throw e;
  }
}

// ✅ Get all manually ticketed passengers with their current status
static Future<List<Map<String, dynamic>>> getManualTickets(
  String conductorId,
  String date,
) async {
  try {
    final ticketsSnapshot = await FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorId)
        .collection('remittance')
        .doc(date)
        .collection('tickets')
        .where('ticketType', isEqualTo: 'manual')
        .get();

    return ticketsSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
  } catch (e) {
    print('❌ Error fetching manual tickets: $e');
    return [];
  }
}

// ✅ Get all QR-scanned tickets with their current status
static Future<List<Map<String, dynamic>>> getQRTickets(
  String conductorId,
  String date,
) async {
  try {
    final ticketsSnapshot = await FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorId)
        .collection('remittance')
        .doc(date)
        .collection('tickets')
        .where('ticketType', isEqualTo: 'qr')
        .get();

    return ticketsSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
      };
    }).toList();
  } catch (e) {
    print('❌ Error fetching QR tickets: $e');
    return [];
  }
}

// ✅ Update QR-scanned ticket status to accomplished
static Future<void> updateQRTicketStatus(
  String conductorId,
  String date,
  String ticketDocName,
  String newStatus,
) async {
  try {
    // Update in remittance collection
    final remittanceDoc = FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorId)
        .collection('remittance')
        .doc(date)
        .collection('tickets')
        .doc(ticketDocName);

    final remittanceData = await remittanceDoc.get();
    if (!remittanceData.exists) {
      throw Exception('Ticket not found in remittance collection');
    }

    final ticketData = remittanceData.data() as Map<String, dynamic>;
    final quantity = ticketData['quantity'] ?? 0;
    final currentStatus = ticketData['status'] ?? 'boarded';

    // Only allow status changes from "boarded" to "accomplished"
    if (currentStatus == 'boarded' && newStatus == 'accomplished') {
      await remittanceDoc.update({
        'status': newStatus,
        'accomplishedAt': FieldValue.serverTimestamp(),
      });

      // Also update in daily trip structure
      try {
        final dailyTripDoc = await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorId)
            .collection('dailyTrips')
            .doc(date)
            .get();

        if (dailyTripDoc.exists) {
          final dailyTripData = dailyTripDoc.data();
          final currentTrip = dailyTripData?['currentTrip'] ?? 1;
          final tripCollection = 'trip$currentTrip';

          final dailyTripTicketDoc = FirebaseFirestore.instance
              .collection('conductors')
              .doc(conductorId)
              .collection('dailyTrips')
              .doc(date)
              .collection(tripCollection)
              .doc('tickets')
              .collection('tickets')
              .doc(ticketDocName);

          await dailyTripTicketDoc.update({
            'status': newStatus,
            'accomplishedAt': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        print('Failed to update daily trip structure: $e');
        // Continue with normal operation even if daily trip structure fails
      }

      // Decrement passenger count when status changes to accomplished
      if (quantity > 0) {
        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorId)
            .update({
              'passengerCount': FieldValue.increment(-quantity)
            });
        print('✅ Passenger count decremented by $quantity');
      }

      // Update remittance summary
      try {
        Map<String, dynamic> remittanceSummary = await RemittanceService.calculateDailyRemittance(conductorId, date);
        await RemittanceService.saveRemittanceSummary(conductorId, date, remittanceSummary);
        print('✅ Remittance summary updated for $date');
      } catch (e) {
        print('Error updating remittance summary: $e');
      }

      print('✅ QR ticket status updated to $newStatus successfully');
    } else {
      throw Exception('Invalid status transition from $currentStatus to $newStatus');
    }
  } catch (e) {
    print('❌ Error updating QR ticket status: $e');
    throw e;
  }
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
        .collection('dailyTrips')  // Changed from 'trips' to 'dailyTrips'
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
  try {
    print('🔍 Fetching tickets for conductor: $conductorId, date: $date');
    
    // Only fetch from remittance collection since that's where status is updated
    List<Map<String, dynamic>> allTickets = [];
    
    try {
      final remittanceDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('remittance')
          .doc(date)
          .get();

      if (remittanceDoc.exists) {
        // Check tickets collection in remittance
        final remittanceTicketsSnapshot = await remittanceDoc.reference
            .collection('tickets')
            .get();

        if (remittanceTicketsSnapshot.docs.isNotEmpty) {
          print('🔍 Found tickets in remittance: ${remittanceTicketsSnapshot.docs.length}');
          
          for (var ticketDoc in remittanceTicketsSnapshot.docs) {
            final data = ticketDoc.data();
            print('🔍 Found remittance ticket: ${ticketDoc.id} with data: $data');
            
            allTickets.add({
              'id': ticketDoc.id,
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
              'status': data['status'] ?? 'paid',
              'ticketType': data['ticketType'] ?? 'manual',
              // Ensure Trips page can determine boarded
              'boardedAt': data['boardedAt'],
              'scannedBy': data['scannedBy'],
              'boardingStatus': data['boardingStatus'],
              'dropOffTimestamp': data['dropOffTimestamp'],
              'dropOffLocation': data['dropOffLocation'],
              'geofenceStatus': data['geofenceStatus'],
            });
          }
        }
      } else {
        print('⚠️ No remittance document found for date: $date');
      }
    } catch (e) {
      print('🔍 Remittance collection not found or error: $e');
    }

    print('✅ Total tickets found: ${allTickets.length}');
    return allTickets;
  } catch (e) {
    print('❌ Error fetching tickets: $e');
    return [];
  }
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
  try {
    // First, find the ticket in the dailyTrips structure
    final dailyTripsDoc = await FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorId)
        .collection('dailyTrips')
        .doc(date)
        .get();

    if (!dailyTripsDoc.exists) {
      throw Exception('Daily trips document not found for date: $date');
    }

    // Since listCollections() is not available, we'll use a different approach
    // We'll check for common trip collection names and find the ticket
    for (int i = 1; i <= 5; i++) { // Check up to 5 trips
      try {
        final tripCollection = dailyTripsDoc.reference.collection('trip$i');
        final ticketsDoc = tripCollection.doc('tickets');
        final ticketsCollection = ticketsDoc.collection('tickets');
        
        final ticketDoc = ticketsCollection.doc(ticketId);
        final ticketSnapshot = await ticketDoc.get();
        
        if (ticketSnapshot.exists) {
          final ticketData = ticketSnapshot.data()!;
          final quantity = ticketData['quantity'] ?? 0;

          // Delete the ticket
          await ticketDoc.delete();

          // Decrement the passenger count
          if (quantity > 0) {
            await FirebaseFirestore.instance
                .collection('conductors')
                .doc(conductorId)
                .update({
                  'passengerCount': FieldValue.increment(-quantity)
                });
          }
          
          print('✅ Ticket deleted successfully');
          return;
        }
      } catch (e) {
        // If trip collection doesn't exist, continue to next
        print('🔍 Trip $i not found or error: $e');
        continue;
      }
    }
    
    throw Exception('Ticket not found');
  } catch (e) {
    print('❌ Error deleting ticket: $e');
    throw e;
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