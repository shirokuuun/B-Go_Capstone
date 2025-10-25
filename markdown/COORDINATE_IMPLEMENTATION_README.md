# B-Go Coordinate Implementation

This document explains the coordinate system implementation for the B-Go bus tracking app.

## Overview

The coordinate system allows conductors to see passenger pick-up and drop-off locations on a map, and automatically manages passenger count when the conductor reaches drop-off locations.

## Key Features

### 1. Route Coordinates

- Each route location now includes GPS coordinates (latitude/longitude)
- Coordinates are stored in Firestore alongside existing data
- Supports both forward and reverse routes

### 2. Pre-Booking with Coordinates

- When users pre-book, their pick-up and drop-off coordinates are saved
- Coordinates are used to show exact locations on the conductor's map
- No more simulated locations - real GPS coordinates are used

### 3. Conductor Map Features

- **Real-time passenger tracking**: Shows actual pick-up and drop-off locations
- **Automatic passenger count management**: When conductor reaches drop-off radius (200m), passengers are automatically removed
- **Visual markers**:
  - Blue marker: Conductor location
  - Green markers: Pick-up locations
  - Red markers: Drop-off locations
  - Yellow markers: Passenger current locations
- **Passenger count display**: Shows current passenger count and number of bookings

## Database Structure

### Firestore Collections

```
Destinations/
├── Batangas/
│   ├── Place/ (Forward route)
│   │   ├── SM City Lipa: {Name, km, latitude, longitude}
│   │   ├── Lipa City Proper: {Name, km, latitude, longitude}
│   │   └── Batangas City: {Name, km, latitude, longitude}
│   └── Place 2/ (Reverse route)
│       ├── Batangas City: {Name, km, latitude, longitude}
│       ├── Lipa City Proper: {Name, km, latitude, longitude}
│       └── SM City Lipa: {Name, km, latitude, longitude}
├── Rosario/
├── Mataas na Kahoy/
├── Tiaong/
└── San Juan/
```

### Pre-Booking Data Structure

```json
{
  "route": "Batangas",
  "direction": "SM Lipa to Batangas City",
  "from": "SM City Lipa",
  "to": "Batangas City",
  "fromKm": 0.0,
  "toKm": 28.0,
  "fromLatitude": 13.9407,
  "fromLongitude": 121.1529,
  "toLatitude": 13.7563,
  "toLongitude": 121.0583,
  "passengerLatitude": 13.9407,
  "passengerLongitude": 121.1529,
  "passengerLocationTimestamp": "timestamp",
  "quantity": 2,
  "status": "paid",
  "userId": "user_uid"
}
```

## Implementation Details

### 1. RouteService Updates

- Added coordinate fields to `fetchPlaces()` method
- Added `calculateDistance()` method for proximity calculations
- Uses Haversine formula for accurate distance calculation

### 2. Pre-Booking Updates

- Saves pick-up and drop-off coordinates when booking
- Includes user ID for tracking
- Coordinates are used for map visualization

### 3. Conductor Maps Updates

- Real-time location tracking every 10 seconds
- Automatic passenger drop-off when within 200m radius
- Visual feedback with different colored markers
- Passenger count management

## Setup Instructions

### 1. Database Setup

1. Go to your Firestore console
2. Navigate to the 'Destinations' collection
3. For each route, add coordinate data:
   - Add `latitude` and `longitude` fields to existing location documents
   - Use the sample coordinates from `route_coordinates.dart`

### 2. Sample Coordinates

Use the coordinates provided in `lib/pages/conductor/route_coordinates.dart`:

- SM City Lipa: 13.9407, 121.1529
- Batangas City: 13.7563, 121.0583
- Rosario: 13.8500, 121.2000
- Mataas na Kahoy: 13.9000, 121.1800
- Tiaong: 13.9500, 121.3000
- San Juan: 13.8000, 121.4000

### 3. Manual Database Update Steps

**IMPORTANT: You need to manually add coordinates to your Firestore database**

1. **Open Firebase Console**:

   - Go to https://console.firebase.google.com
   - Select your B-Go project
   - Go to Firestore Database

2. **Navigate to Destinations Collection**:

   - Find the "Destinations" collection
   - Click on each route document (Batangas, Rosario, etc.)

3. **Update Place Documents**:

   - For each route, find the "Place" subcollection
   - Click on each location document
   - Add these fields:
     - `latitude`: (number) - GPS latitude coordinate
     - `longitude`: (number) - GPS longitude coordinate

4. **Example for Batangas Route**:

   ```
   Collection: Destinations
   Document: Batangas
   Subcollection: Place
   Documents:
     - SM City Lipa:
       * Name: "SM City Lipa"
       * km: 0.0
       * latitude: 13.9407
       * longitude: 121.1529

     - Lipa City Proper:
       * Name: "Lipa City Proper"
       * km: 2.0
       * latitude: 13.9420
       * longitude: 121.1540

     - Batangas City:
       * Name: "Batangas City"
       * km: 28.0
       * latitude: 13.7563
       * longitude: 121.0583
   ```

5. **Repeat for Place 2 (Reverse Routes)**:
   - For each route, also update the "Place 2" subcollection
   - Use the same coordinates but reverse the order

### 4. Testing

1. Create pre-bookings with coordinates
2. Log in as conductor
3. View map with real passenger locations
4. Test automatic passenger drop-off by moving near drop-off locations

## Key Benefits

1. **Accurate Tracking**: Real GPS coordinates instead of simulated locations
2. **Automatic Management**: Passenger count updates automatically
3. **Better User Experience**: Passengers can see exact pickup/dropoff locations
4. **Conductor Efficiency**: Real-time passenger location tracking

## Troubleshooting

### Common Issues:

1. **"fromLatitude and toLatitude are 0.0"**:

   - Solution: Add coordinates to your Firestore database as described above
   - Check that the `latitude` and `longitude` fields are numbers, not strings

2. **"setState() called during build"**:

   - Solution: Fixed in latest code update with proper subscription management

3. **"Passenger locations not showing on conductor map"**:
   - Solution: Ensure coordinates are added to Firestore
   - Check that bookings have `status: 'paid'` or `status: 'pending_payment'`

### Verification Steps:

1. **Check Firestore Data**:

   ```javascript
   // In Firebase Console, verify a place document has:
   {
     "Name": "SM City Lipa",
     "km": 0.0,
     "latitude": 13.9407,
     "longitude": 121.1529
   }
   ```

2. **Check Pre-Booking Data**:
   ```javascript
   // Verify a pre-booking document has:
   {
     "fromLatitude": 13.9407,
     "fromLongitude": 121.1529,
     "toLatitude": 13.7563,
     "toLongitude": 121.0583,
     "passengerLatitude": 13.9407,
     "passengerLongitude": 121.1529
   }
   ```

## Next Steps

After adding coordinates to your Firestore database:

1. Test the pre-booking flow
2. Verify passenger locations appear on conductor maps
3. Test automatic passenger drop-off functionality
4. Monitor the system for any remaining issues

The coordinate system is now fully implemented and ready for production use once the database is properly configured with coordinates.
