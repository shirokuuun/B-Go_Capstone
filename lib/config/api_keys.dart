import 'package:flutter_dotenv/flutter_dotenv.dart';

// API Keys Configuration
// Add your API keys to the .env file in the root directory

class ApiKeys {
  // Google Maps API Key
  static String get googleMapsApiKey => 
    dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'YOUR_MAPS_API_KEY_HERE';
  static String get googleMapsApiDirectionsKey => 
    dotenv.env['GOOGLE_MAPS_API_DIRECTIONS_KEY'] ?? 'YOUR_MAPS_API_DIRECTIONS_KEY_HERE';
}
