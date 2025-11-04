# Destination Markers Implementation

This implementation adds destination markers to the conductor map based on coordinates stored in Firestore.

## Features Added

### 1. Destination Markers

- **Violet markers**: Forward route destinations
- **Orange markers**: Reverse route destinations
- **Info windows**: Show destination name, kilometer, and route direction
- **Automatic loading**: Destinations are loaded when the conductor map opens

### 2. Route Range Display

- Shows the kilometer range for the current route (e.g., "0-15 km" for Rosario)
- Displayed in the passenger count overlay

### 3. Removed Legend

- The legend overlay has been removed from the conductor map for a cleaner interface

## Setup Instructions

### 1. Google Geocoding API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Geocoding API**
4. Go to **Credentials** and create an API key
5. Update the API key in `lib/config/api_keys.dart`:

```dart
static const String googleGeocodingApiKey = 'YOUR_ACTUAL_API_KEY_HERE';
```

### 2. Firestore Database Structure

Your destinations should be structured like this in Firestore:

```
Destinations/
├── Rosario/
│   ├── Place/ (Forward route)
│   │   ├── SM City Lipa: {Name, km: 0, latitude, longitude}
│   │   ├── Lipa City Proper: {Name, km: 5, latitude, longitude}
│   │   └── Rosario: {Name, km: 15, latitude, longitude}
│   └── Place 2/ (Reverse route)
│       ├── Rosario: {Name, km: 0, latitude, longitude}
│       ├── Lipa City Proper: {Name, km: 10, latitude, longitude}
│       └── SM City Lipa: {Name, km: 15, latitude, longitude}
├── Batangas/
├── Mataas na Kahoy/
└── Tiaong/
```

### 3. Adding Coordinates to Destinations

For each destination in your Firestore database, add these fields:

```json
{
  "Name": "SM City Lipa",
  "km": 0,
  "latitude": 13.9425,
  "longitude": 121.1633
}
```

### 4. Geocoding Fallback

If coordinates are not available in Firestore, the system will:

1. Try to geocode the location using Google Geocoding API
2. Add the coordinates to Firestore for future use
3. Display the marker on the map

## Files Modified

### New Files:

- `lib/pages/conductor/destination_service.dart` - Service for handling destination markers
- `lib/config/api_keys.dart` - Configuration for API keys
- `DESTINATION_MARKERS_README.md` - This documentation

### Modified Files:

- `lib/pages/conductor/conductor_maps.dart` - Added destination markers and removed legend
- `pubspec.yaml` - Added http dependency for geocoding API calls

## Usage

1. **For Conductors**: The destination markers will automatically appear on the map when they open the conductor map
2. **Route Range**: The kilometer range is displayed in the top-left overlay
3. **Marker Colors**:
   - Blue: Conductor location
   - Violet: Forward route destinations
   - Orange: Reverse route destinations
   - Green: Pick-up locations
   - Red: Drop-off locations
   - Yellow: Passenger locations

## Example Routes

### Rosario Route (0-15 km)

- SM City Lipa (0 km)
- Lipa City Proper (5 km)
- Rosario (15 km)

### Batangas Route (0-25 km)

- SM City Lipa (0 km)
- Lipa City Proper (5 km)
- Batangas City (25 km)

## Troubleshooting

1. **Markers not appearing**: Check if coordinates are properly set in Firestore
2. **API errors**: Verify your Google Geocoding API key is correct and has proper permissions
3. **No route range**: Ensure destinations have valid `km` values in Firestore

## Security Notes

- Keep your API keys secure and never commit them to version control
- Consider using environment variables for production deployments
- Monitor API usage to avoid exceeding quotas
