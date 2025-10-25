# Emulator Test Script for Geofencing

## Quick Test Sequence

### 1. **Setup Phase**

```
1. Open B-Go app in emulator
2. Login as conductor
3. Navigate to Conductor Dashboard
4. Ensure you have a route assigned
```

### 2. **Start Location Tracking**

```
1. Click "Start Tracking" button
2. Verify status shows "Location tracking is active"
3. Check console for "✅ Conductor geofencing monitoring started"
```

### 3. **Create Test Data**

```
1. Create Pre-ticket:
   - Go to Pre-ticketing
   - Select route and locations
   - Generate QR code
   - Save ticket

2. Create Pre-booking:
   - Go to Pre-booking
   - Select route and locations
   - Complete booking process

3. Create Manual Ticket:
   - Go to Conductor Ticketing
   - Create ticket with passenger
   - Verify passenger count increases
```

### 4. **Test Geofencing**

```
1. Use Test Buttons (Recommended):
   - Click "Test SM Lipa" button
   - Click "Test Batangas" button
   - Click "Test Rosario" button
   - Click "Test Current" button

2. Watch for:
   - Console logs showing geofencing activity
   - Passenger count decreasing
   - Tickets marked as completed
```

### 5. **Verify Results**

```
1. Check Conductor Dashboard:
   - Passenger count should decrease
   - Status updates should show

2. Check Console Logs:
   - 🎯 Destination reached messages
   - ✅ Ticket completion messages
   - Passenger count updates

3. Check Firestore:
   - Ticket status changes
   - Passenger count updates
```

## Expected Console Output

```
✅ Conductor geofencing monitoring started for route: Batangas
🔍 Checking conductor geofencing for route: Batangas
🎯 Conductor reached SM City Lipa: 2 passenger(s) dropped off (85.2m away)
✅ Conductor ticket ticket_1 marked as completed for 2 passenger(s)
✅ Total passengers dropped off: 2
✅ Conductor passenger count updated
```

## Troubleshooting Commands

### Test Current Location

```dart
await _geofencingService.testGeofencing();
```

### Simulate Specific Destination

```dart
await _geofencingService.simulateDestinationReached('SM City Lipa', 'Batangas');
```

### Check Geofencing Status

```dart
bool isActive = _geofencingService.isMonitoring;
bool isConductorMode = _geofencingService.isConductorMode;
```

## Common Test Scenarios

### Scenario 1: Single Passenger Drop-off

1. Create 1 passenger ticket
2. Test arrival at destination
3. Verify passenger count decreases by 1

### Scenario 2: Multiple Passenger Drop-off

1. Create 3 passenger ticket
2. Test arrival at destination
3. Verify passenger count decreases by 3

### Scenario 3: Mixed Ticket Types

1. Create pre-ticket, pre-booking, and manual ticket
2. Test arrival at destination
3. Verify all tickets are completed

### Scenario 4: Route Change

1. Change conductor route
2. Test geofencing with new route
3. Verify destination coordinates update

## Performance Testing

### Load Testing

1. Create 20+ passenger tickets
2. Test rapid destination arrivals
3. Monitor system performance

### Stress Testing

1. Create maximum capacity (27 passengers)
2. Test multiple drop-offs simultaneously
3. Verify accurate passenger counting

## Debug Mode

Enable debug logging by checking console for:

- `🔍` - Geofencing checks
- `🎯` - Destination reached
- `✅` - Successful operations
- `❌` - Errors
- `ℹ️` - Information

## Success Criteria

✅ **Geofencing activates automatically when tracking starts**
✅ **Passenger count decreases at destinations**
✅ **Tickets are marked as completed**
✅ **Real-time dashboard updates**
✅ **Console logging shows activity**
✅ **No memory leaks or performance issues**
✅ **Works with all ticket types**
✅ **Handles edge cases gracefully**
