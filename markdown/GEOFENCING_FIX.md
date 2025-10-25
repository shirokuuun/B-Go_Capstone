# Geofencing Pre-Booking Drop-off Fix

## Issues Identified

1. **Passenger count not decrementing for pre-bookings** (line 642-650 in conductor_maps.dart)
   - Current code explicitly skips decrementing passengerCount for pre-bookings
   - Comment says "Pre-bookings don't affect passenger count, they're counted separately"
   - This is incorrect - when pre-bookings are boarded, they SHOULD be counted

2. **Status not syncing to passenger's collection**
   - `_updatePreBookingStatus()` only updates conductor's collection
   - Doesn't update the passenger's `users/{userId}/preBookings/{bookingId}` document
   - This is why passengers don't see "accomplished" status

3. **Missing userId parameter**
   - `_updatePreBookingStatus()` is called without userId
   - Need userId to update passenger's collection

## Required Changes

### Change 1: Fix passenger count decrement (line 634-653)

**FIND:**
```dart
        // Update status and decrement count based on ticket type
        if (ticketType == 'preBooking') {
          // Check if already processed to prevent duplicates
          final existsInList = _activeBookings.any((b) => b['id'] == passengerId);
          if (!existsInList) {
            print('⚠️ Pre-booking $passengerId already removed, skipping');
            continue;
          }

          // Remove from active bookings (do NOT decrement passengerCount for pre-bookings)
          if (mounted && !_isDisposed) {
            setState(() {
              _activeBookings
                  .removeWhere((booking) => booking['id'] == passengerId);
              // Pre-bookings don't affect passenger count, they're counted separately
            });
          }
          _updatePreBookingStatus(passengerId, 'accomplished');
          // Update remittance ticket status
          _updateRemittanceTicketStatus(passengerId, 'accomplished');
```

**REPLACE WITH:**
```dart
        // Update status and decrement count based on ticket type
        if (ticketType == 'preBooking') {
          // Check if already processed to prevent duplicates
          final existsInList = _activeBookings.any((b) => b['id'] == passengerId);
          if (!existsInList) {
            print('⚠️ Pre-booking $passengerId already removed, skipping');
            continue;
          }

          // Remove from active bookings and decrement passengerCount
          if (mounted && !_isDisposed) {
            setState(() {
              _activeBookings
                  .removeWhere((booking) => booking['id'] == passengerId);
              // FIXED: Pre-bookings DO affect passenger count when boarded
              passengerCount = math.max(
                  0,
                  passengerCount -
                      (quantity is int ? quantity : (quantity as num).toInt()));
            });
          }
          _updatePreBookingStatus(passengerId, userId, 'accomplished');
          // Update remittance ticket status
          _updateRemittanceTicketStatus(passengerId, 'accomplished');
```

### Change 2: Update _updatePreBookingStatus method (line 705-734)

**FIND:**
```dart
  // Update the _updatePreBookingStatus method
  Future<void> _updatePreBookingStatus(
      String passengerId, String status) async {
    if (_isDisposed) return;

    try {
      final query = await FirebaseFirestore.instance
          .collectionGroup('preBookings')
          .where(FieldPath.documentId, isEqualTo: passengerId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty && !_isDisposed) {
        await query.docs.first.reference.update({
          'status': status,
          'dropOffTimestamp': FieldValue.serverTimestamp(),
          'dropOffLocation': _currentPosition != null
              ? {
                  'latitude': _currentPosition!.latitude,
                  'longitude': _currentPosition!.longitude,
                }
              : null,
        });
        print('Updated pre-booking $passengerId status to $status');
      }
    } catch (e) {
      print('Error updating pre-booking status: $e');
      // Don't crash the app, just log the error
    }
  }
```

**REPLACE WITH:**
```dart
  // Update the _updatePreBookingStatus method
  Future<void> _updatePreBookingStatus(
      String passengerId, String userId, String status) async {
    if (_isDisposed) return;

    try {
      // Update in conductor's preBookings collection
      final query = await FirebaseFirestore.instance
          .collectionGroup('preBookings')
          .where(FieldPath.documentId, isEqualTo: passengerId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty && !_isDisposed) {
        await query.docs.first.reference.update({
          'status': status,
          'dropOffTimestamp': FieldValue.serverTimestamp(),
          'dropOffLocation': _currentPosition != null
              ? {
                  'latitude': _currentPosition!.latitude,
                  'longitude': _currentPosition!.longitude,
                }
              : null,
        });
        print('Updated conductor pre-booking $passengerId status to $status');
      }

      // FIXED: Also update in passenger's collection
      if (userId.isNotEmpty && !_isDisposed) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('preBookings')
              .doc(passengerId)
              .update({
            'status': status,
            'dropOffTimestamp': FieldValue.serverTimestamp(),
            'dropOffLocation': _currentPosition != null
                ? {
                    'latitude': _currentPosition!.latitude,
                    'longitude': _currentPosition!.longitude,
                  }
                : null,
          });
          print('✅ Updated passenger pre-booking $passengerId status to $status');
        } catch (userUpdateError) {
          print('❌ Error updating passenger pre-booking: $userUpdateError');
          // Continue - conductor side was updated successfully
        }
      }
    } catch (e) {
      print('Error updating pre-booking status: $e');
      // Don't crash the app, just log the error
    }
  }
```

### Change 3: Update remittance ticket status method to also sync passenger doc (line 736-788)

**FIND:** (around line 759-783)
```dart
      if (ticketQuery.docs.isNotEmpty && !_isDisposed) {
        await ticketQuery.docs.first.reference.update({
          'status': status,
          'dropOffTimestamp': FieldValue.serverTimestamp(),
          'dropOffLocation': _currentPosition != null
              ? {
                  'latitude': _currentPosition!.latitude,
                  'longitude': _currentPosition!.longitude,
                }
              : null,
        });
        print('Updated remittance ticket for pre-booking $preBookingId to $status');
      }
    } catch (e) {
      print('Error updating remittance ticket status: $e');
      // Don't crash the app, just log the error
    }
  }
```

**REPLACE WITH:**
```dart
      if (ticketQuery.docs.isNotEmpty && !_isDisposed) {
        final ticketData = ticketQuery.docs.first.data();
        final userId = ticketData['userId'];

        await ticketQuery.docs.first.reference.update({
          'status': status,
          'dropOffTimestamp': FieldValue.serverTimestamp(),
          'dropOffLocation': _currentPosition != null
              ? {
                  'latitude': _currentPosition!.latitude,
                  'longitude': _currentPosition!.longitude,
                }
              : null,
        });
        print('Updated remittance ticket for pre-booking $preBookingId to $status');

        // FIXED: Also sync to passenger's collection
        if (userId != null && !_isDisposed) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('preBookings')
                .doc(preBookingId)
                .update({
              'status': status,
              'dropOffTimestamp': FieldValue.serverTimestamp(),
              'dropOffLocation': _currentPosition != null
                  ? {
                      'latitude': _currentPosition!.latitude,
                      'longitude': _currentPosition!.longitude,
                    }
                  : null,
            });
            print('✅ Synced status to passenger collection for $preBookingId');
          } catch (userSyncError) {
            print('⚠️ Failed to sync to passenger collection: $userSyncError');
          }
        }
      }
    } catch (e) {
      print('Error updating remittance ticket status: $e');
      // Don't crash the app, just log the error
    }
  }
```

## Summary

These changes will:
1. ✅ Decrement passenger count when pre-bookings are dropped off via geofencing
2. ✅ Update the passenger's pre-booking status to "accomplished" in their collection
3. ✅ Allow passengers to see "accomplished" status in their reservation confirmations
4. ✅ Maintain backward compatibility with existing pre-ticket and manual ticket logic

## Testing Steps

1. Create a pre-booking as a passenger
2. Pay for the pre-booking
3. Board the bus (conductor scans QR)
4. Verify passenger count increases
5. Conductor drives to drop-off location
6. Wait for geofencing to trigger (within 250m radius)
7. Check:
   - Passenger count decrements automatically
   - Conductor's trip page shows "Accomplished"
   - Passenger's reservation page shows "Accomplished"
   - Drop-off location and timestamp are recorded
