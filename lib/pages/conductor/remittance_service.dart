import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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

      int totalPassengers = 0;
      double totalFare = 0.0;
      List<Map<String, dynamic>> ticketDetails = [];

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
          'documentType': ticketData['documentType'] ?? 'ticket',
        });
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
        'ticketCount': remittanceSnapshot.docs.length,
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
