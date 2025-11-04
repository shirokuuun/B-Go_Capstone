# Geofencing Implementation for B-Go Bus App

## Overview

This implementation provides automatic passenger count decrementing when the conductor's bus reaches passenger drop-off locations. The system uses geofencing technology to detect when the bus is within 100 meters of a destination and automatically marks passengers as completed.

## Features

### 1. **Automatic Passenger Count Decrementing**

- When the conductor's bus reaches a passenger's destination, the passenger count automatically decreases
- Works for all ticket types: Pre-tickets, Pre-bookings, and Manual tickets
- Real-time updates to the conductor dashboard

### 2. **Dual Mode Geofencing**

- **Passenger Mode**: Monitors individual passenger locations for destination arrival
- **Conductor Mode**: Monitors conductor's bus location for passenger drop-offs

### 3. **Multiple Ticket Type Support**

- Pre-tickets (QR code based)
- Pre-bookings (reservation based)
- Manual tickets (conductor created)

## How It Works

### Geofencing Logic

1. **Location Monitoring**: Continuously tracks conductor's bus location
2. **Destination Detection**: Checks if bus is within 100m of any passenger destination
3. **Automatic Processing**: Marks tickets as completed and decrements passenger count
4. **Real-time Updates**: Updates Firestore database and conductor dashboard

### Data Flow

```
Bus Location → Geofencing Check → Destination Match →
Ticket Completion → Passenger Count Decrement → Dashboard Update
```

## Implementation Details

### Files Modified

1. **`lib/pages/passenger/services/geofencing_service.dart`**

   - Core geofencing logic
   - Dual mode support (passenger/conductor)
   - Automatic ticket completion
   - Passenger count management

2. **`lib/pages/conductor/conductor_dashboard.dart`**

   - Geofencing service integration
   - Test buttons for emulator
   - Real-time passenger count updates

3. **`lib/pages/passenger/services/pre_ticket.dart`**

   - Passenger geofencing integration
   - Automatic ticket accomplishment

4. **`lib/pages/passenger/services/pre_book.dart`**

   - Pre-booking geofencing integration
   - Location-based completion

5. **`lib/pages/conductor/ticketing/conductor_from.dart`**
   - Conductor geofencing integration
   - Test button for emulator

## Testing in Emulator

### 1. **Setup Requirements**

- Enable location services in emulator
- Grant location permissions to the app
- Have active tickets/bookings in the system

### 2. **Testing Steps**

#### **Step 1: Start Conductor Location Tracking**

1. Open Conductor Dashboard
2. Click "Start Tracking" button
3. Verify geofencing monitoring is active

#### **Step 2: Create Test Tickets**

1. Use Pre-ticketing to create tickets
2. Use Pre-booking to create reservations
3. Use Manual ticketing to create conductor tickets

#### **Step 3: Test Geofencing**

1. **Use Test Buttons** (Recommended for emulator):

   - Click "Test SM Lipa" button
   - Click "Test Batangas" button
   - Click "Test Rosario" button
   - Click "Test Current" button

2. **Manual Location Simulation**:
   - Use Android Studio's Extended Controls
   - Set location to destination coordinates
   - Watch passenger count decrement

### 3. **Test Button Locations**

#### **Conductor Dashboard**

- **Geofencing Test Card**: Appears when tracking is active
- **Test Buttons**:
  - Test SM Lipa (Blue)
  - Test Batangas (Green)
  - Test Rosario (Purple)
  - Test Current (Orange)

#### **Conductor Ticketing Page**

- **Orange Location Button**: Next to camera icon
- **Quick Test**: Simulates arrival at SM City Lipa

### 4. **Expected Results**

- Passenger count should decrease automatically
- Tickets should be marked as "completed"
- Dashboard should update in real-time
- Console logs should show geofencing activity

## Emulator Location Setup

### Using Android Studio Extended Controls

1. **Open Extended Controls**:

   - Click "..." button in emulator toolbar
   - Select "Extended controls"

2. **Location Tab**:

   - Click "Location" in left sidebar
   - Select "Routes" tab

3. **Set Test Routes**:

   - **SM City Lipa**: 13.940190, 121.122530
   - **Batangas City**: 13.7563, 121.0583
   - **Rosario**: 13.8476, 121.2039

4. **Enable GPS Signal**:

   - Toggle "Enable GPS signal" to ON
   - Set playback speed (e.g., "Speed 5X")

5. **Simulate Movement**:
   - Use "STOP ROUTE" button to pause
   - Use "Import GPX/KML" for custom routes
   - Manually set coordinates for testing

## Configuration

### Geofence Settings

```dart
static const double _geofenceRadius = 100.0; // 100 meters
static const Duration _checkInterval = Duration(seconds: 30);
```

### Location Settings

```dart
LocationSettings(
  accuracy: LocationAccuracy.high,
  distanceFilter: 10, // Update every 10 meters
)
```

## Troubleshooting

### Common Issues

1. **Geofencing Not Working**:

   - Check location permissions
   - Verify GPS is enabled in emulator
   - Check console logs for errors

2. **Passenger Count Not Updating**:

   - Ensure conductor is tracking location
   - Check if tickets are properly created
   - Verify destination coordinates exist

3. **Test Buttons Not Appearing**:
   - Start location tracking first
   - Check if conductor document exists
   - Verify route configuration

### Debug Information

The system provides detailed console logging:

- `🔍` - Geofencing checks
- `🎯` - Destination reached
- `✅` - Successful operations
- `❌` - Errors
- `ℹ️` - Information

## Best Practices

1. **Testing**:

   - Use test buttons for quick validation
   - Test with multiple ticket types
   - Verify passenger count accuracy

2. **Production**:

   - Monitor geofencing performance
   - Adjust radius based on real-world testing
   - Implement error handling for edge cases

3. **Maintenance**:
   - Regular testing of geofencing accuracy
   - Monitor system performance
   - Update destination coordinates as needed

## Future Enhancements

1. **Smart Geofencing**:

   - Dynamic radius based on speed
   - Route-aware geofencing
   - Predictive arrival times

2. **Advanced Analytics**:

   - Geofencing accuracy metrics
   - Performance monitoring
   - Usage statistics

3. **User Experience**:
   - Notifications for passengers
   - Real-time ETA updates
   - Route optimization

## Conclusion

This geofencing implementation provides a robust, automated system for managing passenger counts and ticket completion. The dual-mode approach ensures both passengers and conductors benefit from location-based automation, while the comprehensive testing tools make development and debugging efficient.

For questions or issues, check the console logs and use the test buttons to validate functionality.
