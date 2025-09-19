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
      data['id'] = doc.id; // <- Save Firestore doc ID (busName)
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

      // Format conductors as bus data
      final buses = conductors.map((conductor) {
        final plateNumber = conductor['plateNumber'] as String? ?? '';
        final lastDigit =
            int.tryParse(plateNumber.substring(plateNumber.length - 1)) ?? 0;

        // Determine coding days based on plate number ending
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
          'Price': 2000, // Default price
          'status': 'active',
          'conductorData': conductor, // Keep original conductor data
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
  // Returns true if bus is available for reservation (on coding day), false if not available
  static bool isBusAvailableForReservation(String plateNumber, DateTime selectedDate) {
    if (plateNumber.isEmpty) return true;

    // Get the last digit of plate number
    final lastDigit = int.tryParse(plateNumber.substring(plateNumber.length - 1)) ?? 0;

    // Philippines coding day system - buses are AVAILABLE for reservation on these days
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

    // Return true if IS on coding day (available for reservation)
    final isOnCodingDay = codingDays.contains(selectedWeekday);
    
    print('🔍 Plate: $plateNumber, Selected: $selectedWeekday, Coding Days: $codingDays');
    print('🔍 Is on coding day (available for reservation): $isOnCodingDay');
    
    return isOnCodingDay;
  }

  // Keep the old method name for backward compatibility
  static bool isBusAvailableForCoding(String plateNumber, DateTime selectedDate) {
    return isBusAvailableForReservation(plateNumber, selectedDate);
  }

  // Get bus availability status - Fixed version
  static String getBusAvailabilityStatus(Map<String, dynamic> conductorData) {
    if (conductorData['activeTrip'] == null) {
      print('🔍 No activeTrip found for conductor: ${conductorData['name']} - Defaulting to available');
      return 'available'; // Changed: No active trip means available for reservation
    }

    final activeTrip = conductorData['activeTrip'] as Map<String, dynamic>;
    
    // Check if bus is available for reservation (new field)
    final availableForReservation = activeTrip['availableForReservation'] as bool? ?? true;
    
    print('🔍 Conductor: ${conductorData['name']}, Plate: ${conductorData['plateNumber']}');
    print('🔍 ActiveTrip: $activeTrip');
    print('🔍 AvailableForReservation: $availableForReservation');
    
    // If explicitly set as available for reservation, return available
    if (availableForReservation) {
      return 'available';
    }
    
    // Check the old busAvailabilityStatus field as fallback
    final busAvailabilityStatus = activeTrip['busAvailabilityStatus'] as String? ?? 'available';
    print('🔍 BusAvailabilityStatus (fallback): $busAvailabilityStatus');
    
    return busAvailabilityStatus;
  }

  // Check if bus should be grayed out due to coding day restrictions
  // Buses are grayed out if they are NOT on their coding day (not available for reservation)
  static bool isBusGrayedOutDueToCoding(String plateNumber, DateTime? selectedDate) {
    if (selectedDate == null) return false;
    
    // Gray out if NOT available for reservation (not on coding day)
    final isAvailableForReservation = isBusAvailableForReservation(plateNumber, selectedDate);
    final shouldGrayOut = !isAvailableForReservation;
    
    print('🔍 Should gray out bus $plateNumber: $shouldGrayOut (available for reservation: $isAvailableForReservation)');
    
    return shouldGrayOut;
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