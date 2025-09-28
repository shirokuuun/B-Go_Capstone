import 'package:cloud_firestore/cloud_firestore.dart';

class RemittanceService {
  static Future<Map<String, dynamic>> calculateDailyRemittance(String conductorId, String date) async {
    try {
      // Get all tickets from remittance collection for the day
      final remittanceSnapshot = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('remittance')
          .doc(date)
          .collection('tickets')
          .get();

      // Get all pre-bookings from remittance tickets collection for the day
      final preBookingsSnapshot = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('remittance')
          .doc(date)
          .collection('tickets')
          .where('documentType', isEqualTo: 'preBooking')
          .get();

      int totalPassengers = 0;
      double totalFare = 0.0;
      List<Map<String, dynamic>> ticketDetails = [];

      // Process tickets from remittance collection
      for (var ticket in remittanceSnapshot.docs) {
        final ticketData = ticket.data();
        
        // Extract passenger count
        final quantity = ticketData['quantity'] ?? 1;
        totalPassengers += (quantity is int) ? quantity : (quantity as num).toInt();
        
        // Extract total fare
        final fare = ticketData['totalFare'];
        if (fare != null) {
          if (fare is String) {
            totalFare += double.tryParse(fare) ?? 0.0;
          } else if (fare is num) {
            totalFare += fare.toDouble();
          }
        }
        
        // Store ticket details for breakdown
        ticketDetails.add({
          'ticketId': ticket.id,
          'from': ticketData['from'] ?? '',
          'to': ticketData['to'] ?? '',
          'quantity': quantity,
          'totalFare': fare,
          'timestamp': ticketData['timestamp'],
          'documentType': ticketData['documentType'] ?? 'preTicket',
          'source': 'remittance',
        });
      }

      // Process pre-bookings from remittance tickets collection
      for (var preBooking in preBookingsSnapshot.docs) {
        final preBookingData = preBooking.data();
        
        // Extract passenger count
        final quantity = preBookingData['quantity'] ?? 1;
        totalPassengers += (quantity is int) ? quantity : (quantity as num).toInt();
        
        // Extract total fare
        final fare = preBookingData['totalFare'];
        if (fare != null) {
          if (fare is String) {
            totalFare += double.tryParse(fare) ?? 0.0;
          } else if (fare is num) {
            totalFare += fare.toDouble();
          }
        }
        
        // Store pre-booking details for breakdown
        ticketDetails.add({
          'ticketId': preBooking.id,
          'from': preBookingData['from'] ?? '',
          'to': preBookingData['to'] ?? '',
          'quantity': quantity,
          'totalFare': fare,
          'timestamp': preBookingData['timestamp'],
          'documentType': 'preBooking',
          'source': 'remittance',
        });
      }

      // Also get tickets from daily trip structure to ensure completeness
      try {
        final dailyTripDoc = await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorId)
            .collection('dailyTrips')
            .doc(date)
            .get();

        if (dailyTripDoc.exists) {
          final dailyTripData = dailyTripDoc.data();
          
          // Check all trip collections (trip1, trip2, trip3, etc.)
          int tripNumber = 1;
          while (dailyTripData?['trip$tripNumber'] != null) {
            try {
              final tripTicketsSnapshot = await FirebaseFirestore.instance
                  .collection('conductors')
                  .doc(conductorId)
                  .collection('dailyTrips')
                  .doc(date)
                  .collection('trip$tripNumber')
                  .doc('tickets')
                  .collection('tickets')
                  .get();

              for (var ticket in tripTicketsSnapshot.docs) {
                final ticketData = ticket.data();
                
                // Check if this ticket is already counted in remittance
                bool alreadyCounted = ticketDetails.any((detail) => 
                    detail['ticketId'] == ticket.id && detail['source'] == 'remittance');
                
                if (!alreadyCounted) {
                  // Extract passenger count
                  final quantity = ticketData['quantity'] ?? 1;
                  totalPassengers += (quantity is int) ? quantity : (quantity as num).toInt();
                  
                  // Extract total fare
                  final fare = ticketData['totalFare'];
                  if (fare != null) {
                    if (fare is String) {
                      totalFare += double.tryParse(fare) ?? 0.0;
                    } else if (fare is num) {
                      totalFare += fare.toDouble();
                    }
                  }
                  
                  // Store ticket details for breakdown
                  ticketDetails.add({
                    'ticketId': ticket.id,
                    'from': ticketData['from'] ?? '',
                    'to': ticketData['to'] ?? '',
                    'quantity': quantity,
                    'totalFare': fare,
                    'timestamp': ticketData['timestamp'],
                    'documentType': ticketData['documentType'] ?? 'ticket',
                    'source': 'trip$tripNumber',
                  });
                }
              }
            } catch (e) {
              print('Error processing tickets from trip$tripNumber: $e');
            }
            
            tripNumber++;
          }
        }
      } catch (e) {
        print('Error processing daily trip structure: $e');
      }

      // Get daily trip information
      final dailyTripDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('dailyTrips')
          .doc(date)
          .get();

      Map<String, dynamic> dailyTripInfo = {};
      if (dailyTripDoc.exists) {
        dailyTripInfo = dailyTripDoc.data() ?? {};
      }

      return {
        'date': date,
        'totalPassengers': totalPassengers,
        'totalFare': totalFare,
        'totalFareFormatted': '₱${totalFare.toStringAsFixed(2)}',
        'ticketCount': remittanceSnapshot.docs.length + preBookingsSnapshot.docs.length,
        'ticketDetails': ticketDetails,
        'dailyTripInfo': dailyTripInfo,
        'calculatedAt': FieldValue.serverTimestamp(),
      };
    } catch (e) {
      print('Error calculating daily remittance: $e');
      return {
        'date': date,
        'totalPassengers': 0,
        'totalFare': 0.0,
        'totalFareFormatted': '₱0.00',
        'ticketCount': 0,
        'ticketDetails': [],
        'dailyTripInfo': {},
        'error': e.toString(),
      };
    }
  }

  static Future<void> saveRemittanceSummary(String conductorId, String date, Map<String, dynamic> summary) async {
    try {
      await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('remittance')
          .doc(date)
          .set({
            'summary': summary,
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving remittance summary: $e');
    }
  }

  static Future<Map<String, dynamic>?> getRemittanceSummary(String conductorId, String date) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('remittance')
          .doc(date)
          .get();

      if (doc.exists) {
        final data = doc.data();
        return data?['summary'];
      }
      return null;
    } catch (e) {
      print('Error getting remittance summary: $e');
      return null;
    }
  }

  static Future<List<String>> getAvailableRemittanceDates(String conductorId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('remittance')
          .get();

      List<String> dates = snapshot.docs.map((doc) => doc.id).toList();
      dates.sort((a, b) => b.compareTo(a)); // Sort newest first
      return dates;
    } catch (e) {
      print('Error getting available remittance dates: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getTripBreakdown(String conductorId, String date) async {
    try {
      final dailyTripDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('dailyTrips')
          .doc(date)
          .get();

      if (!dailyTripDoc.exists) {
        return {
          'trip1': null,
          'trip2': null,
          'totalTrips': 0,
        };
      }

      final data = dailyTripDoc.data()!;
      final trip1 = data['trip1'];
      final trip2 = data['trip2'];
      int totalTrips = 0;

      if (trip1 != null) totalTrips++;
      if (trip2 != null) totalTrips++;

      return {
        'trip1': trip1,
        'trip2': trip2,
        'totalTrips': totalTrips,
        'isRoundTripComplete': data['isRoundTripComplete'] ?? false,
        'startTime': data['createdAt'],
        'endTime': data['endTime'],
      };
    } catch (e) {
      print('Error getting trip breakdown: $e');
      return {
        'trip1': null,
        'trip2': null,
        'totalTrips': 0,
        'error': e.toString(),
      };
    }
  }
}
