# Direction Validation Implementation

## Overview

This implementation prevents passengers from boarding when their pre-ticket route direction doesn't match the conductor's active trip direction. For example, if a conductor is on "SM Lipa to Rosario" trip, passengers with "Rosario to SM Lipa" tickets cannot board.

## Files Modified

### 1. `lib/services/direction_validation_service.dart` (NEW)

- **Purpose**: Centralized direction validation logic
- **Key Features**:
  - Maps passenger direction labels to conductor direction labels
  - Validates direction compatibility using place collections
  - Provides user-friendly error messages
  - Supports all routes: Batangas, Rosario, Mataas na Kahoy, Mataas Na Kahoy Palengke, Tiaong, San Juan

### 2. `lib/pages/passenger/services/pre_ticket.dart`

- **Changes**:
  - Added `direction` and `placeCollection` to QR data
  - Updated `_ReceiptModal` to accept direction parameters
  - Enhanced QR data structure for validation

### 3. `lib/pages/conductor/ticketing/conductor_from.dart`

- **Changes**:
  - Added direction validation before processing pre-tickets
  - Imported `DirectionValidationService`
  - Enhanced error messages for direction mismatches

### 4. `lib/pages/conductor/conductor_maps.dart`

- **Changes**:
  - Added direction validation in `storePreTicketToFirestore`
  - Imported `DirectionValidationService`
  - Enhanced error handling for direction conflicts

### 5. `lib/pages/conductor/conductor_departure.dart`

- **Changes**:
  - Added direction validation in `storePreTicketToFirestore`
  - Imported `DirectionValidationService`
  - Consistent error messaging across all conductor pages

## How It Works

### 1. Pre-Ticket Creation

When a passenger creates a pre-ticket:

```dart
final qrData = {
  'type': 'preTicket',
  'route': route,
  'direction': routeLabels[route]![directionIndex], // e.g., "SM Lipa to Rosario"
  'placeCollection': selectedPlaceCollection, // e.g., "Place" or "Place 2"
  // ... other data
};
```

### 2. Conductor Scanning

When a conductor scans a QR code:

1. **Route Validation**: Checks if conductor's route matches passenger's route
2. **Direction Validation**: Validates direction compatibility using place collections
3. **Error Handling**: Provides specific error messages for mismatches

### 3. Direction Mapping

The system maps passenger directions to conductor directions:

| Route    | Passenger Direction        | Conductor Direction            | Place Collection |
| -------- | -------------------------- | ------------------------------ | ---------------- |
| Rosario  | "SM Lipa to Rosario"       | "SM City Lipa - Rosario"       | "Place"          |
| Rosario  | "Rosario to SM Lipa"       | "Rosario - SM City Lipa"       | "Place 2"        |
| Batangas | "SM Lipa to Batangas City" | "SM City Lipa - Batangas City" | "Place"          |
| Batangas | "Batangas City to SM Lipa" | "Batangas City - SM City Lipa" | "Place 2"        |

## Error Messages

### Direction Mismatch

```
Direction mismatch! Your ticket is for "SM Lipa to Rosario" but the conductor is currently on "Rosario - SM City Lipa" trip. Please wait for the correct direction or contact the conductor.
```

### Route Mismatch

```
Route mismatch! Your ticket is for "Rosario" route but the conductor is assigned to "Batangas" route. Please find the correct conductor for your route.
```

## Test Scenarios

### ✅ VALID (Should Allow Boarding)

- **Conductor**: Rosario route, "SM City Lipa - Rosario" direction, Place collection
- **Passenger**: Rosario route, "SM Lipa to Rosario" direction, Place collection

### ❌ INVALID (Should Reject Boarding)

- **Conductor**: Rosario route, "SM City Lipa - Rosario" direction, Place collection
- **Passenger**: Rosario route, "Rosario to SM Lipa" direction, Place 2 collection

## Benefits

1. **Prevents Wrong Direction Boarding**: Passengers cannot board buses going in the opposite direction
2. **Clear Error Messages**: Users understand why they cannot board
3. **Consistent Validation**: Same logic across all conductor scanning interfaces
4. **Maintainable Code**: Centralized validation logic in a dedicated service
5. **Future-Proof**: Easy to add new routes or modify direction mappings

## Usage

The validation is automatically applied when:

- Conductors scan pre-ticket QR codes
- The system checks both route and direction compatibility
- Clear error messages are shown for any mismatches

No additional configuration is required - the validation works out of the box with the existing conductor and passenger workflows.
