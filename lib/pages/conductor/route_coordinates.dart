// Sample coordinates for B-Go routes
// This file contains sample coordinates for each route location
// Add these coordinates to your Firestore database in the Destinations collection

class RouteCoordinates {
  // Batangas Route Coordinates (SM Lipa to Batangas City)
  static const Map<String, Map<String, dynamic>> batangasPlaces = {
    'SM City Lipa': {
      'Name': 'SM City Lipa',
      'km': 0.0,
      'latitude': 13.9407,
      'longitude': 121.1529,
    },
    'Lipa City Proper': {
      'Name': 'Lipa City Proper',
      'km': 2.0,
      'latitude': 13.9420,
      'longitude': 121.1540,
    },
    'Batangas City': {
      'Name': 'Batangas City',
      'km': 28.0,
      'latitude': 13.7563,
      'longitude': 121.0583,
    },
  };

  // Rosario Route Coordinates (SM Lipa to Rosario)
  static const Map<String, Map<String, dynamic>> rosarioPlaces = {
    'SM City Lipa': {
      'Name': 'SM City Lipa',
      'km': 0.0,
      'latitude': 13.9407,
      'longitude': 121.1529,
    },
    'Rosario Proper': {
      'Name': 'Rosario Proper',
      'km': 1.0,
      'latitude': 13.843257,
      'longitude': 121.204127,
    },
    'San Roque': {
      'Name': 'San Roque',
      'km': 2.0,
      'latitude': 13.852393,
      'longitude': 121.204133,
    },
    'Quilib School': {
      'Name': 'Quilib School',
      'km': 3.0,
      'latitude': 13.858943,
      'longitude': 121.205942,
    },
    'Quilib Boundary': {
      'Name': 'Quilib Boundary',
      'km': 4.0,
      'latitude': 13.867770,
      'longitude': 121.208388,
    },
    'Padre Garcia (Pob)': {
      'Name': 'Padre Garcia (Pob)',
      'km': 5.0,
      'latitude': 13.876740,
      'longitude': 121.210798,
    },
    'Edson Lumber': {
      'Name': 'Edson Lumber',
      'km': 6.0,
      'latitude': 13.883350,
      'longitude': 121.205956,
    },
    'San Felipe': {
      'Name': 'San Felipe',
      'km': 7.0,
      'latitude': 13.891014,
      'longitude': 121.201524,
    },
    'Tejero Sampaloc': {
      'Name': 'Tejero Sampaloc',
      'km': 8.0,
      'latitude': 13.897106,
      'longitude': 121.197585,
    },
    'Pinagkawitan': {
      'Name': 'Pinagkawitan',
      'km': 9.0,
      'latitude': 13.903381,
      'longitude': 121.192652,
    },
    'Tower Feeds': {
      'Name': 'Tower Feeds',
      'km': 10.0,
      'latitude': 13.906773,
      'longitude': 121.189956,
    },
    'San Adriano': {
      'Name': 'San Adriano',
      'km': 11.0,
      'latitude': 13.910657,
      'longitude': 121.186624,
    },
    'Antipolo Sur': {
      'Name': 'Antipolo Sur',
      'km': 12.0,
      'latitude': 13.916125,
      'longitude': 121.179550,
    },
    'Antipolo Norte': {
      'Name': 'Antipolo Norte',
      'km': 13.0,
      'latitude': 13.925642,
      'longitude': 121.171170,
    },
    'Rancho Jota': {
      'Name': 'Rancho Jota',
      'km': 14.0,
      'latitude': 13.934412,
      'longitude': 121.165489,
    },
    'Lipa City Proper': {
      'Name': 'Lipa City Proper',
      'km': 15.0,
      'latitude': 13.953451,
      'longitude': 121.162575,
    },
  };

  // Mataas na Kahoy Route Coordinates (SM Lipa to Mataas na Kahoy)
  static const Map<String, Map<String, dynamic>> mataasNaKahoyPlaces = {
    'SM City Lipa': {
      'Name': 'SM City Lipa',
      'km': 0.0,
      'latitude': 13.9407,
      'longitude': 121.1529,
    },
    'Mataas na Kahoy Terminal': {
      'Name': 'Mataas na Kahoy Terminal',
      'km': 8.0,
      'latitude': 13.9000,
      'longitude': 121.1800,
    },
  };

  // Tiaong Route Coordinates (SM Lipa to Tiaong)
  static const Map<String, Map<String, dynamic>> tiaongPlaces = {
    'SM City Lipa': {
      'Name': 'SM City Lipa',
      'km': 0.0,
      'latitude': 13.9407,
      'longitude': 121.1529,
    },
    'Tiaong': {
      'Name': 'Tiaong',
      'km': 30.0,
      'latitude': 13.9500,
      'longitude': 121.3000,
    },
  };

  // San Juan Route Coordinates (SM Lipa to San Juan)
  static const Map<String, Map<String, dynamic>> sanJuanPlaces = {
    'SM City Lipa': {
      'Name': 'SM City Lipa',
      'km': 0.0,
      'latitude': 13.9407,
      'longitude': 121.1529,
    },
    'San Juan': {
      'Name': 'San Juan',
      'km': 37.0,
      'latitude': 13.8000,
      'longitude': 121.4000,
    },
  };

  // Helper method to get coordinates for a specific route
  static Map<String, Map<String, dynamic>> getCoordinatesForRoute(String route) {
    switch (route.trim()) {
      case 'Batangas':
        return batangasPlaces;
      case 'Rosario':
        return rosarioPlaces;
      case 'Mataas na Kahoy':
        return mataasNaKahoyPlaces;
      case 'Tiaong':
        return tiaongPlaces;
      case 'San Juan':
        return sanJuanPlaces;
      default:
        return {};
    }
  }

  // Helper method to get reverse route coordinates
  static Map<String, Map<String, dynamic>> getReverseCoordinatesForRoute(String route) {
    final forwardCoordinates = getCoordinatesForRoute(route);
    final reverseCoordinates = <String, Map<String, dynamic>>{};
    
    final keys = forwardCoordinates.keys.toList();
    for (int i = keys.length - 1; i >= 0; i--) {
      final key = keys[i];
      final data = forwardCoordinates[key]!;
      final reverseKey = keys[keys.length - 1 - i];
      
      reverseCoordinates[reverseKey] = {
        'Name': data['Name'],
        'km': data['km'],
        'latitude': data['latitude'],
        'longitude': data['longitude'],
      };
    }
    
    return reverseCoordinates;
  }
}

/*
Database Setup Instructions:

1. Go to your Firestore console
2. Navigate to the 'Destinations' collection
3. For each route (Batangas, Rosario, Mataas na Kahoy, Tiaong, San Juan):
   - Create a document with the route name
   - Create a 'Place' subcollection
   - Add documents for each location with the following fields:
     * Name: Location name
     * km: Distance from start
     * latitude: GPS latitude
     * longitude: GPS longitude

4. For reverse routes, create a 'Place 2' subcollection with the same data

Example for Batangas route:
Collection: Destinations
Document: Batangas
Subcollection: Place
Documents:
  - SM City Lipa: {Name: "SM City Lipa", km: 0.0, latitude: 13.9407, longitude: 121.1529}
  - Lipa City Proper: {Name: "Lipa City Proper", km: 2.0, latitude: 13.9420, longitude: 121.1540}
  - Batangas City: {Name: "Batangas City", km: 28.0, latitude: 13.7563, longitude: 121.0583}

Subcollection: Place 2 (reverse route)
Documents:
  - Batangas City: {Name: "Batangas City", km: 0.0, latitude: 13.7563, longitude: 121.0583}
  - Lipa City Proper: {Name: "Lipa City Proper", km: 26.0, latitude: 13.9420, longitude: 121.1540}
  - SM City Lipa: {Name: "SM City Lipa", km: 28.0, latitude: 13.9407, longitude: 121.1529}
*/
