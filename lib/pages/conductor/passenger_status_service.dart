import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PassengerStatusService {
  static const String _logPrefix = '🎫 PassengerStatusService:';

  /// Listen for ticket status changes and automatically update conductor passenger count
  /// This handles both manual ticket accomplishments and geofenced drop-offs
  static Stream<DocumentSnapshot> listenToTicketStatusChanges(String conductorId) {
    return FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorId)
        .snapshots();
  }

  /// Handle accomplished ticket by decrementing passenger count
  static Future<void> handleTicketAccomplished({
    required String ticketId,
    required int quantity,
    required String from,
    required String to,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      print('$_logPrefix Handling ticket accomplished: $ticketId (quantity: $quantity)');

      // Get conductor document
      final conductorQuery = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (conductorQuery.docs.isEmpty) {
        throw Exception('Conductor not found');
      }

      final conductorDoc = conductorQuery.docs.first;
      final conductorData = conductorDoc.data();
      final currentPassengerCount = conductorData['passengerCount'] ?? 0;

      // Calculate new passenger count
      final newPassengerCount = (currentPassengerCount - quantity).clamp(0, 999);

      print('$_logPrefix Current count: $currentPassengerCount, Decrementing by: $quantity, New count: $newPassengerCount');

      // Update conductor passenger count
      await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorDoc.id)
          .update({
        'passengerCount': newPassengerCount,
        'lastPassengerCountUpdate': FieldValue.serverTimestamp(),
        'lastAccomplishedTicket': {
          'ticketId': ticketId,
          'quantity': quantity,
          'from': from,
          'to': to,
          'accomplishedAt': FieldValue.serverTimestamp(),
        },
      });

      print('$_logPrefix Successfully decremented passenger count from $currentPassengerCount to $newPassengerCount');

    } catch (e) {
      print('$_logPrefix Error handling ticket accomplished: $e');
      throw e;
    }
  }

  /// Mark a pre-booking as accomplished (for geofencing)
  static Future<void> markPreBookingAccomplished({
    required String preBookingId,
    required int quantity,
    required String from,
    required String to,
    required double? dropOffLat,
    required double? dropOffLng,
  }) async {
    try {
      print('$_logPrefix Marking pre-booking as accomplished: $preBookingId');

      // Find and update the pre-booking document
      final preBookingQuery = await FirebaseFirestore.instance
          .collectionGroup('preBookings')
          .where(FieldPath.documentId, isEqualTo: preBookingId)
          .limit(1)
          .get();

      if (preBookingQuery.docs.isNotEmpty) {
        await preBookingQuery.docs.first.reference.update({
          'status': 'accomplished',
          'accomplishedAt': FieldValue.serverTimestamp(),
          'dropOffLocation': dropOffLat != null && dropOffLng != null
              ? {
                  'latitude': dropOffLat,
                  'longitude': dropOffLng,
                }
              : null,
        });

        print('$_logPrefix Pre-booking marked as accomplished in database');

        // Handle the passenger count decrement
        await handleTicketAccomplished(
          ticketId: preBookingId,
          quantity: quantity,
          from: from,
          to: to,
        );
      } else {
        print('$_logPrefix Pre-booking not found: $preBookingId');
      }
    } catch (e) {
      print('$_logPrefix Error marking pre-booking accomplished: $e');
      throw e;
    }
  }

  /// Mark a manual ticket as accomplished
  static Future<void> markManualTicketAccomplished({
    required String conductorId,
    required String date,
    required String ticketId,
    required int quantity,
    required String from,
    required String to,
  }) async {
    try {
      print('$_logPrefix Marking manual ticket as accomplished: $ticketId');

      // Try both possible paths for manual tickets
      DocumentReference? ticketRef;
      
      // First try: /conductors/{id}/remittance/{date}/manualTickets/{ticketId}
      try {
        final ref1 = FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorId)
            .collection('remittance')
            .doc(date)
            .collection('manualTickets')
            .doc(ticketId);
        
        final doc1 = await ref1.get();
        if (doc1.exists) {
          ticketRef = ref1;
          print('$_logPrefix Found manual ticket in manualTickets collection');
        }
      } catch (e) {
        print('$_logPrefix Manual tickets collection not found: $e');
      }
      
      // Second try: /conductors/{id}/remittance/{date}/tickets/{ticketId}
      if (ticketRef == null) {
        try {
          final ref2 = FirebaseFirestore.instance
              .collection('conductors')
              .doc(conductorId)
              .collection('remittance')
              .doc(date)
              .collection('tickets')
              .doc(ticketId);
          
          final doc2 = await ref2.get();
          if (doc2.exists) {
            final data = doc2.data() as Map<String, dynamic>?;
            // Check if this is a manual ticket
            if (data?['ticketType'] == 'manual') {
              ticketRef = ref2;
              print('$_logPrefix Found manual ticket in tickets collection');
            }
          }
        } catch (e) {
          print('$_logPrefix Tickets collection not found: $e');
        }
      }
      
      if (ticketRef != null) {
        // Update the ticket status
        await ticketRef.update({
          'status': 'accomplished',
          'accomplishedAt': FieldValue.serverTimestamp(),
        });

        print('$_logPrefix Manual ticket marked as accomplished in database');

        // Handle the passenger count decrement
        await handleTicketAccomplished(
          ticketId: ticketId,
          quantity: quantity,
          from: from,
          to: to,
        );
      } else {
        print('$_logPrefix Manual ticket not found in any expected location: $ticketId');
        throw Exception('Manual ticket not found: $ticketId');
      }
    } catch (e) {
      print('$_logPrefix Error marking manual ticket accomplished: $e');
      throw e;
    }
  }

  /// Get current conductor passenger count
  static Future<int> getCurrentPassengerCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final conductorQuery = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (conductorQuery.docs.isNotEmpty) {
        final conductorData = conductorQuery.docs.first.data();
        return conductorData['passengerCount'] ?? 0;
      }

      return 0;
    } catch (e) {
      print('$_logPrefix Error getting current passenger count: $e');
      return 0;
    }
  }

  /// Reset conductor passenger count to zero
  static Future<void> resetPassengerCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final conductorQuery = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (conductorQuery.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorQuery.docs.first.id)
            .update({
          'passengerCount': 0,
          'passengerCountResetAt': FieldValue.serverTimestamp(),
        });

        print('$_logPrefix Passenger count reset to 0');
      }
    } catch (e) {
      print('$_logPrefix Error resetting passenger count: $e');
      throw e;
    }
  }
}