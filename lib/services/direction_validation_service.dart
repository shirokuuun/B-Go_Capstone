import 'package:cloud_firestore/cloud_firestore.dart';

class DirectionValidationService {
  // Map passenger direction labels to conductor direction labels
  static const Map<String, Map<String, String>> _directionMapping = {
    'Batangas': {
      'SM Lipa to Batangas City': 'SM City Lipa - Batangas City',
      'Batangas City to SM Lipa': 'Batangas City - SM City Lipa',
    },
    'Rosario': {
      'SM Lipa to Rosario': 'SM City Lipa - Rosario',
      'Rosario to SM Lipa': 'Rosario - SM City Lipa',
    },
    'Mataas na Kahoy': {
      'SM Lipa to Mataas na Kahoy': 'SM City Lipa - Mataas na Kahoy',
      'Mataas na Kahoy to SM Lipa': 'Mataas na Kahoy - SM City Lipa',
    },
    'Mataas Na Kahoy Palengke': {
      'Lipa Palengke to Mataas na Kahoy': 'Lipa Palengke - Mataas na Kahoy',
      'Mataas na Kahoy to Lipa Palengke': 'Mataas na Kahoy - Lipa Palengke',
    },
    'Tiaong': {
      'SM Lipa to Tiaong': 'SM City Lipa - Tiaong',
      'Tiaong to SM Lipa': 'Tiaong - SM City Lipa',
    },
    'San Juan': {
      'SM Lipa to San Juan': 'SM City Lipa - San Juan',
      'San Juan to SM Lipa': 'San Juan - SM City Lipa',
    },
  };

  // Map passenger place collections to conductor place collections
  static const Map<String, Map<String, String>> _placeCollectionMapping = {
    'Batangas': {
      'Place': 'Place',
      'Place 2': 'Place 2',
    },
    'Rosario': {
      'Place': 'Place',
      'Place 2': 'Place 2',
    },
    'Mataas na Kahoy': {
      'Place': 'Place',
      'Place 2': 'Place 2',
    },
    'Mataas Na Kahoy Palengke': {
      'Place': 'Place',
      'Place 2': 'Place 2',
    },
    'Tiaong': {
      'Place': 'Place',
      'Place 2': 'Place 2',
    },
    'San Juan': {
      'Place': 'Place',
      'Place 2': 'Place 2',
    },
  };

  /// Validates if a passenger's pre-ticket direction is compatible with conductor's active trip
  /// Returns true if compatible, false otherwise
  static Future<bool> validateDirectionCompatibility({
    required String passengerRoute,
    required String passengerDirection,
    required String conductorUid,
  }) async {
    try {
      // Get conductor's active trip information
      final conductorDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: conductorUid)
          .limit(1)
          .get();

      if (conductorDoc.docs.isEmpty) {
        print('❌ DirectionValidation: Conductor not found');
        return false;
      }

      final conductorData = conductorDoc.docs.first.data();
      final activeTrip = conductorData['activeTrip'];

      if (activeTrip == null || activeTrip['isActive'] != true) {
        print('❌ DirectionValidation: No active trip found for conductor');
        return false;
      }

      final conductorRoute = conductorData['route'];
      final conductorDirection = activeTrip['direction'];
      final conductorPlaceCollection = activeTrip['placeCollection'];

      print('🔍 DirectionValidation:');
      print('  Passenger Route: $passengerRoute');
      print('  Passenger Direction: $passengerDirection');
      print('  Conductor Route: $conductorRoute');
      print('  Conductor Direction: $conductorDirection');
      print('  Conductor Place Collection: $conductorPlaceCollection');

      // First check if routes match
      if (conductorRoute != passengerRoute) {
        print('❌ DirectionValidation: Route mismatch - $conductorRoute vs $passengerRoute');
        return false;
      }

      // Map passenger direction to conductor direction format
      final mappedDirection = _directionMapping[passengerRoute]?[passengerDirection];
      if (mappedDirection == null) {
        print('❌ DirectionValidation: Could not map passenger direction: $passengerDirection');
        return false;
      }

      // Check if directions match
      if (mappedDirection != conductorDirection) {
        print('❌ DirectionValidation: Direction mismatch - $mappedDirection vs $conductorDirection');
        return false;
      }

      print('✅ DirectionValidation: Directions are compatible');
      return true;

    } catch (e) {
      print('❌ DirectionValidation: Error validating direction: $e');
      return false;
    }
  }

  /// Validates direction compatibility using place collection instead of direction labels
  static Future<bool> validateDirectionCompatibilityByCollection({
    required String passengerRoute,
    required String passengerPlaceCollection,
    required String conductorUid,
  }) async {
    try {
      // Get conductor's active trip information
      final conductorDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: conductorUid)
          .limit(1)
          .get();

      if (conductorDoc.docs.isEmpty) {
        print('❌ DirectionValidation: Conductor not found');
        return false;
      }

      final conductorData = conductorDoc.docs.first.data();
      final activeTrip = conductorData['activeTrip'];

      if (activeTrip == null || activeTrip['isActive'] != true) {
        print('❌ DirectionValidation: No active trip found for conductor');
        return false;
      }

      final conductorRoute = conductorData['route'];
      final conductorPlaceCollection = activeTrip['placeCollection'];

      print('🔍 DirectionValidation (by collection):');
      print('  Passenger Route: $passengerRoute');
      print('  Passenger Place Collection: $passengerPlaceCollection');
      print('  Conductor Route: $conductorRoute');
      print('  Conductor Place Collection: $conductorPlaceCollection');

      // First check if routes match
      if (conductorRoute != passengerRoute) {
        print('❌ DirectionValidation: Route mismatch - $conductorRoute vs $passengerRoute');
        return false;
      }

      // Map passenger place collection to conductor place collection
      final mappedCollection = _placeCollectionMapping[passengerRoute]?[passengerPlaceCollection];
      if (mappedCollection == null) {
        print('❌ DirectionValidation: Could not map passenger place collection: $passengerPlaceCollection');
        return false;
      }

      // Check if place collections match
      if (mappedCollection != conductorPlaceCollection) {
        print('❌ DirectionValidation: Place collection mismatch - $mappedCollection vs $conductorPlaceCollection');
        return false;
      }

      print('✅ DirectionValidation: Place collections are compatible');
      return true;

    } catch (e) {
      print('❌ DirectionValidation: Error validating direction by collection: $e');
      return false;
    }
  }

  /// Gets a user-friendly error message for direction mismatch
  static String getDirectionMismatchMessage({
    required String passengerRoute,
    required String passengerDirection,
    required String conductorDirection,
  }) {
    return 'Direction mismatch! Your ticket is for "$passengerDirection" but the conductor is currently on "$conductorDirection" trip. Please wait for the correct direction or contact the conductor.';
  }

  /// Gets a user-friendly error message for route mismatch
  static String getRouteMismatchMessage({
    required String passengerRoute,
    required String conductorRoute,
  }) {
    return 'Route mismatch! Your ticket is for "$passengerRoute" route but the conductor is assigned to "$conductorRoute" route. Please find the correct conductor for your route.';
  }
}
