# Pre-Booking Remittance Implementation

## Overview

This implementation adds remittance tracking for pre-bookings, similar to how pre-tickets are handled. Pre-bookings will now be included in the conductor's daily remittance calculations and displayed in the conductor dashboard.

## Changes Made

### 1. Updated RemittanceService (`lib/pages/conductor/remittance_service.dart`)

- **Enhanced `calculateDailyRemittance()` method** to include pre-bookings from the remittance collection
- **Added pre-booking processing** alongside existing pre-ticket processing
- **Updated ticket count calculation** to include both tickets and pre-bookings
- **Maintained data structure consistency** with existing pre-ticket format

### 2. Updated Pre-Booking Service (`lib/pages/passenger/services/pre_book.dart`)

- **Enhanced `_saveToRemittance()` method** to save pre-bookings in the same format as pre-tickets
- **Updated `processTripEndForPreBookings()` method** to handle boarded pre-bookings properly
- **Added `_moveBoardedPreBookingToRemittance()` method** to move boarded pre-bookings to remittance collection
- **Improved data structure** to match the format shown in your database image

## Data Structure

Pre-bookings are now saved as documents in the `tickets/` subcollection under the remittance date document, with the same structure as pre-tickets:

**Remittance Date Document Structure:**

```
remittance/{date}/
├── createdAt: timestamp
├── lastUpdated: timestamp
├── summary: map (calculated summary)
├── dailyTripInfo: map (trip information)
└── tickets/ (subcollection for all tickets)
    ├── ticket 1 (pre-ticket)
    ├── ticket 2 (pre-booking)
    ├── ticket 3 (manual ticket)
    └── ...
```

**Pre-booking document structure in tickets subcollection:**

```json
{
  "active": true,
  "discountAmount": "0.00",
  "discountBreakdown": [
    "Passenger 1: Regular (No discount) — 15.00 PHP",
    "Passenger 2: Regular (No discount) — 15.00 PHP"
  ],
  "documentId": "94H614sg7Jf955pDX7Mz",
  "documentType": "preBooking",
  "endKm": 4,
  "farePerPassenger": ["15.00", "15.00"],
  "from": "SM City Lipa",
  "quantity": 2,
  "scannedBy": "c07VTkWDrUPP7pz4AgL9Ih4KjID3",
  "startKm": 0,
  "status": "boarded",
  "ticketType": "preBooking",
  "timestamp": "23 September 2025 at 22:05:00 UTC+8",
  "to": "San Adriano",
  "totalFare": "30.00",
  "totalKm": 4,
  "route": "Rosario",
  "direction": "SM City Lipa - Rosario",
  "conductorId": "conductor_id",
  "conductorName": "Conductor Name",
  "busNumber": "Bus Number",
  "tripId": "trip_id",
  "createdAt": "2025-09-01T14:26:45Z",
  "boardedAt": "2025-09-01T14:26:53Z",
  "scannedAt": "2025-09-01T14:26:53Z"
}
```

## How It Works

### 1. Pre-Booking Creation

- When a passenger creates a pre-booking, it's saved to the conductor's `preBookings` collection
- A copy is also saved to the `remittance/{date}/preBookings` collection for tracking

### 2. Pre-Booking Boarding

- When conductor scans a pre-booking QR code, the status is updated to "boarded"
- The pre-booking remains in the conductor's `preBookings` collection until trip ends

### 3. Trip End Processing

- When conductor ends a trip, boarded pre-bookings are moved to the remittance collection
- Cancelled pre-bookings (no-shows) are marked as cancelled and also moved to remittance
- The remittance summary is recalculated to include both pre-tickets and pre-bookings

### 4. Remittance Calculation

- The `RemittanceService.calculateDailyRemittance()` method now processes both:
  - `remittance/{date}/tickets` (pre-tickets and manual tickets)
  - `remittance/{date}/preBookings` (pre-bookings)
- Total passengers, total fare, and ticket count include both types

## Testing

### Test Scenarios

1. **Create Pre-Booking**

   - Create a pre-booking through the passenger app
   - Verify it appears in conductor's `preBookings` collection
   - Verify it appears in `remittance/{date}/preBookings` collection

2. **Board Pre-Booking**

   - Scan the pre-booking QR code as conductor
   - Verify status changes to "boarded"
   - Verify passenger count increases

3. **End Trip**

   - End the trip as conductor
   - Verify boarded pre-bookings are moved to remittance collection
   - Verify remittance summary includes pre-booking data

4. **View Remittance**
   - Check conductor dashboard remittance view
   - Verify pre-bookings appear in ticket details
   - Verify totals include pre-booking fares and passenger counts

### Expected Results

- Pre-bookings should appear in remittance calculations alongside pre-tickets
- Total passengers and fares should include both pre-tickets and pre-bookings
- Conductor dashboard should display all ticket types in the remittance view
- Data structure should match the format shown in your database image

## Files Modified

- `lib/pages/conductor/remittance_service.dart` - Enhanced remittance calculation
- `lib/pages/passenger/services/pre_book.dart` - Updated pre-booking handling
- `PRE_BOOKING_REMITTANCE_IMPLEMENTATION.md` - This documentation file

## Notes

- The implementation maintains backward compatibility with existing pre-ticket functionality
- All existing conductor dashboard features will continue to work as before
- Pre-bookings are now fully integrated into the remittance tracking system
- The data structure matches the format you provided in your database image
