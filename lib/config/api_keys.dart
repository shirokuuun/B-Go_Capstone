import 'package:flutter_dotenv/flutter_dotenv.dart';

// API Keys Configuration
// Add your API keys to the .env file in the root directory

class ApiKeys {
  // Google Geocoding API Key
  // Get this from: https://console.cloud.google.com/apis/credentials
  static String get googleGeocodingApiKey => 
    dotenv.env['GOOGLE_GEOCODING_API_KEY'] ?? 'YOUR_GEOCODING_API_KEY_HERE';
  
  // Google Maps API Key (if different from geocoding)
  static String get googleMapsApiKey => 
    dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'YOUR_MAPS_API_KEY_HERE';
}
