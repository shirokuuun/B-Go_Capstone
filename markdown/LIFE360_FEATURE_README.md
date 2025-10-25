# B-Go Life360-like Bus Tracking Feature

## Features

### For Conductors:

1. **Location Tracking Dashboard**: Updated conductor dashboard with start/stop location tracking
2. **Real-time GPS Updates**: Location updates every 10 meters or 30 seconds
3. **Online/Offline Status**: Automatic status management when tracking starts/stops
4. **Route Information**: Displays assigned route and bus number

### For Passengers:

1. **Real-time Bus Map**: See all online buses on Google Maps
2. **Route-based Filtering**: Filter buses by specific routes
3. **Color-coded Markers**: Different colors for different routes
4. **Bus Information**: Tap markers to see bus details
5. **Live Updates**: Real-time location updates without refreshing

## Implementation Details

### Files Added/Modified:

1. **`lib/pages/conductor/location_service.dart`**

   - GPS tracking service for conductors
   - Firestore integration for location storage
   - Permission handling for location access

2. **`lib/pages/passenger/services/bus_location_service.dart`**

   - Service to fetch real-time bus locations
   - Route filtering functionality
   - Distance calculation utilities

3. **`lib/pages/conductor/conductor_dashboard.dart`**

   - Updated dashboard with location tracking controls
   - Start/stop tracking buttons
   - Status indicators and instructions

4. **`lib/pages/passenger/home_page.dart`**

   - Real-time bus markers on Google Maps
   - Route filtering dialog
   - Bus count indicator
   - Interactive map features

5. **`pubspec.yaml`**

   - Added `geolocator: ^13.0.1` for GPS functionality
   - Added `geocoding: ^3.0.0` for location services

6. **`android/app/src/main/AndroidManifest.xml`**
   - Added location permissions:
     - `ACCESS_FINE_LOCATION`
     - `ACCESS_COARSE_LOCATION`
     - `ACCESS_BACKGROUND_LOCATION`
     - `FOREGROUND_SERVICE`
     - `WAKE_LOCK`

## How to Use

### For Conductors:

1. Log in to the conductor account
2. Navigate to the Dashboard
3. Click "Start Tracking" to begin location sharing
4. The app will request location permissions if not already granted
5. Your bus will now appear on passengers' maps
6. Click "Stop Tracking" when your shift ends

### For Passengers:

1. Open the B-Go app as a passenger
2. Navigate to the Home page (map view)
3. See all online buses as colored markers
4. Tap the filter icon to filter by specific routes
5. Tap any bus marker to see details
6. Use the "My Location" button to center on your position

## Route Color Coding:

- **Batangas**: Red markers
- **Lipa**: Blue markers
- **Tanauan**: Green markers
- **Santo Tomas**: Yellow markers
- **Malvar**: Orange markers
- **Mataas na Kahoy**: Violet markers
- **Other routes**: Azure markers

## Technical Features:

### Real-time Updates:

- Location updates every 10 meters of movement
- Backup updates every 30 seconds
- Firestore real-time listeners for instant updates

### Privacy & Security:

- Only online conductors are visible
- Location data is stored securely in Firestore
- Automatic offline status when tracking stops

### Performance:

- Efficient marker updates
- Route-based filtering for better performance
- Distance-based filtering available

## Database Schema:

### Conductor Document Structure:

```json
{
  "email": "conductor@example.com",
  "name": "Conductor Name",
  "route": "Batangas",
  "busNumber": "BUS-001",
  "isOnline": true,
  "lastSeen": "timestamp",
  "currentLocation": {
    "latitude": 13.9407,
    "longitude": 121.1529,
    "timestamp": "timestamp",
    "accuracy": 5.0,
    "speed": 25.0,
    "heading": 90.0
  }
}
```

## Setup Instructions:

1. **Install Dependencies**:

   ```bash
   flutter pub get
   ```

2. **Configure Firebase**:

   - Ensure Firestore is enabled in your Firebase project
   - Set up appropriate security rules for the `conductors` collection

3. **Android Permissions**:

   - The necessary permissions are already added to `AndroidManifest.xml`
   - Users will be prompted for location permissions when needed

4. **Testing**:
   - Test with multiple conductor accounts on different routes
   - Verify real-time updates work correctly
   - Test route filtering functionality

## Future Enhancements:

- Custom bus icons for different vehicle types
- Estimated arrival times
- Route path visualization
- Push notifications for nearby buses
- Historical route tracking
- Bus capacity indicators

## Troubleshooting:

### Common Issues:

1. **Location not updating**: Check location permissions and GPS settings
2. **Buses not appearing**: Verify conductors have started location tracking
3. **Filter not working**: Ensure route names match exactly in the database
4. **Map not loading**: Check Google Maps API key configuration

### Debug Steps:

1. Check Firestore console for location data
2. Verify conductor `isOnline` status
3. Test location permissions manually
4. Check network connectivity for real-time updates
