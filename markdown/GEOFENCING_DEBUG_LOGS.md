# Geofencing Debug Logs Guide

## 📋 Overview

Comprehensive logging has been added to the geofencing system to help debug pre-booking drop-offs. This guide explains what logs to look for and what they mean.

## 🔍 How to View Logs

### Option 1: Android Studio / VS Code
1. Run the app in debug mode
2. Open the "Run" or "Debug Console" tab
3. Watch for emoji-prefixed log messages

### Option 2: Terminal
```bash
flutter run
# or
adb logcat | grep -E "(GEOFENCING|Pre-booking|scannedQRCode)"
```

## 📊 Log Sequence When Working Correctly

### 1. Geofencing Check (Every 5 seconds)
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 GEOFENCING CHECK SUMMARY:
   Pre-bookings active: 2
   Pre-tickets active: 0
   Manual tickets active: 0
   Passengers NEAR drop-off: 0
   Passengers READY for drop-off: 0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**What it means:**
- Lists all active tickets being tracked
- Shows how many are near/ready for drop-off

### 2. Distance Calculation (For each pre-booking)
```
📏 Distance to Mataas Na Lupa: 1523.4m (Pre-booking ID: abc123xyz)
```

**What it means:**
- Calculates distance from bus to drop-off location
- Shows pre-booking ID for tracking

### 3. Near Drop-off Alert (Within 250m)
```
⚠️ Pre-booking NEAR drop-off (≤250m)
```

**What it means:**
- Bus is within 250m of drop-off
- Banner will show on map
- NOT automatically dropping off yet

### 4. Ready for Drop-off (Within 100m)
```
🎯 Pre-booking READY for drop-off (≤100m)
🚨 AUTO-DROP-OFF WILL BE TRIGGERED FOR 1 PASSENGERS!
   - preBooking: Lipa Palengke → Mataas Na Lupa
🔄 Calling _processReadyPassengers...
```

**What it means:**
- Bus is within 100m of drop-off
- Automatic drop-off will be triggered
- System will update all collections

### 5. Drop-off Execution
```
🚨 GEOFENCING DROP-OFF TRIGGERED 🚨
📍 Passenger ID: abc123xyz
👤 User ID: user789
🎫 Ticket Type: preBooking
👥 Quantity: 3
🚏 Route: Lipa Palengke → Mataas Na Lupa
👫 Current passenger count BEFORE drop-off: 8
```

**What it means:**
- Drop-off process has started
- Shows all passenger details
- Shows current passenger count

### 6. Pre-booking Found
```
📱 Processing PRE-BOOKING drop-off...
✅ Pre-booking abc123xyz found in activeBookings, proceeding with drop-off
```

**What it means:**
- Confirmed pre-booking exists in active list
- Will proceed with drop-off

### 7. Passenger Count Decrement
```
➖ Decremented passenger count by 3
👫 New passenger count AFTER drop-off: 5
```

**What it means:**
- Passenger count reduced by booking quantity
- Shows new total count

### 8. Update Pre-booking Status
```
📝 Updating pre-booking status to "accomplished"...
🔄 _updatePreBookingStatus called for passenger: abc123xyz
   User ID: user789
   Target status: accomplished
🔍 Searching conductor preBookings collection...
📊 Query result: 1 documents found
✏️ Updating conductor preBooking document...
✅ Updated conductor pre-booking abc123xyz status to accomplished
```

**What it means:**
- Updating conductor's preBookings collection
- Shows if document was found and updated

### 9. Update Passenger Collection
```
👤 Updating passenger preBooking collection...
   Path: users/user789/preBookings/abc123xyz
✅ Updated passenger pre-booking abc123xyz status to accomplished
```

**What it means:**
- Updating passenger's preBookings collection
- This makes status visible to passenger

### 10. Update Remittance Ticket
```
💰 Updating remittance ticket status...
```

**What it means:**
- Updating conductor's remittance/tickets collection
- For financial tracking

### 11. Update ScannedQRCodes Collection
```
🔍 Updating scannedQRCodes collection status...
🔄 _updateScannedQRCodeStatus called for preBookingId: abc123xyz
   Target status: accomplished
👤 Current user UID: conductor123
🔍 Searching for conductor document...
✅ Conductor document found: cond456
🔍 Searching scannedQRCodes collection...
   Path: conductors/cond456/scannedQRCodes
   Query: WHERE bookingId == abc123xyz
📊 Query result: 1 documents found
📄 Found scannedQRCode document: qr789
   Current status: boarded
✏️ Updating scannedQRCode status to: accomplished
✅ Successfully updated scannedQRCode for abc123xyz to accomplished
```

**What it means:**
- Updating conductor's scannedQRCodes collection
- This updates the dashboard display
- Shows if the query found the correct document

### 12. Drop-off Complete
```
✅ Pre-booking drop-off complete for abc123xyz
─────────────────────────────────────────
```

**What it means:**
- All updates finished successfully
- Ready for next geofencing check

## ❌ Common Error Scenarios

### Error 1: Missing Coordinates
```
❌ Pre-booking abc123xyz missing coordinates (to: Mataas Na Lupa)
```

**What it means:**
- Pre-booking doesn't have toLatitude/toLongitude
- Geofencing cannot calculate distance
- **Fix:** Ensure coordinates are saved when booking is created

### Error 2: Pre-booking Already Removed
```
⚠️ Pre-booking abc123xyz already removed from activeBookings, skipping
```

**What it means:**
- Pre-booking was already processed
- Prevents duplicate drop-offs
- **This is normal** - not an error

### Error 3: No Conductor PreBooking Found
```
⚠️ No conductor preBooking found for abc123xyz
```

**What it means:**
- Pre-booking document doesn't exist in conductor's collection
- Status update will fail
- **Check:** Firebase console for document

### Error 4: No ScannedQRCode Found
```
❌ No scannedQRCode document found with bookingId: abc123xyz
   This means the QR code was not scanned or used a different ID
```

**What it means:**
- ScannedQRCodes collection doesn't have this booking ID
- Dashboard won't show "accomplished" status
- **Check:** Verify QR was scanned and bookingId field matches

### Error 5: Passenger Collection Update Failed
```
❌ Error updating passenger pre-booking: [error details]
```

**What it means:**
- Failed to update user's preBookings collection
- Passenger won't see "accomplished" status
- **Check:** User ID is correct and document exists

### Error 6: Empty User ID
```
⚠️ Skipping passenger update - userId is empty or disposed
```

**What it means:**
- User ID is missing from booking data
- Cannot update passenger's collection
- **Check:** Ensure userId is stored when QR is scanned

## 🧪 Testing Checklist

### Step-by-step Testing:

1. **Start Trip**
   - Watch for: Active bookings count
   ```
   📊 GEOFENCING CHECK SUMMARY:
      Pre-bookings active: 0
   ```

2. **Scan Pre-booking QR**
   - Watch for: Active count increase
   ```
   📊 GEOFENCING CHECK SUMMARY:
      Pre-bookings active: 1
   ```

3. **Drive Towards Drop-off**
   - Watch for: Distance decreasing
   ```
   📏 Distance to Mataas Na Lupa: 1523.4m
   📏 Distance to Mataas Na Lupa: 892.1m
   📏 Distance to Mataas Na Lupa: 437.6m
   ```

4. **Enter 250m Radius**
   - Watch for: Near drop-off alert
   ```
   ⚠️ Pre-booking NEAR drop-off (≤250m)
   Passengers NEAR drop-off: 1
   ```

5. **Enter 100m Radius**
   - Watch for: Ready for drop-off + trigger
   ```
   🎯 Pre-booking READY for drop-off (≤100m)
   🚨 AUTO-DROP-OFF WILL BE TRIGGERED FOR 1 PASSENGERS!
   ```

6. **Drop-off Execution**
   - Watch for: Full sequence of updates
   - All ✅ checkmarks should appear
   - Passenger count should decrease

7. **Verify UI Updates**
   - Conductor dashboard: Green "ACCOMPLISHED" badge
   - Trip page: Green "Accomplished" status
   - Passenger app: "ACCOMPLISHED" status

## 🔎 Key Logs to Watch For Issues

### Issue: Geofencing Not Triggering

**Look for:**
```
❌ Pre-booking abc123xyz missing coordinates (to: Mataas Na Lupa)
```
**Solution:** Check that toLatitude/toLongitude are stored in booking

### Issue: Passenger Count Not Decreasing

**Look for:**
```
⚠️ Pre-booking abc123xyz already removed from activeBookings, skipping
```
**Or missing:**
```
➖ Decremented passenger count by X
```
**Solution:** Check if pre-booking is in _activeBookings list

### Issue: Dashboard Not Showing "Accomplished"

**Look for:**
```
❌ No scannedQRCode document found with bookingId: abc123xyz
```
**Solution:**
1. Check scannedQRCodes collection has the document
2. Verify field name is 'bookingId' not 'documentId'
3. Ensure booking ID matches exactly

### Issue: Passenger Not Seeing "Accomplished"

**Look for:**
```
❌ Error updating passenger pre-booking: [error]
```
**Or:**
```
⚠️ Skipping passenger update - userId is empty or disposed
```
**Solution:**
1. Check userId is stored when QR is scanned
2. Verify users/{userId}/preBookings/{bookingId} exists
3. Check booking ID matches

## 📝 Log Symbols Reference

| Symbol | Meaning |
|--------|---------|
| 🚨 | Critical event (drop-off triggered) |
| 📍 | Location/Position data |
| 👤 | User/Passenger info |
| 🎫 | Ticket type |
| 👥 | Quantity/Count |
| 🚏 | Route information |
| 👫 | Passenger count |
| 📱 | Pre-booking processing |
| 📏 | Distance calculation |
| 🎯 | Ready for drop-off |
| ⚠️ | Warning (near drop-off) |
| ✅ | Success |
| ❌ | Error/Failure |
| 🔍 | Searching/Querying |
| ✏️ | Updating/Writing |
| 📊 | Summary/Statistics |
| 🔄 | Processing/Running |
| 💰 | Remittance/Financial |
| 📝 | Status update |
| ━━━ | Section separator |

## 🚀 Quick Debug Command

To filter only geofencing-related logs in terminal:
```bash
flutter run | grep -E "🚨|📏|🎯|⚠️|✅|❌|━━━"
```

## 💡 Tips

1. **Check distance logs** - If distance never reaches ≤100m, geofencing won't trigger
2. **Watch for missing coordinates** - Most common issue preventing geofencing
3. **Verify all ✅ checkmarks appear** - Each update should succeed
4. **Check passenger count logs** - Should decrement when drop-off occurs
5. **Look for userId warnings** - Passenger updates need valid userId
6. **Monitor scannedQRCodes query results** - Must find exactly 1 document

## 🔧 If Nothing Happens

If you see NO logs at all when approaching drop-off:

1. Check geofencing is enabled (timer running every 5 seconds)
2. Verify location permissions granted
3. Ensure GPS is enabled
4. Check _activeBookings has the pre-booking
5. Verify pre-booking status is "boarded" (not "paid")
