import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
      'Price': 2000,
    };

    await FirebaseFirestore.instance
        .collection('AvailableBuses')
        .doc(busName)
        .set(busData);
  }

  // Fetch buses with coding days that match this week
  static Future<List<Map<String, dynamic>>> getAvailableBuses() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('AvailableBuses')
        .where('status', isEqualTo: 'active')
        .get();

    print('📦 Fetched ${snapshot.docs.length} bus docs from Firestore');

    const allWeekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
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
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    print(
        '✅ Available (Coded) Buses for the rest of this week: ${availableBuses.length}');
    return availableBuses;
  }

  // Fetch conductor data from Firestore
  static Future<Map<String, dynamic>?> getConductorData(
      String conductorId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error fetching conductor data: $e');
      return null;
    }
  }

  // Fetch all conductors from Firestore
  static Future<List<Map<String, dynamic>>> getAllConductors() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('conductors').get();

      print('📦 Fetched ${snapshot.docs.length} conductor docs from Firestore');

      final conductors = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      print('✅ Retrieved ${conductors.length} conductors');
      return conductors;
    } catch (e) {
      print('Error fetching all conductors: $e');
      return [];
    }
  }

  // Get all conductors formatted as bus data for display
  static Future<List<Map<String, dynamic>>> getAllConductorsAsBuses() async {
    try {
      final conductors = await getAllConductors();

      final buses = conductors.map((conductor) {
        final plateNumber = conductor['plateNumber'] as String? ?? '';
        final lastDigit = plateNumber.isNotEmpty
            ? int.tryParse(plateNumber[plateNumber.length - 1]) ?? 0
            : 0;

        // Determine coding days based on plate number ending
        // These are the days when the bus is AVAILABLE for charter/reservation
        final codingRules = {
          1: ['Monday'],
          2: ['Monday'],
          3: ['Tuesday'],
          4: ['Tuesday'],
          5: ['Wednesday'],
          6: ['Wednesday'],
          7: ['Thursday'],
          8: ['Thursday'],
          9: ['Friday'],
          0: ['Friday'],
        };

        final codingDays = codingRules[lastDigit] ?? [];

        return {
          'id': conductor['id'],
          'name': conductor['name'] ?? 'Unknown Conductor',
          'plateNumber': plateNumber,
          'codingDays': codingDays,
          'Price': 2000,
          'status': 'active',
          'conductorData': conductor,
        };
      }).toList();

      print('✅ Formatted ${buses.length} conductors as buses');
      return buses;
    } catch (e) {
      print('Error formatting conductors as buses: $e');
      return [];
    }
  }

  // Check if bus is available for reservation based on coding day
  // Returns TRUE if the selected date matches the bus's coding day
  // Returns FALSE if the selected date does NOT match the bus's coding day
  static bool isBusAvailableForReservation(
      String plateNumber, DateTime selectedDate) {
    if (plateNumber.isEmpty) return false;

    final lastDigit = plateNumber.isNotEmpty
        ? int.tryParse(plateNumber[plateNumber.length - 1]) ?? 0
        : 0;

    // Philippines coding day system
    // Buses are available for reservation on their coding days
    final codingRules = {
      1: ['Monday'],
      2: ['Monday'],
      3: ['Tuesday'],
      4: ['Tuesday'],
      5: ['Wednesday'],
      6: ['Wednesday'],
      7: ['Thursday'],
      8: ['Thursday'],
      9: ['Friday'],
      0: ['Friday'],
    };

    final codingDays = codingRules[lastDigit] ?? [];
    final selectedWeekday = DateFormat('EEEE').format(selectedDate);

    // Return TRUE if the selected date IS on the bus's coding day
    final isOnCodingDay = codingDays.contains(selectedWeekday);

    print(
        '🔍 Plate: $plateNumber | Selected: $selectedWeekday | Coding Days: $codingDays | Available: $isOnCodingDay');

    return isOnCodingDay;
  }

  // Keep the old method name for backward compatibility
  static bool isBusAvailableForCoding(
      String plateNumber, DateTime selectedDate) {
    return isBusAvailableForReservation(plateNumber, selectedDate);
  }

  // Get bus availability status based on reservation status ONLY
  // This checks if the bus is reserved/pending, NOT coding day
  static String getBusAvailabilityStatus(Map<String, dynamic> conductorData) {
    final busAvailabilityStatus =
        conductorData['busAvailabilityStatus'] as String? ?? 'available';

    if (busAvailabilityStatus == 'pending') {
      return 'pending';
    }

    // Treat both 'reserved' and 'confirmed' as reserved status
    if (busAvailabilityStatus == 'reserved' ||
        busAvailabilityStatus == 'confirmed') {
      return 'reserved';
    }

    if (busAvailabilityStatus == 'no-reservation') {
      return 'available';
    }

    final availableForReservation =
        conductorData['availableForReservation'] as bool? ?? true;

    if (!availableForReservation) {
      return 'unavailable';
    }

    return busAvailabilityStatus;
  }

  // Check if a bus is reserved for a specific date
  static bool isBusReservedForDate(
      Map<String, dynamic> conductorData, DateTime selectedDate) {
    final busAvailabilityStatus =
        conductorData['busAvailabilityStatus'] as String? ?? 'available';

    if (busAvailabilityStatus != 'reserved') {
      return false;
    }

    final reservationDetails =
        conductorData['reservationDetails'] as Map<String, dynamic>?;
    if (reservationDetails == null) {
      return false;
    }

    final departureDate = reservationDetails['departureDate'] as Timestamp?;
    if (departureDate == null) {
      return false;
    }

    final reservationDate = departureDate.toDate();

    return reservationDate.year == selectedDate.year &&
        reservationDate.month == selectedDate.month &&
        reservationDate.day == selectedDate.day;
  }

  // Check if a bus should be available again after the reservation date has passed
  static bool shouldBusBeAvailableAgain(Map<String, dynamic> conductorData) {
    final busAvailabilityStatus =
        conductorData['busAvailabilityStatus'] as String? ?? 'available';

    if (busAvailabilityStatus != 'reserved') {
      return false;
    }

    final reservationDetails =
        conductorData['reservationDetails'] as Map<String, dynamic>?;
    if (reservationDetails == null) {
      return false;
    }

    final departureDate = reservationDetails['departureDate'] as Timestamp?;
    if (departureDate == null) {
      return false;
    }

    final reservationDate = departureDate.toDate();
    final now = DateTime.now();

    return now.isAfter(reservationDate);
  }

  // Check if bus should be grayed out
  // A bus should be grayed out if:
  // 1. When a weekday filter is selected AND the bus is not available on that day
  // 2. OR if the bus is reserved/pending regardless of filter
  static bool isBusGrayedOutDueToCoding(
      String plateNumber, DateTime? selectedDate) {
    if (selectedDate == null) return false;

    // Gray out if NOT available for reservation on the selected date
    final isAvailableForReservation =
        isBusAvailableForReservation(plateNumber, selectedDate);

    print(
        '🎨 Gray out check - Plate: $plateNumber | Available: $isAvailableForReservation | Should Gray: ${!isAvailableForReservation}');

    return !isAvailableForReservation;
  }

  // Get conductor data by plate number
  static Map<String, dynamic>? getConductorByPlateNumber(
      List<Map<String, dynamic>> conductors, String plateNumber) {
    try {
      return conductors.firstWhere(
        (conductor) => conductor['plateNumber'] == plateNumber,
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      print('Error finding conductor by plate number: $e');
      return null;
    }
  }

  static Future<String> saveReservation({
    required List<String> selectedBusIds,
    required String from,
    required String to,
    required bool isRoundTrip,
    required String fullName,
    required String email,
    DateTime? departureDate,
    String? departureTime,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final reservationsRef = firestore.collection('reservations');

    final snapshot = await reservationsRef.get();
    final newReservationId = 'reservation ${snapshot.docs.length + 1}';

    await reservationsRef.doc(newReservationId).set({
      'selectedBusIds': selectedBusIds,
      'from': from,
      'to': to,
      'isRoundTrip': isRoundTrip,
      'fullName': fullName,
      'email': email,
      'departureDate':
          departureDate != null ? Timestamp.fromDate(departureDate) : null,
      'departureTime': departureTime,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    for (String conductorId in selectedBusIds) {
      final conductorRef = firestore.collection('conductors').doc(conductorId);

      await conductorRef.update({
        'busAvailabilityStatus': 'pending',
        'availableForReservation': false,
        'reservationId': newReservationId,
        'reservationDetails': {
          'from': from,
          'to': to,
          'isRoundTrip': isRoundTrip,
          'fullName': fullName,
          'email': email,
          'departureDate':
              departureDate != null ? Timestamp.fromDate(departureDate) : null,
          'departureTime': departureTime,
          'reservedAt': FieldValue.serverTimestamp(),
          'status': 'pending',
        }
      });
    }

    return newReservationId;
  }

  // Admin method to verify payment and change status from pending to reserved
  static Future<void> verifyPaymentAndConfirmReservation(
      String reservationId) async {
    final firestore = FirebaseFirestore.instance;

    try {
      final reservationDoc =
          await firestore.collection('reservations').doc(reservationId).get();

      if (!reservationDoc.exists) {
        throw Exception('Reservation not found');
      }

      final reservationData = reservationDoc.data() as Map<String, dynamic>;
      final selectedBusIds =
          List<String>.from(reservationData['selectedBusIds'] ?? []);

      await firestore.collection('reservations').doc(reservationId).update({
        'status': 'confirmed',
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': 'admin',
      });

      for (String conductorId in selectedBusIds) {
        await firestore.collection('conductors').doc(conductorId).update({
          'busAvailabilityStatus': 'reserved',
          'reservationDetails.status': 'confirmed',
          'reservationDetails.verifiedAt': FieldValue.serverTimestamp(),
        });
      }

      print('✅ Payment verified and reservation confirmed for: $reservationId');
    } catch (e) {
      print('❌ Error verifying payment: $e');
      rethrow;
    }
  }

  // Admin method to reject payment and cancel reservation
  static Future<void> rejectPaymentAndCancelReservation(
      String reservationId, String reason) async {
    final firestore = FirebaseFirestore.instance;

    try {
      final reservationDoc =
          await firestore.collection('reservations').doc(reservationId).get();

      if (!reservationDoc.exists) {
        throw Exception('Reservation not found');
      }

      final reservationData = reservationDoc.data() as Map<String, dynamic>;
      final selectedBusIds =
          List<String>.from(reservationData['selectedBusIds'] ?? []);

      await firestore.collection('reservations').doc(reservationId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': reason,
        'cancelledBy': 'admin',
      });

      for (String conductorId in selectedBusIds) {
        await firestore.collection('conductors').doc(conductorId).update({
          'busAvailabilityStatus': 'no-reservation',
          'availableForReservation': true,
          'reservationId': FieldValue.delete(),
          'reservationDetails': FieldValue.delete(),
        });
      }

      print('✅ Payment rejected and reservation cancelled for: $reservationId');
    } catch (e) {
      print('❌ Error rejecting payment: $e');
      rethrow;
    }
  }

  // Get all pending reservations for admin review
  static Future<List<Map<String, dynamic>>> getPendingReservations() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reservations')
          .where('status', isEqualTo: 'pending')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching pending reservations: $e');
      return [];
    }
  }

  // Get all reservations with receipt uploaded
  static Future<List<Map<String, dynamic>>>
      getReservationsWithReceipts() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reservations')
          .where('status', isEqualTo: 'receipt_uploaded')
          .orderBy('receiptUploadedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching reservations with receipts: $e');
      return [];
    }
  }

  // Get all user reservations
  static Future<List<Map<String, dynamic>>> getAllUserReservations() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reservations')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching all user reservations: $e');
      return [];
    }
  }

  // Get reservations for a specific user by email
  static Future<List<Map<String, dynamic>>> getUserReservationsByEmail(
      String email) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reservations')
          .where('email', isEqualTo: email)
          .get();

      final reservations = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      reservations.sort((a, b) {
        final timestampA = a['timestamp'] as Timestamp?;
        final timestampB = b['timestamp'] as Timestamp?;

        if (timestampA == null && timestampB == null) return 0;
        if (timestampA == null) return 1;
        if (timestampB == null) return -1;

        return timestampB.compareTo(timestampA);
      });

      return reservations;
    } catch (e) {
      print('Error fetching user reservations by email: $e');
      return [];
    }
  }

  // Automatically cancel expired pending reservations (older than 2 days)
  static Future<void> cancelExpiredReservations() async {
    try {
      final now = DateTime.now();
      final twoDaysAgo = now.subtract(Duration(days: 2));

      final expiredReservations = await FirebaseFirestore.instance
          .collection('reservations')
          .where('status', isEqualTo: 'pending')
          .where('timestamp', isLessThan: Timestamp.fromDate(twoDaysAgo))
          .get();

      print(
          '🔍 Found ${expiredReservations.docs.length} expired reservations to cancel');

      for (var doc in expiredReservations.docs) {
        await _cancelExpiredReservation(doc.id, doc.data());
      }
    } catch (e) {
      print('❌ Error cancelling expired reservations: $e');
    }
  }

  // Automatically make buses available again after their reservation date has passed
  static Future<void> updateExpiredReservations() async {
    try {
      final conductorsSnapshot = await FirebaseFirestore.instance
          .collection('conductors')
          .where('busAvailabilityStatus', isEqualTo: 'reserved')
          .get();

      print(
          '🔍 Found ${conductorsSnapshot.docs.length} reserved conductors to check');

      for (var doc in conductorsSnapshot.docs) {
        final conductorData = doc.data();

        if (shouldBusBeAvailableAgain(conductorData)) {
          await _makeConductorAvailableAgain(doc.id, conductorData);
        }
      }
    } catch (e) {
      print('❌ Error updating expired reservations: $e');
    }
  }

  // Helper method to make a conductor available again after reservation expires
  static Future<void> _makeConductorAvailableAgain(
      String conductorId, Map<String, dynamic> conductorData) async {
    try {
      await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .update({
        'busAvailabilityStatus': 'no-reservation',
        'availableForReservation': true,
        'reservationId': FieldValue.delete(),
        'reservationDetails': FieldValue.delete(),
      });

      print(
          '✅ Made conductor $conductorId available again after reservation expired');
    } catch (e) {
      print('❌ Error making conductor $conductorId available again: $e');
    }
  }

  // Helper method to cancel a single expired reservation
  static Future<void> _cancelExpiredReservation(
      String reservationId, Map<String, dynamic> reservationData) async {
    try {
      final selectedBusIds =
          List<String>.from(reservationData['selectedBusIds'] ?? []);

      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason':
            'Automatic cancellation - No receipt uploaded within 2 days',
        'cancelledBy': 'system',
      });

      for (String conductorId in selectedBusIds) {
        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorId)
            .update({
          'busAvailabilityStatus': 'no-reservation',
          'availableForReservation': true,
          'reservationId': FieldValue.delete(),
          'reservationDetails': FieldValue.delete(),
        });
      }

      print('✅ Automatically cancelled expired reservation: $reservationId');
    } catch (e) {
      print('❌ Error cancelling expired reservation $reservationId: $e');
    }
  }
}
