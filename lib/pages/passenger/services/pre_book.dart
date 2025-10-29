import 'package:b_go/pages/passenger/services/pre_book_payment.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Added for Timer
import 'package:geolocator/geolocator.dart'; // Added for location tracking
import 'package:b_go/pages/passenger/services/passenger_location_service.dart';
import 'dart:convert'; // Added for JSON encoding
import 'package:responsive_framework/responsive_framework.dart';
import 'package:b_go/pages/passenger/services/geofencing_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class PreBook extends StatefulWidget {
  final Map<String, dynamic>? selectedConductor;
  const PreBook({super.key, this.selectedConductor});

  @override
  State<PreBook> createState() => _PreBookState();

// Static method to handle trip end processing for pre-bookings
  static Future<void> processTripEndForPreBookings(
      String conductorId, String date, String? tripId) async {
    try {
      print('🔄 PreBook: ========================================');
      print('🔄 PreBook: Processing trip end for pre-bookings');
      print('🔍 PreBook: Conductor ID: $conductorId');
      print('🔍 PreBook: Date: $date');
      print('🔍 PreBook: Trip ID: $tripId');

      // STEP 1: Get the current trip number from dailyTrips document
      final dailyTripsDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('dailyTrips')
          .doc(date)
          .get();

      if (!dailyTripsDoc.exists) {
        print('❌ PreBook: No dailyTrips document found for date $date');
        return;
      }

      final dailyTripData = dailyTripsDoc.data();
      final currentTrip = dailyTripData?['currentTrip'] ?? 1;
      final tripCollection = 'trip$currentTrip';

      print('📍 PreBook: Current trip number: $currentTrip');
      print('📍 PreBook: Trip collection: $tripCollection');
      print(
          '📍 PreBook: Looking in path: conductors/$conductorId/dailyTrips/$date/$tripCollection/preBookings/preBookings/');

      // STEP 2: Get all ACTIVE pre-bookings for this trip from dailyTrips
      final preBookingsRef = FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('dailyTrips')
          .doc(date)
          .collection(tripCollection)
          .doc('preBookings')
          .collection('preBookings');

      print('🔍 PreBook: Querying for active bookings...');

      QuerySnapshot preBookingsSnapshot =
          await preBookingsRef.where('active', isEqualTo: true).get();

      print(
          '🔄 PreBook: Found ${preBookingsSnapshot.docs.length} ACTIVE pre-bookings to process');

      if (preBookingsSnapshot.docs.isEmpty) {
        print('✅ PreBook: No active pre-bookings to process for this trip');
        return;
      }

      int accomplishedCount = 0;
      int cancelledCount = 0;
      int skippedCount = 0;

      // STEP 3: Process each booking
      for (var preBookingDoc in preBookingsSnapshot.docs) {
        final preBookingData = preBookingDoc.data() as Map<String, dynamic>;
        final preBookingId = preBookingData['preBookingId'] ?? preBookingDoc.id;
        final originalUserId = preBookingData['userId'] as String?;
        final currentStatus = preBookingData['status'] as String?;

        print('');
        print('📋 PreBook: ========================================');
        print('📋 PreBook: Processing booking ID: $preBookingId');
        print('📋 PreBook: Document ID: ${preBookingDoc.id}');
        print('📋 PreBook: Status: $currentStatus');
        print('📋 PreBook: User ID: $originalUserId');
        print('📋 PreBook: Active: ${preBookingData['active']}');
        print('📋 PreBook: Trip ID: ${preBookingData['tripId']}');

        // STEP 4: Check if accomplished by geofencing
        if (currentStatus == 'accomplished' ||
            preBookingData['dropOffTimestamp'] != null ||
            preBookingData['geofenceStatus'] == 'completed' ||
            preBookingData['tripCompleted'] == true) {
          print(
              '✅ PreBook: Booking is ACCOMPLISHED - preserving and copying to remittance');

          // Copy to remittance so it shows in trip pages
          try {
            print('📦 PreBook: Copying accomplished booking to remittance...');

            await FirebaseFirestore.instance
                .collection('conductors')
                .doc(conductorId)
                .collection('remittance')
                .doc(date)
                .collection('tickets')
                .doc(preBookingId)
                .set({
              'from': preBookingData['from'],
              'to': preBookingData['to'],
              'totalFare': preBookingData['totalFare'],
              'quantity': preBookingData['quantity'],
              'discountAmount': preBookingData['discountAmount'] ?? 0,
              'discountBreakdown': preBookingData['discountBreakdown'] ?? [],
              'farePerPassenger': preBookingData['farePerPassenger'] ?? [],
              'startKm': preBookingData['fromKm'] ?? 0,
              'endKm': preBookingData['toKm'] ?? 0,
              'timestamp': preBookingData['timestamp'],
              'status': 'accomplished',
              'ticketType': 'preBooking',
              'boardedAt': preBookingData['boardedAt'],
              'scannedBy': preBookingData['scannedBy'],
              'boardingStatus': preBookingData['boardingStatus'],
              'dropOffTimestamp': preBookingData['dropOffTimestamp'],
              'dropOffLocation': preBookingData['dropOffLocation'],
              'geofenceStatus': preBookingData['geofenceStatus'],
              'preBookingId': preBookingId,
              'userId': originalUserId,
              'tripId': preBookingData['tripId'],
              'paidAt': preBookingData['paidAt'],
              'route': preBookingData['route'],
              'direction': preBookingData['direction'],
            });

            print(
                '✅ PreBook: Successfully copied accomplished booking to remittance');
            print(
                '   Path: conductors/$conductorId/remittance/$date/tickets/$preBookingId');
          } catch (e) {
            print(
                '❌ PreBook: Error copying accomplished booking to remittance: $e');
          }

          accomplishedCount++;
          continue;
        }

        // Skip if already completed or cancelled
        if (currentStatus == 'completed' || currentStatus == 'cancelled') {
          print('⏭️ PreBook: SKIPPING - Already $currentStatus');
          skippedCount++;
          continue;
        }

        // Verify userId exists
        if (originalUserId == null || originalUserId.isEmpty) {
          print(
              '❌ PreBook: ERROR - userId is null or empty, cannot update passenger booking');
          print('📊 PreBook: Booking data: $preBookingData');
          skippedCount++;
          continue;
        }

        // STEP 5: Cancel bookings that are BOARDED but not dropped off
        // STEP 5: Mark boarded bookings as accomplished (they completed the trip!)
        if (currentStatus == 'boarded') {
          print(
              '✅ PreBook: ACCOMPLISHING - Passenger boarded (treating as completed)');

          // Update in dailyTrips collection
          try {
            print('🔄 PreBook: Updating dailyTrips booking...');
            await preBookingsRef.doc(preBookingDoc.id).update({
              'status': 'accomplished',
              'accomplishedAt': FieldValue.serverTimestamp(),
              'tripEnded': true,
              'active': false,
            });
            print('✅ PreBook: DailyTrips booking updated to accomplished');
          } catch (e) {
            print('❌ PreBook: Error updating dailyTrips booking: $e');
          }

          // Update passenger's booking
          try {
            print('🔄 PreBook: Updating passenger booking...');
            print('   Collection: users/$originalUserId/preBookings/');
            print('   Document: $preBookingId');

            await FirebaseFirestore.instance
                .collection('users')
                .doc(originalUserId)
                .collection('preBookings')
                .doc(preBookingId)
                .update({
              'status': 'accomplished',
              'accomplishedAt': FieldValue.serverTimestamp(),
              'tripEnded': true,
            });

            print('✅ PreBook: Passenger booking updated to accomplished!');
          } catch (e) {
            print('❌ PreBook: CRITICAL ERROR updating passenger booking: $e');
            print('   User ID: $originalUserId');
            print('   Booking ID: $preBookingId');
          }

          // Copy to remittance so it shows in trip pages
          try {
            print('📦 PreBook: Copying accomplished booking to remittance...');

            await FirebaseFirestore.instance
                .collection('conductors')
                .doc(conductorId)
                .collection('remittance')
                .doc(date)
                .collection('tickets')
                .doc(preBookingId)
                .set({
              'from': preBookingData['from'],
              'to': preBookingData['to'],
              'totalFare': preBookingData['totalFare'],
              'quantity': preBookingData['quantity'],
              'discountAmount': preBookingData['discountAmount'] ?? 0,
              'discountBreakdown': preBookingData['discountBreakdown'] ?? [],
              'farePerPassenger': preBookingData['farePerPassenger'] ?? [],
              'startKm': preBookingData['fromKm'] ?? 0,
              'endKm': preBookingData['toKm'] ?? 0,
              'timestamp': preBookingData['timestamp'],
              'status': 'accomplished',
              'ticketType': 'preBooking',
              'boardedAt': preBookingData['boardedAt'],
              'scannedBy': preBookingData['scannedBy'],
              'boardingStatus': 'accomplished',
              'preBookingId': preBookingId,
              'userId': originalUserId,
              'tripId': preBookingData['tripId'],
              'paidAt': preBookingData['paidAt'],
              'route': preBookingData['route'],
              'direction': preBookingData['direction'],
            }, SetOptions(merge: true));

            print(
                '✅ PreBook: Successfully copied accomplished booking to remittance');
          } catch (e) {
            print(
                '❌ PreBook: Error copying accomplished booking to remittance: $e');
          }

          accomplishedCount++;
        }
        // STEP 6: Cancel bookings that are PAID but never boarded (NO SHOW)
        else if (currentStatus == 'paid') {
          print('🚫 PreBook: CANCELLING - Paid but never boarded (NO SHOW)');

          // Update in dailyTrips collection
          try {
            print('🔄 PreBook: Updating dailyTrips booking...');
            await preBookingsRef.doc(preBookingDoc.id).update({
              'status': 'cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
              'cancelledReason': 'Trip ended - no show',
              'tripEnded': true,
              'active': false,
            });
            print('✅ PreBook: DailyTrips booking updated to cancelled');
          } catch (e) {
            print('❌ PreBook: Error updating dailyTrips booking: $e');
          }

          // Update passenger's booking
          try {
            print('🔄 PreBook: Updating passenger booking...');
            print('   Collection: users/$originalUserId/preBookings/');
            print('   Document: $preBookingId');

            final passengerBookingRef = FirebaseFirestore.instance
                .collection('users')
                .doc(originalUserId)
                .collection('preBookings')
                .doc(preBookingId);

            // Check if document exists first
            final docSnapshot = await passengerBookingRef.get();
            if (!docSnapshot.exists) {
              print('❌ PreBook: ERROR - Passenger booking document not found!');
              print('   Path: users/$originalUserId/preBookings/$preBookingId');
              cancelledCount++;
              continue;
            }

            print('📄 PreBook: Document exists, updating now...');

            await passengerBookingRef.update({
              'status': 'cancelled',
              'cancelledAt': FieldValue.serverTimestamp(),
              'cancelledReason': 'Trip ended - no show',
              'tripEnded': true,
            });

            print('✅ PreBook: Passenger booking updated to cancelled!');
            print('   ✓ status: cancelled');
            print('   ✓ tripEnded: true');
            print('   ✓ cancelledReason: Trip ended - no show');
          } catch (e) {
            print('❌ PreBook: CRITICAL ERROR updating passenger booking: $e');
            print('   User ID: $originalUserId');
            print('   Booking ID: $preBookingId');
          }

          cancelledCount++;
        } else {
          print('⚠️ PreBook: UNKNOWN STATUS - $currentStatus (not processing)');
          skippedCount++;
        }
      }

      print('');
      print('🎉 PreBook: ========================================');
      print('✅ PreBook: Trip end processing COMPLETE!');
      print(
          '   📊 Total bookings processed: ${preBookingsSnapshot.docs.length}');
      print(
          '   ✅ Accomplished (preserved & copied to remittance): $accomplishedCount');
      print('   🚫 Cancelled (no drop-off/no-show): $cancelledCount');
      print('   ⏭️  Skipped (already processed): $skippedCount');
      print('🎉 PreBook: ========================================');
    } catch (e, stackTrace) {
      print('❌ PreBook: FATAL ERROR processing trip end for pre-bookings!');
      print('❌ PreBook: Error: $e');
      print('📚 PreBook: Stack trace:');
      print(stackTrace);
      rethrow;
    }
  }

// Helper method to move boarded pre-booking to remittance collection
  static Future<void> _moveBoardedPreBookingToRemittance(String conductorId,
      String date, String preBookingId, Map<String, dynamic> preBookingData,
      {bool isCancelled = false}) async {
    try {
      // Get the next ticket number for this date
      final ticketNumber = await _getNextTicketNumberStatic(conductorId, date);
      final ticketDocId = 'ticket $ticketNumber';

      // Prepare remittance data in the same format as pre-tickets
      final remittanceData = {
        'active': false, // Set to false since trip ended
        'discountAmount': '0.00', // Default for pre-bookings
        'discountBreakdown': preBookingData['discountBreakdown'] ?? [],
        'documentId': preBookingId,
        'documentType': 'preBooking',
        'endKm': preBookingData['toKm'],
        'farePerPassenger': preBookingData['passengerFares'] ?? [],
        'from': preBookingData['from'],
        'quantity': preBookingData['quantity'],
        'scannedBy': preBookingData['scannedBy'] ?? conductorId,
        'startKm': preBookingData['fromKm'],
        'status': isCancelled ? 'cancelled' : 'boarded',
        'ticketType': 'preBooking',
        'timestamp': FieldValue.serverTimestamp(),
        'to': preBookingData['to'],
        'totalFare': preBookingData['totalFare'],
        'totalKm':
            (preBookingData['toKm'] as num) - (preBookingData['fromKm'] as num),
        // Additional fields for consistency
        'route': preBookingData['route'],
        'direction': preBookingData['direction'],
        'conductorId': conductorId,
        'conductorName': preBookingData['conductorName'],
        'busNumber': preBookingData['busNumber'],
        'tripId': preBookingData['tripId'],
        'createdAt': preBookingData['createdAt'],
        'boardedAt': preBookingData['boardedAt'],
        'scannedAt': preBookingData['scannedAt'],
        if (isCancelled) ...{
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledReason': 'Trip ended before drop-off',
          'tripEnded': true,
        },
      };

      // Save pre-booking data to tickets subcollection
      await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('remittance')
          .doc(date)
          .collection('tickets')
          .doc(ticketDocId)
          .set(remittanceData);

      // Update lastUpdated on date document
      await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('remittance')
          .doc(date)
          .set({
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Remove from active preBookings collection
      await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('preBookings')
          .doc(preBookingId)
          .delete();

      print(
          '✅ PreBook: Moved ${isCancelled ? 'cancelled' : 'boarded'} pre-booking $preBookingId to tickets subcollection as $ticketDocId');
    } catch (e) {
      print('❌ PreBook: Error moving boarded pre-booking to remittance: $e');
    }
  }

  // Static helper method to get next ticket number for a date
  static Future<int> _getNextTicketNumberStatic(
      String conductorId, String formattedDate) async {
    try {
      final ticketsSnapshot = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('remittance')
          .doc(formattedDate)
          .collection('tickets')
          .get();

      return ticketsSnapshot.docs.length + 1;
    } catch (e) {
      print('❌ PreBook: Error getting next ticket number: $e');
      return 1; // Default to 1 if error
    }
  }

  // Helper method to move pre-booking to trip end collections
  static Future<void> _movePreBookingToTripEndCollections(String conductorId,
      String date, String preBookingId, Map<String, dynamic> preBookingData,
      {bool isCancelled = false}) async {
    try {
      // Prepare ticket data for trip end collections
      final ticketData = {
        'from': preBookingData['from'],
        'to': preBookingData['to'],
        'fromKm': preBookingData['fromKm'],
        'toKm': preBookingData['toKm'],
        'totalKm': preBookingData['toKm'] - preBookingData['fromKm'],
        'timestamp': FieldValue.serverTimestamp(),
        'active': false, // Trip has ended
        'quantity': preBookingData['quantity'],
        'farePerPassenger': preBookingData['farePerPassenger'],
        'totalFare': preBookingData['totalFare'],
        'discountBreakdown': preBookingData['discountBreakdown'],
        'status': isCancelled ? 'cancelled' : preBookingData['status'],
        'ticketType': 'preBooking',
        'preBookingId': preBookingId,
        'userId': preBookingData['userId'],
        'conductorId': conductorId,
        'conductorName': preBookingData['conductorName'],
        'busNumber': preBookingData['busNumber'],
        'route': preBookingData['route'],
        'direction': preBookingData['direction'],
        'passengerLatitude': preBookingData['passengerLatitude'],
        'passengerLongitude': preBookingData['passengerLongitude'],
        'qrData': preBookingData['qrData'],
        'createdAt': preBookingData['createdAt'],
        'tripEndedAt': FieldValue.serverTimestamp(),
        if (isCancelled) ...{
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledReason': 'Trip ended - no show',
          'tripEnded': true,
        },
      };

      // Move to dailyTrips tickets collection
      await _moveToDailyTripsTickets(
          conductorId, date, preBookingId, ticketData);

      // Remove from active preBookings collection
      await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('preBookings')
          .doc(preBookingId)
          .delete();

      print(
          '✅ PreBook: Moved pre-booking $preBookingId to trip end collections');
    } catch (e) {
      print('❌ PreBook: Error moving pre-booking to trip end collections: $e');
    }
  }

  // Helper method to move pre-booking to dailyTrips tickets collection
  static Future<void> _moveToDailyTripsTickets(String conductorId, String date,
      String preBookingId, Map<String, dynamic> ticketData) async {
    try {
      final dailyTripDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('dailyTrips')
          .doc(date)
          .get();

      if (dailyTripDoc.exists) {
        final dailyTripData = dailyTripDoc.data();
        final currentTrip = dailyTripData?['currentTrip'] ?? 1;
        final tripCollection = 'trip$currentTrip';

        // Remove from dailyTrips preBookings collection
        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorId)
            .collection('dailyTrips')
            .doc(date)
            .collection(tripCollection)
            .doc('preBookings')
            .collection('preBookings')
            .doc(preBookingId)
            .delete();

        print('✅ PreBook: Moved pre-booking to dailyTrips tickets collection');
      }
    } catch (e) {
      print('❌ PreBook: Error moving to dailyTrips tickets: $e');
    }
  }
}

class _PreBookState extends State<PreBook> {
  final List<String> routeChoices = [
    'Batangas',
    'Rosario',
    'Mataas na Kahoy',
    'Mataas Na Kahoy Palengke',
    'Tiaong',
    'San Juan',
  ];

  // Map display names to Firestore document names
  final Map<String, String> _routeFirestoreNames = {
    'Batangas': 'Batangas',
    'Rosario': 'Rosario',
    'Mataas na Kahoy': 'Mataas na Kahoy',
    'Mataas Na Kahoy Palengke': 'Mataas Na Kahoy Palengke',
    'Tiaong': 'Tiaong',
    'San Juan': 'San Juan',
  };

  final Map<String, List<String>> routeLabels = {
    'Batangas': [
      'SM Lipa to Batangas City',
      'Batangas City to SM Lipa',
    ],
    'Rosario': [
      'SM Lipa to Rosario',
      'Rosario to SM Lipa',
    ],
    'Mataas na Kahoy': [
      'SM Lipa to Mataas na Kahoy',
      'Mataas na Kahoy to SM Lipa',
    ],
    'Mataas Na Kahoy Palengke': [
      'Lipa Palengke to Mataas na Kahoy',
      'Mataas na Kahoy to Lipa Palengke',
    ],
    'Tiaong': [
      'SM Lipa to Tiaong',
      'Tiaong to SM Lipa',
    ],
    'San Juan': [
      'SM Lipa to San Juan',
      'San Juan to SM Lipa',
    ],
  };

  String selectedRoute = 'Batangas';
  int directionIndex = 0; // 0: Place, 1: Place 2
  late Future<List<Map<String, dynamic>>> placesFuture;
  String? verifiedIDType;
  Position? _currentLocation; // Added for passenger location tracking
  final PassengerLocationService _locationService = PassengerLocationService();
  String selectedPlaceCollection = 'Place'; // Added for direction selection
  Map<String, dynamic>? selectedConductor; // Store selected conductor info

  @override
  void initState() {
    super.initState();

    // Initialize with selected conductor if available
    if (widget.selectedConductor != null) {
      selectedConductor = widget.selectedConductor;
      selectedRoute = selectedConductor!['route'] ?? 'Batangas';

      // Set direction based on conductor's active trip
      final activeTrip = selectedConductor!['activeTrip'];
      if (activeTrip != null) {
        // ✅ FIX: Use the placeCollection from activeTrip instead of isReturnTrip
        selectedPlaceCollection = activeTrip['placeCollection'] ?? 'Place';

        // Set directionIndex based on placeCollection
        directionIndex = selectedPlaceCollection == 'Place' ? 0 : 1;

        print('🔍 PreBook: Selected conductor active trip:');
        print('   - Direction: ${activeTrip['direction']}');
        print('   - PlaceCollection: $selectedPlaceCollection');
        print('   - DirectionIndex: $directionIndex');
      }
    }

    placesFuture = RouteService.fetchPlaces(
        _routeFirestoreNames[selectedRoute] ?? selectedRoute,
        placeCollection: selectedPlaceCollection);
    _fetchVerifiedIDType();
    // Delay location request slightly to ensure UI is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation(); // Get passenger's current location
    });
    // Start geofencing service for passenger monitoring
    GeofencingService().startMonitoring();
  }

  // Custom snackbar widget
  void _showCustomSnackBar(String message, String type) {
    Color backgroundColor;
    IconData icon;
    Color iconColor;

    switch (type) {
      case 'success':
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        iconColor = Colors.white;
        break;
      case 'error':
        backgroundColor = Colors.red;
        icon = Icons.error;
        iconColor = Colors.white;
        break;
      case 'warning':
        backgroundColor = Colors.orange;
        icon = Icons.warning;
        iconColor = Colors.white;
        break;
      default:
        backgroundColor = Colors.grey;
        icon = Icons.info;
        iconColor = Colors.white;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 12,
                color: backgroundColor,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.all(16),
        action: SnackBarAction(
          label: '✕',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<void> _fetchVerifiedIDType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('VerifyID')
          .doc('id')
          .get();
      if (doc.exists) {
        final data = doc.data();
        final status = data?['status'];
        final idType = data?['idType'];
        if (status == 'verified' && idType != null) {
          setState(() {
            verifiedIDType = idType;
          });
        }
      }
    } catch (e) {
      print('Error fetching verified ID type: $e');
    }
  }

  // Added method to get passenger's current location
  Future<void> _getCurrentLocation() async {
    print('🚀 PreBook: Starting location capture...');
    try {
      print(
          '🚀 PreBook: Calling PassengerLocationService.getCurrentLocation()...');

      // Try to get location with timeout
      final position =
          await _locationService.getCurrentLocation(context: context);

      if (position != null) {
        setState(() {
          _currentLocation = position;
        });
        print(
            '✅ PreBook: Passenger location captured successfully: ${position.latitude}, ${position.longitude}');

        // Show success message to user
        if (mounted) {
          _showCustomSnackBar(
              'Location captured: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
              'success');
        }
      } else {
        print('❌ PreBook: Failed to get passenger location - position is null');
        // Show error to user
        if (mounted) {
          _showCustomSnackBar(
              '❌ Failed to get your location. Please check your GPS settings and try again.',
              'error');
        }
      }
    } catch (e) {
      print('❌ PreBook: Error getting passenger location: $e');
      if (mounted) {
        _showCustomSnackBar('❌ Error getting location: $e', 'error');
      }
    }
  }

  void _onRouteChanged(String? newRoute) {
    if (newRoute != null && newRoute != selectedRoute) {
      setState(() {
        selectedRoute = newRoute;
        directionIndex = 0;
        selectedPlaceCollection = 'Place';
        // Use the Firestore route name instead of the display name
        String firestoreRouteName = _routeFirestoreNames[newRoute] ?? newRoute;
        placesFuture = RouteService.fetchPlaces(firestoreRouteName,
            placeCollection: selectedPlaceCollection);
      });
    }
  }

  void _toggleDirection() {
    setState(() {
      directionIndex = directionIndex == 0 ? 1 : 0;
      selectedPlaceCollection = directionIndex == 0 ? 'Place' : 'Place 2';
      // Use the Firestore route name instead of the display name
      String firestoreRouteName =
          _routeFirestoreNames[selectedRoute] ?? selectedRoute;
      placesFuture = RouteService.fetchPlaces(firestoreRouteName,
          placeCollection: selectedPlaceCollection);
    });
  }

  void _showToSelectionPage(Map<String, dynamic> fromPlace,
      List<Map<String, dynamic>> allPlaces) async {
    // Check if location is captured before proceeding
    if (_currentLocation == null) {
      _showCustomSnackBar(
          '⚠️ Location access required! Please enable location and try again.',
          'warning');
      return;
    }

    // Double-check location is valid
    if (_currentLocation!.latitude == 0.0 &&
        _currentLocation!.longitude == 0.0) {
      _showCustomSnackBar(
          '⚠️ Invalid location detected! Please try capturing location again.',
          'warning');
      return;
    }

    // Additional validation: check if coordinates are reasonable (not in the middle of the ocean)
    if (_currentLocation!.latitude < -90 ||
        _currentLocation!.latitude > 90 ||
        _currentLocation!.longitude < -180 ||
        _currentLocation!.longitude > 180) {
      _showCustomSnackBar(
          '⚠️ Invalid coordinates detected! Please try capturing location again.',
          'warning');
      return;
    }

    print(
        '✅ PreBook: Location verified before proceeding: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');

    int fromIndex = allPlaces.indexOf(fromPlace);
    List<Map<String, dynamic>> toPlaces = allPlaces.sublist(fromIndex + 1);
    if (toPlaces.isEmpty) {
      _showCustomSnackBar(
          'No valid drop-off locations after selected pick-up.', 'warning');
      return;
    }
    final toPlace = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => _ToSelectionPage(
          toPlaces: toPlaces,
          directionLabel: routeLabels[selectedRoute]![directionIndex],
        ),
      ),
    );
    if (toPlace != null) {
      _showQuantityModal(fromPlace, toPlace);
    }
  }

  void _showQuantityModal(
      Map<String, dynamic> fromPlace, Map<String, dynamic> toPlace) async {
    int? quantity = await showDialog<int>(
      context: context,
      builder: (context) => _QuantitySelectionModal(),
    );
    if (quantity != null && quantity > 0) {
      _showFareTypeModal(fromPlace, toPlace, quantity);
    }
  }

  void _showFareTypeModal(Map<String, dynamic> fromPlace,
      Map<String, dynamic> toPlace, int quantity) async {
    List<String>? fareTypes = await showDialog<List<String>>(
      context: context,
      builder: (context) => _FareTypeSelectionModal(
        quantity: quantity,
        verifiedIDType: verifiedIDType,
      ),
    );
    if (fareTypes != null) {
      _showConfirmationModal(fromPlace, toPlace, quantity, fareTypes);
    }
  }

  void _showConfirmationModal(
      Map<String, dynamic> fromPlace,
      Map<String, dynamic> toPlace,
      int quantity,
      List<String> fareTypes) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmationModal(),
    );
    if (confirmed == true) {
      _showReceiptModal(fromPlace, toPlace, quantity, fareTypes);
    }
  }

  void _showReceiptModal(
      Map<String, dynamic> fromPlace,
      Map<String, dynamic> toPlace,
      int quantity,
      List<String> fareTypes) async {
    await showDialog(
      context: context,
      builder: (context) => _ReceiptModal(
        route: selectedRoute,
        directionLabel: routeLabels[selectedRoute]![directionIndex],
        fromPlace: fromPlace,
        toPlace: toPlace,
        quantity: quantity,
        fareTypes: fareTypes,
        currentLocation: _currentLocation, // Pass the location directly
        selectedConductor: selectedConductor, // Pass conductor info
        selectedPlaceCollection: selectedPlaceCollection,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    // Get screen dimensions for better responsive calculations
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive sizing with better screen size adaptation
    final titleFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final routeFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final dropdownFontSize = isMobile
        ? 12.0
        : isTablet
            ? 14.0
            : 16.0;
    final locationTitleFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final locationStatusFontSize = isMobile
        ? 11.0
        : isTablet
            ? 13.0
            : 15.0;
    final locationCoordFontSize = isMobile
        ? 9.0
        : isTablet
            ? 11.0
            : 13.0;
    final buttonFontSize = isMobile
        ? 14.0
        : isTablet
            ? 16.0
            : 18.0;

    // Responsive heights based on screen size
    final expandedHeight = isMobile
        ? (screenHeight * 0.18)
        : isTablet
            ? (screenHeight * 0.20)
            : (screenHeight * 0.22);
    final topPadding = isMobile
        ? (screenHeight * 0.06)
        : isTablet
            ? (screenHeight * 0.07)
            : (screenHeight * 0.08);

    // Responsive padding that scales with screen size
    final horizontalPadding = isMobile
        ? (screenWidth * 0.04)
        : isTablet
            ? (screenWidth * 0.05)
            : (screenWidth * 0.06);
    final verticalPadding = isMobile
        ? (screenHeight * 0.01)
        : isTablet
            ? (screenHeight * 0.012)
            : (screenHeight * 0.015);
    final containerPadding = isMobile
        ? (screenWidth * 0.04)
        : isTablet
            ? (screenWidth * 0.05)
            : (screenWidth * 0.06);
    final cardPadding = isMobile
        ? (screenWidth * 0.04)
        : isTablet
            ? (screenWidth * 0.05)
            : (screenWidth * 0.06);
    final locationPadding = isMobile
        ? (screenWidth * 0.03)
        : isTablet
            ? (screenWidth * 0.035)
            : (screenWidth * 0.04);

    // Responsive button sizing
    final buttonHeight = isMobile
        ? (screenHeight * 0.01)
        : isTablet
            ? (screenHeight * 0.012)
            : (screenHeight * 0.015);
    final iconSize = isMobile
        ? 18.0
        : isTablet
            ? 22.0
            : 26.0;
    final smallIconSize = isMobile
        ? 14.0
        : isTablet
            ? 18.0
            : 22.0;

    // Responsive grid configuration
    final gridCrossAxisCount = isMobile
        ? 2
        : isTablet
            ? 3
            : 4;
    final gridSpacing = isMobile
        ? (screenWidth * 0.02)
        : isTablet
            ? (screenWidth * 0.025)
            : (screenWidth * 0.03);
    final gridAspectRatio = isMobile
        ? 2.5
        : isTablet
            ? 3.0
            : 3.5;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF007A8F),
            expandedHeight: expandedHeight,
            flexibleSpace: FlexibleSpaceBar(
              background: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: topPadding),
                    child: Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Pre-Booking',
                            style: GoogleFonts.outfit(
                                fontSize: titleFontSize, color: Colors.white),
                          ),
                        ),
                        if (selectedConductor == null)
                          Padding(
                            padding: EdgeInsets.only(right: 10.0),
                            child: DropdownButton<String>(
                              value: selectedRoute,
                              dropdownColor: const Color(0xFF007A8F),
                              style: GoogleFonts.outfit(
                                  fontSize: dropdownFontSize,
                                  color: Colors.white),
                              iconEnabledColor: Colors.white,
                              underline: Container(),
                              items: routeChoices
                                  .map((route) => DropdownMenuItem(
                                        value: route,
                                        child: Text(routeLabels[route]![0],
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ))
                                  .toList(),
                              onChanged: _onRouteChanged,
                            ),
                          )
                        else
                          Padding(
                            padding: EdgeInsets.only(right: 10.0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.directions_bus,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Bus #${selectedConductor!['busNumber'] ?? 'N/A'}',
                                  style: GoogleFonts.outfit(
                                    fontSize: dropdownFontSize,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding),
                    child: GestureDetector(
                      onTap:
                          selectedConductor == null ? _toggleDirection : null,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: containerPadding,
                            vertical: verticalPadding),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007A8F),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.swap_horiz, color: Colors.white),
                            SizedBox(width: isMobile ? 12 : 16),
                            Expanded(
                              child: Text(
                                selectedConductor != null
                                    ? (selectedConductor!['activeTrip']
                                            ?['direction'] ??
                                        routeLabels[selectedRoute]![
                                            directionIndex])
                                    : routeLabels[selectedRoute]![
                                        directionIndex],
                                style: GoogleFonts.outfit(
                                    fontSize: routeFontSize,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.only(
                top: isMobile ? (screenHeight * 0.02) : (screenHeight * 0.025)),
          ),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: EdgeInsets.only(top: screenHeight * 0.02),
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                    horizontal: cardPadding, vertical: cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: isMobile ? 10 : 12),
                      child: Text(
                        "Select Location:",
                        style: GoogleFonts.outfit(
                            fontSize: locationTitleFontSize,
                            color: Colors.black87),
                      ),
                    ),
                    // Location status indicator with responsive sizing
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 10 : 12,
                          vertical: isMobile
                              ? (screenHeight * 0.01)
                              : (screenHeight * 0.012)),
                      child: Container(
                        padding: EdgeInsets.all(locationPadding),
                        decoration: BoxDecoration(
                          color: _currentLocation != null
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _currentLocation != null
                                ? Colors.green
                                : Colors.orange,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _currentLocation != null
                                      ? Icons.location_on
                                      : Icons.location_off,
                                  color: _currentLocation != null
                                      ? Colors.green
                                      : Colors.orange,
                                  size: iconSize,
                                ),
                                SizedBox(width: isMobile ? 8 : 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentLocation != null
                                            ? 'Location captured successfully!'
                                            : 'Location access needed for conductor to find you',
                                        style: GoogleFonts.outfit(
                                          fontSize: locationStatusFontSize,
                                          fontWeight: FontWeight.w600,
                                          color: _currentLocation != null
                                              ? Colors.green.shade700
                                              : Colors.orange.shade700,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (_currentLocation != null) ...[
                                        SizedBox(height: isMobile ? 2 : 4),
                                        Text(
                                          'Lat: ${_currentLocation!.latitude.toStringAsFixed(6)}',
                                          style: GoogleFonts.outfit(
                                            fontSize: locationCoordFontSize,
                                            color: Colors.green.shade600,
                                          ),
                                        ),
                                        Text(
                                          'Lng: ${_currentLocation!.longitude.toStringAsFixed(6)}',
                                          style: GoogleFonts.outfit(
                                            fontSize: locationCoordFontSize,
                                            color: Colors.green.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (_currentLocation == null)
                                  IconButton(
                                    icon: Icon(Icons.refresh,
                                        size: smallIconSize),
                                    onPressed: () {
                                      _getCurrentLocation();
                                      _showCustomSnackBar(
                                          'Requesting location access...',
                                          'info');
                                    },
                                    color: Colors.orange,
                                  ),
                              ],
                            ),
                            if (_currentLocation == null) ...[
                              SizedBox(
                                  height: isMobile
                                      ? (screenHeight * 0.01)
                                      : (screenHeight * 0.012)),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _getCurrentLocation();
                                    _showCustomSnackBar(
                                        'Requesting location access...',
                                        'info');
                                  },
                                  icon: Icon(Icons.location_on,
                                      size: smallIconSize),
                                  label: Text('Enable Location Access',
                                      style:
                                          TextStyle(fontSize: buttonFontSize)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                        vertical: buttonHeight),
                                  ),
                                ),
                              ),
                            ],
                            // Debug button to show current location
                            if (_currentLocation != null) ...[
                              SizedBox(
                                  height: isMobile
                                      ? (screenHeight * 0.01)
                                      : (screenHeight * 0.012)),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _showCustomSnackBar(
                                        'Location: ${_currentLocation!.latitude.toStringAsFixed(6)}, ${_currentLocation!.longitude.toStringAsFixed(6)}',
                                        'info');
                                  },
                                  icon: Icon(Icons.info, size: smallIconSize),
                                  label: Text('Show Location Details',
                                      style:
                                          TextStyle(fontSize: buttonFontSize)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                        vertical: buttonHeight),
                                  ),
                                ),
                              ),
                            ],
                            // Debug button to test location capture
                            SizedBox(
                                height: isMobile
                                    ? (screenHeight * 0.01)
                                    : (screenHeight * 0.012)),
                          ],
                        ),
                      ),
                    ),
                    // Conductor information section
                    if (selectedConductor != null) ...[
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 10 : 12,
                            vertical: isMobile
                                ? (screenHeight * 0.01)
                                : (screenHeight * 0.012)),
                        child: Container(
                          padding: EdgeInsets.all(locationPadding),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.blue,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.directions_bus,
                                    color: Colors.blue,
                                    size: iconSize,
                                  ),
                                  SizedBox(width: isMobile ? 8 : 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Selected Bus: ${selectedConductor!['name'] ?? 'Unknown Conductor'}',
                                          style: GoogleFonts.outfit(
                                            fontSize: locationStatusFontSize,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade700,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: isMobile ? 2 : 4),
                                        Text(
                                          'Bus #${selectedConductor!['busNumber'] ?? 'N/A'} • ${selectedConductor!['passengerCount'] ?? 0} passengers',
                                          style: GoogleFonts.outfit(
                                            fontSize: locationCoordFontSize,
                                            color: Colors.blue.shade600,
                                          ),
                                        ),
                                        if (selectedConductor!['activeTrip']
                                                ?['direction'] !=
                                            null) ...[
                                          SizedBox(height: isMobile ? 2 : 4),
                                          Text(
                                            'Route: ${selectedConductor!['activeTrip']['direction']}',
                                            style: GoogleFonts.outfit(
                                              fontSize: locationCoordFontSize,
                                              color: Colors.blue.shade600,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Online',
                                      style: GoogleFonts.outfit(
                                        fontSize: locationCoordFontSize - 1,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: placesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(child: Text('No places found.'));
                        }
                        final myList = snapshot.data!;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridCrossAxisCount,
                            mainAxisSpacing: gridSpacing,
                            crossAxisSpacing: gridSpacing,
                            childAspectRatio: gridAspectRatio,
                          ),
                          itemCount: myList.length,
                          itemBuilder: (context, index) {
                            final item = myList[index];
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0091AD),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(
                                    vertical: isMobile
                                        ? (screenHeight * 0.01)
                                        : (screenHeight * 0.012),
                                    horizontal: isMobile
                                        ? (screenWidth * 0.015)
                                        : (screenWidth * 0.02)),
                              ),
                              onPressed: () =>
                                  _showToSelectionPage(item, myList),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item['name'] ?? '',
                                    style: GoogleFonts.outfit(
                                        fontSize: isMobile ? 12 : 14,
                                        color: Colors.white),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (item['km'] != null) ...[
                                    SizedBox(height: isMobile ? 2 : 4),
                                    Text(
                                      '${(item['km'] as num).toInt()} km',
                                      style: TextStyle(
                                          fontSize: isMobile ? 10 : 12,
                                          color: Colors.white70),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToSelectionPage extends StatelessWidget {
  final List<Map<String, dynamic>> toPlaces;
  final String directionLabel;
  const _ToSelectionPage(
      {Key? key, required this.toPlaces, required this.directionLabel})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    // Get screen dimensions for better responsive calculations
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive sizing with better screen size adaptation
    final titleFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final routeFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final locationTitleFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;

    // Responsive heights based on screen size
    final expandedHeight = isMobile
        ? (screenHeight * 0.18)
        : isTablet
            ? (screenHeight * 0.20)
            : (screenHeight * 0.22);
    final topPadding = isMobile
        ? (screenHeight * 0.06)
        : isTablet
            ? (screenHeight * 0.07)
            : (screenHeight * 0.08);

    // Responsive padding that scales with screen size
    final horizontalPadding = isMobile
        ? (screenWidth * 0.04)
        : isTablet
            ? (screenWidth * 0.05)
            : (screenWidth * 0.06);
    final verticalPadding = isMobile
        ? (screenHeight * 0.01)
        : isTablet
            ? (screenHeight * 0.012)
            : (screenHeight * 0.015);
    final containerPadding = isMobile
        ? (screenWidth * 0.04)
        : isTablet
            ? (screenWidth * 0.05)
            : (screenWidth * 0.06);
    final cardPadding = isMobile
        ? (screenWidth * 0.04)
        : isTablet
            ? (screenWidth * 0.05)
            : (screenWidth * 0.06);

    // Responsive grid configuration
    final gridCrossAxisCount = isMobile
        ? 2
        : isTablet
            ? 3
            : 4;
    final gridSpacing = isMobile
        ? (screenWidth * 0.02)
        : isTablet
            ? (screenWidth * 0.025)
            : (screenWidth * 0.03);
    final gridAspectRatio = isMobile
        ? 2.5
        : isTablet
            ? 3.0
            : 3.5;

    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF007A8F),
            expandedHeight: expandedHeight,
            flexibleSpace: FlexibleSpaceBar(
              background: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: topPadding),
                    child: Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Drop-off',
                            style: GoogleFonts.outfit(
                              fontSize: titleFontSize,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // No dropdown here
                      ],
                    ),
                  ),
                  // Non-clickable direction label
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: containerPadding,
                          vertical: verticalPadding),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007A8F),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: isMobile ? 12 : 16),
                          Expanded(
                            child: Text(
                              directionLabel,
                              style: GoogleFonts.outfit(
                                fontSize: routeFontSize,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: EdgeInsets.only(
                    top: size.height * 0.02, bottom: size.height * 0.08),
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                    horizontal: cardPadding, vertical: cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: isMobile ? 10 : 12),
                      child: Text(
                        "Select Your Drop-off:",
                        style: GoogleFonts.outfit(
                          fontSize: locationTitleFontSize,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridCrossAxisCount,
                        mainAxisSpacing: gridSpacing,
                        crossAxisSpacing: gridSpacing,
                        childAspectRatio: gridAspectRatio,
                      ),
                      itemCount: toPlaces.length,
                      itemBuilder: (context, index) {
                        final place = toPlaces[index];
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0091AD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(
                                vertical: isMobile
                                    ? (screenHeight * 0.01)
                                    : (screenHeight * 0.012),
                                horizontal: isMobile
                                    ? (screenWidth * 0.015)
                                    : (screenWidth * 0.02)),
                          ),
                          onPressed: () => Navigator.of(context).pop(place),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                place['name'] ?? '',
                                style: GoogleFonts.outfit(
                                    fontSize: isMobile ? 12 : 14,
                                    color: Colors.white),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (place['km'] != null) ...[
                                SizedBox(height: isMobile ? 2 : 4),
                                Text(
                                  '${(place['km'] as num).toInt()} km',
                                  style: TextStyle(
                                      fontSize: isMobile ? 10 : 12,
                                      color: Colors.white70),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Quantity, FareType, Confirmation, and Receipt modals are similar to PreTicket, but receipt saves to preBookings
class _QuantitySelectionModal extends StatefulWidget {
  @override
  State<_QuantitySelectionModal> createState() =>
      _QuantitySelectionModalState();
}

class _QuantitySelectionModalState extends State<_QuantitySelectionModal> {
  int quantity = 1;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select Quantity', style: GoogleFonts.outfit(fontSize: 20)),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.remove),
            onPressed: quantity > 1 ? () => setState(() => quantity--) : null,
          ),
          Text('$quantity', style: GoogleFonts.outfit(fontSize: 20)),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => setState(() => quantity++),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 14)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF0091AD),
          ),
          onPressed: () => Navigator.of(context).pop(quantity),
          child: Text('Confirm',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14)),
        ),
      ],
    );
  }
}

class _FareTypeSelectionModal extends StatefulWidget {
  final int quantity;
  final String? verifiedIDType;
  const _FareTypeSelectionModal({required this.quantity, this.verifiedIDType});
  @override
  State<_FareTypeSelectionModal> createState() =>
      _FareTypeSelectionModalState();
}

class _FareTypeSelectionModalState extends State<_FareTypeSelectionModal> {
  final List<String> fareTypes = ['Regular', 'Student', 'PWD', 'Senior'];
  late List<String> selectedTypes;

  @override
  void initState() {
    super.initState();
    selectedTypes = List.generate(widget.quantity, (index) => 'Regular');
    if (widget.verifiedIDType != null && widget.quantity > 0) {
      String autoFareType = _mapIDTypeToFareType(widget.verifiedIDType!);
      selectedTypes[0] = autoFareType;
    }
  }

  String _mapIDTypeToFareType(String idType) {
    switch (idType.toLowerCase()) {
      case 'student':
        return 'Student';
      case 'senior citizen':
        return 'Senior';
      case 'pwd':
        return 'PWD';
      default:
        return 'Regular';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign Fare Type:', style: GoogleFonts.outfit(fontSize: 20)),
      content: SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.verifiedIDType != null) ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Text(
                    'First passenger automatically set to ${_mapIDTypeToFareType(widget.verifiedIDType!)} based on your verified ID',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: Colors.green[700]),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 12),
              ],
              for (int i = 0; i < widget.quantity; i++)
                Row(
                  children: [
                    Text('Passenger ${i + 1}:',
                        style: GoogleFonts.outfit(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    SizedBox(width: 10),
                    DropdownButton<String>(
                      value: selectedTypes[i],
                      items: fareTypes
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type,
                                    style: GoogleFonts.outfit(fontSize: 14)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedTypes[i] = val!;
                        });
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600])),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF0091AD),
          ),
          onPressed: () => Navigator.of(context).pop(selectedTypes),
          child: Text('Confirm',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white)),
        ),
      ],
    );
  }
}

class _ConfirmationModal extends StatefulWidget {
  @override
  State<_ConfirmationModal> createState() => _ConfirmationModalState();
}

class _ConfirmationModalState extends State<_ConfirmationModal> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Are you sure with the Pre-Booking?',
          style: GoogleFonts.outfit(fontSize: 20)),
      content: Text('Do you wish to proceed?',
          style: GoogleFonts.outfit(fontSize: 14)),
      actions: [
        TextButton(
          onPressed:
              _isProcessing ? null : () => Navigator.of(context).pop(false),
          child: Text('Cancel',
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: _isProcessing ? Colors.grey[400] : Colors.grey[600])),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _isProcessing ? Colors.grey : Color(0xFF0091AD),
          ),
          onPressed: _isProcessing
              ? null
              : () async {
                  // Prevent multiple clicks
                  setState(() {
                    _isProcessing = true;
                  });

                  // Small delay to prevent accidental double-tap
                  await Future.delayed(Duration(milliseconds: 300));

                  if (mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
          child: _isProcessing
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('Yes',
                  style: GoogleFonts.outfit(fontSize: 14, color: Colors.white)),
        ),
      ],
    );
  }
}

class _ReceiptModal extends StatefulWidget {
  final String route;
  final String directionLabel;
  final Map<String, dynamic> fromPlace;
  final Map<String, dynamic> toPlace;
  final int quantity;
  final List<String> fareTypes;
  final Position? currentLocation;
  final Map<String, dynamic>? selectedConductor;
  final String selectedPlaceCollection;

  _ReceiptModal({
    required this.route,
    required this.directionLabel,
    required this.fromPlace,
    required this.toPlace,
    required this.quantity,
    required this.fareTypes,
    this.currentLocation,
    this.selectedConductor,
    required this.selectedPlaceCollection,
  });

  @override
  State<_ReceiptModal> createState() => _ReceiptModalState();
}

class _ReceiptModalState extends State<_ReceiptModal> {
  bool _isSaving = false;

  // Calculate full trip fare for pre-booking
  double computeFullTripFare(String route) {
    Map<String, double> routeEndDistances = {
      'Batangas': 28.0,
      'Rosario': 14.0,
      'Mataas na Kahoy': 8.0,
      'Mataas na Kahoy Lipa Palengke': 8.0,
      'Tiaong': 30.0,
      'San Juan': 37.0,
    };

    final totalKm = routeEndDistances[route] ?? 14.0;
    double fare = 15.0;
    if (totalKm > 4) {
      fare += (totalKm - 4) * 2.20;
    }
    return fare;
  }

  Future<String?> savePreBooking(
      BuildContext context,
      double baseFare,
      double totalAmount,
      List<String> discountBreakdown,
      List<double> passengerFares) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final now = DateTime.now();

    Position? passengerLocation = widget.currentLocation;

    if (passengerLocation == null) {
      print('⚠️ PreBook: No location found in modal, trying to get location again...');
      try {
        final locationService = PassengerLocationService();
        passengerLocation = await locationService.getCurrentLocation(context: context);
        if (passengerLocation != null) {
          print('✅ PreBook: Successfully captured location on retry');
        } else {
          print('❌ PreBook: Failed to get location on retry');
        }
      } catch (e) {
        print('❌ PreBook: Error getting location on retry: $e');
      }
    }

    print('💾 PreBook: Saving booking with passenger location: ${passengerLocation?.latitude}, ${passengerLocation?.longitude}');

    final actualDirection = widget.selectedConductor?['activeTrip']?['direction'] ?? widget.directionLabel;
    final actualPlaceCollection = widget.selectedConductor?['activeTrip']?['placeCollection'] ?? widget.selectedPlaceCollection;

    final qrData = {
      'type': 'preBooking',
      'route': widget.route,
      'direction': actualDirection,
      'placeCollection': actualPlaceCollection,
      'from': widget.fromPlace['name'],
      'to': widget.toPlace['name'],
      'fromKm': (widget.fromPlace['km'] as num).toInt(),
      'toKm': (widget.toPlace['km'] as num).toInt(),
      'fromLatitude': widget.fromPlace['latitude'] ?? 0.0,
      'fromLongitude': widget.fromPlace['longitude'] ?? 0.0,
      'toLatitude': widget.toPlace['latitude'] ?? 0.0,
      'toLongitude': widget.toPlace['longitude'] ?? 0.0,
      'passengerLatitude': passengerLocation?.latitude ?? 0.0,
      'passengerLongitude': passengerLocation?.longitude ?? 0.0,
      'fare': baseFare,
      'quantity': widget.quantity,
      'amount': totalAmount,
      'fareTypes': widget.fareTypes,
      'discountBreakdown': discountBreakdown,
      'passengerFares': passengerFares,
      'userId': user.uid,
      'timestamp': now.millisecondsSinceEpoch,
      'boardingStatus': 'pending',
      'conductorId': widget.selectedConductor?['id'],
      'conductorName': widget.selectedConductor?['name'],
      'busNumber': widget.selectedConductor?['busNumber'],
      'tripId': widget.selectedConductor?['activeTrip']?['tripId'],
    };

    final data = {
      'route': widget.route,
      'direction': actualDirection,
      'placeCollection': actualPlaceCollection,
      'from': widget.fromPlace['name'],
      'to': widget.toPlace['name'],
      'fromKm': (widget.fromPlace['km'] as num).toInt(),
      'toKm': (widget.toPlace['km'] as num).toInt(),
      'fromLatitude': widget.fromPlace['latitude'] ?? 0.0,
      'fromLongitude': widget.fromPlace['longitude'] ?? 0.0,
      'toLatitude': widget.toPlace['latitude'] ?? 0.0,
      'toLongitude': widget.toPlace['longitude'] ?? 0.0,
      'passengerLatitude': passengerLocation?.latitude ?? 0.0,
      'passengerLongitude': passengerLocation?.longitude ?? 0.0,
      'passengerLocationTimestamp': passengerLocation != null ? FieldValue.serverTimestamp() : null,
      'fare': baseFare,
      'quantity': widget.quantity,
      'amount': totalAmount,
      'fareTypes': widget.fareTypes,
      'discountBreakdown': discountBreakdown,
      'passengerFares': passengerFares,
      'status': 'pending_payment', // ✅ Status is pending until paid
      'boardingStatus': 'pending',
      'paymentDeadline': now.add(Duration(minutes: 10)),
      'createdAt': now,
      'userId': user.uid,
      'conductorId': widget.selectedConductor?['id'],
      'conductorName': widget.selectedConductor?['name'],
      'busNumber': widget.selectedConductor?['busNumber'],
      'tripId': widget.selectedConductor?['activeTrip']?['tripId'],
      'qrData': jsonEncode(qrData),
    };

    try {
      print('💾 PreBook: Attempting to save booking to Firebase...');

      // ✅ ONLY save to user's collection - NOT to conductor collections
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .add(data);

      print('✅ PreBook: Booking saved to user collection with ID: ${docRef.id}');

      // Update qrData to include the booking ID
      qrData['bookingId'] = docRef.id;
      qrData['id'] = docRef.id;
      final updatedQrDataString = jsonEncode(qrData);

      await docRef.update({
        'qrData': updatedQrDataString,
      });

      print('✅ PreBook: Updated QR data with booking ID: ${docRef.id}');
      print('✅ PreBook: Booking will be saved to conductor collections AFTER payment is confirmed');

      // ❌ DO NOT save to conductor collections here!
      // This will be done in confirm_payment.dart after payment succeeds

      return docRef.id;
    } catch (e) {
      print('❌ PreBook: Error saving booking to Firebase: $e');
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final formattedTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final actualDirection = widget.selectedConductor?['activeTrip']?['direction'] ?? widget.directionLabel;
    final startKm = widget.fromPlace['km'] is num ? widget.fromPlace['km'] : num.tryParse(widget.fromPlace['km'].toString()) ?? 0;
    final endKm = widget.toPlace['km'] is num ? widget.toPlace['km'] : num.tryParse(widget.toPlace['km'].toString()) ?? 0;
    final baseFare = computeFullTripFare(widget.route);
    
    List<String> discountBreakdown = [];
    List<double> passengerFares = [];
    double totalAmount = 0.0;
    
    for (int i = 0; i < widget.fareTypes.length; i++) {
      final type = widget.fareTypes[i];
      double passengerFare;
      bool isDiscounted = false;
      if (type.toLowerCase() == 'pwd' || type.toLowerCase() == 'senior' || type.toLowerCase() == 'student') {
        passengerFare = baseFare * 0.8;
        isDiscounted = true;
      } else {
        passengerFare = baseFare;
      }
      totalAmount += passengerFare;
      passengerFares.add(passengerFare);
      discountBreakdown.add(
        'Passenger ${i + 1}: $type${isDiscounted ? ' (20% off)' : ' (No discount)'} — ${passengerFare.toStringAsFixed(2)} PHP',
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // Prevent back button if saving
        return !_isSaving;
      },
      child: AlertDialog(
        title: Text('Receipt', style: GoogleFonts.outfit(fontSize: 20, color: Colors.black)),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Route: ${widget.route}', style: GoogleFonts.outfit(fontSize: 14)),
                Text('Direction: $actualDirection', style: GoogleFonts.outfit(fontSize: 14)),
                Text('Date: $formattedDate', style: GoogleFonts.outfit(fontSize: 14)),
                Text('Time: $formattedTime', style: GoogleFonts.outfit(fontSize: 14)),
                Text('From: ${widget.fromPlace['name']}', style: GoogleFonts.outfit(fontSize: 14)),
                Text('To: ${widget.toPlace['name']}', style: GoogleFonts.outfit(fontSize: 14)),
                Text('From KM: ${(widget.fromPlace['km'] as num).toInt()}', style: GoogleFonts.outfit(fontSize: 14)),
                Text('To KM: ${(widget.toPlace['km'] as num).toInt()}', style: GoogleFonts.outfit(fontSize: 14)),
                Text('Selected Distance: ${(endKm - startKm).toStringAsFixed(1)} km', style: GoogleFonts.outfit(fontSize: 14)),
                Text('Full Trip Fare (Regular): ${baseFare.toStringAsFixed(2)} PHP', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('Quantity: ${widget.quantity}', style: GoogleFonts.outfit(fontSize: 14)),
                Text('Total Amount: ${totalAmount.toStringAsFixed(2)} PHP', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 16),
                Text('Discounts:', style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 14)),
                ...discountBreakdown.map((e) => Text(e, style: GoogleFonts.outfit(fontSize: 14))),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Text(
                    'Note: You pay the full trip fare for guaranteed seats',
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSaving ? Colors.grey : Color(0xFF0091AD),
            ),
            onPressed: _isSaving
                ? null
                : () async {
                    // ✅ CRITICAL: Check if already saving to prevent duplicates
                    if (_isSaving) {
                      print('⚠️ PreBook: Save already in progress, ignoring click');
                      return;
                    }

                    // Final check: ensure location is captured before saving
                    if (widget.currentLocation == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ Location not captured! Please go back and enable location access.'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 3),
                        ),
                      );
                      return;
                    }

                    // ✅ IMMEDIATELY set saving state to prevent rapid clicks
                    setState(() {
                      _isSaving = true;
                    });

                    // ✅ Add a small delay to ensure setState completes
                    await Future.delayed(Duration(milliseconds: 50));

                    try {
                      print('💾 PreBook: Starting booking save process...');
                      final bookingId = await savePreBooking(
                        context, 
                        baseFare, 
                        totalAmount, 
                        discountBreakdown, 
                        passengerFares
                      );

                      print('💾 PreBook: Booking save result - ID: $bookingId');

                      if (bookingId != null && bookingId.isNotEmpty) {
                        print('✅ PreBook: Booking saved successfully, navigating to payment page');
                        
                        if (mounted) {
                          // Close the receipt modal
                          Navigator.of(context).pop();
                          
                          // Navigate to payment page
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => PreBookPaymentPage(
                                bookingId: bookingId,
                                route: widget.route,
                                directionLabel: widget.directionLabel,
                                fromPlace: widget.fromPlace,
                                toPlace: widget.toPlace,
                                quantity: widget.quantity,
                                fareTypes: widget.fareTypes,
                                baseFare: baseFare,
                                totalAmount: totalAmount,
                                discountBreakdown: discountBreakdown,
                                passengerFares: passengerFares,
                              ),
                            ),
                          );
                        }
                      } else {
                        print('❌ PreBook: Booking save failed - bookingId is null or empty');
                        if (mounted) {
                          setState(() {
                            _isSaving = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('❌ Failed to save booking. Please try again.'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 5),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      print('❌ PreBook: Error in save process: $e');
                      if (mounted) {
                        setState(() {
                          _isSaving = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ Error: $e'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                    // Note: We don't reset _isSaving here on success because we're navigating away
                  },
            child: _isSaving
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Saving...', style: GoogleFonts.outfit(fontSize: 14, color: Colors.white)),
                    ],
                  )
                : Text('Confirm & Save', style: GoogleFonts.outfit(fontSize: 14, color: Colors.white)),
          ),
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: Text('Close', style: GoogleFonts.outfit(fontSize: 14, color: _isSaving ? Colors.grey[400] : Colors.grey[600])),
          ),
        ],
      ),
    );
  }
}