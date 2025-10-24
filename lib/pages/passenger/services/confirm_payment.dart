import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Payment confirmation page
/// Shows booking details and processes payment
class ConfirmationPayment extends StatefulWidget {
  final String bookingId;
  final String route;
  final String directionLabel;
  final Map<String, dynamic> fromPlace;
  final Map<String, dynamic> toPlace;
  final int quantity;
  final List<String> fareTypes;
  final double baseFare;
  final double totalAmount;
  final List<String> discountBreakdown;
  final List<double> passengerFares;
  final double availableBalance;

  const ConfirmationPayment({
    Key? key,
    required this.bookingId,
    required this.route,
    required this.directionLabel,
    required this.fromPlace,
    required this.toPlace,
    required this.quantity,
    required this.fareTypes,
    required this.baseFare,
    required this.totalAmount,
    required this.discountBreakdown,
    required this.passengerFares,
    required this.availableBalance,
  }) : super(key: key);

  @override
  State<ConfirmationPayment> createState() => _ConfirmationPaymentState();
}

class _ConfirmationPaymentState extends State<ConfirmationPayment> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C5EED),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'G',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C5EED),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'GCash',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // White Card with Payment Details
                  Container(
                    margin: EdgeInsets.all(16),
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Dragonpay Logo/Title
                        Text(
                          'Gcash Pay',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 24),
                        
                        // PAY WITH Section
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PAY WITH',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'GCash',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Available Balance',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF2C5EED),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Text(
                                'PHP ${widget.availableBalance.toStringAsFixed(2)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Divider
                        Container(
                          height: 1,
                          color: Colors.grey[200],
                        ),
                        
                        SizedBox(height: 24),
                        
                        // YOU ARE ABOUT TO PAY Section
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YOU ARE ABOUT TO PAY',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 16),
                            
                            // Booking Details
                            _buildDetailRow('Route', widget.route),
                            _buildDetailRow('Direction', widget.directionLabel),
                            _buildDetailRow('From', widget.fromPlace['name']),
                            _buildDetailRow('To', widget.toPlace['name']),
                            _buildDetailRow('Passengers', widget.quantity.toString()),
                            
                            SizedBox(height: 16),
                            
                            // Amount
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Amount',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'PHP ${widget.totalAmount.toStringAsFixed(2)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C5EED),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Divider
                        Container(
                          height: 1,
                          color: Colors.grey[200],
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Fare Breakdown
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FARE BREAKDOWN',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 12),
                            ...widget.discountBreakdown.map((breakdown) => Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                breakdown,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                            )),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Pay Button at Bottom
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF2C5EED),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: Size(double.infinity, 50),
              ),
              child: _isProcessing
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Pay PHP ${widget.totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// Process payment - Same logic as in pre_book_payment.dart
  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showCustomSnackBar('User not authenticated. Please try again.', 'error');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Simulate payment processing
      await Future.delayed(Duration(seconds: 2));

      // Update booking status in Firestore
      final now = DateTime.now();
      final formattedDate =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Get the booking data
      final bookingDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .doc(widget.bookingId)
          .get();

      if (!bookingDoc.exists) {
        _showCustomSnackBar('Booking not found. Please try again.', 'error');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      final bookingData = bookingDoc.data()!;
      final conductorId = bookingData['conductorId'] as String?;

      if (conductorId == null) {
        _showCustomSnackBar('Conductor information missing.', 'error');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Update user's booking status
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .doc(widget.bookingId)
          .update({
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'paymentMethod': 'simulated',
        'testMode': true,
      });

      // Update conductor's booking status
      await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('preBookings')
          .doc(widget.bookingId)
          .update({
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
        'paymentMethod': 'simulated',
        'testMode': true,
      });

      // Update status in dailyTrips collection
      await _updateDailyTripsStatus(conductorId, formattedDate, 'paid');

      // Update status in remittance collection
      await _updateRemittanceStatus(conductorId, formattedDate, 'paid');

      // Show success message
      _showCustomSnackBar(
        'Payment successful! Your reservation is confirmed.',
        'success',
      );

      // Wait a moment for user to see the success message
      await Future.delayed(Duration(seconds: 1));

      // Navigate back to home
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
      }
    } catch (e) {
      print('❌ Error processing payment: $e');
      _showCustomSnackBar(
        '❌ Payment failed. Please try again.',
        'error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Helper method to update status in dailyTrips collection
  Future<void> _updateDailyTripsStatus(
      String conductorId, String formattedDate, String status) async {
    try {
      final dailyTripDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('dailyTrips')
          .doc(formattedDate)
          .get();

      if (dailyTripDoc.exists) {
        final dailyTripData = dailyTripDoc.data();
        final currentTrip = dailyTripData?['currentTrip'] ?? 1;
        final tripCollection = 'trip$currentTrip';

        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorId)
            .collection('dailyTrips')
            .doc(formattedDate)
            .collection(tripCollection)
            .doc('preBookings')
            .collection('preBookings')
            .doc(widget.bookingId)
            .update({
          'status': status,
          'paidAt': FieldValue.serverTimestamp(),
          'paymentMethod': 'simulated',
        });

        print('✅ PreBook: Updated dailyTrips status to $status');
      }
    } catch (e) {
      print('❌ PreBook: Error updating dailyTrips status: $e');
    }
  }

  /// ✅ IMPROVED: Helper method to save paid pre-booking to remittance/tickets collection
  /// This ensures paid pre-bookings appear EVERYWHERE (trip pages AND trip summary)
  Future<void> _updateRemittanceStatus(
      String conductorId, String formattedDate, String status) async {
    try {
      // Get the booking data to save to remittance
      final bookingDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('preBookings')
          .doc(widget.bookingId)
          .get();

      if (!bookingDoc.exists) {
        print('❌ PreBook: Booking not found in conductor preBookings');
        return;
      }

      final bookingData = bookingDoc.data()!;

      // ✅ IMPROVED: Explicitly set all required fields to ensure compatibility
      await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('remittance')
          .doc(formattedDate)
          .collection('tickets')
          .doc(widget.bookingId)
          .set({
        // Required fields for Trip Page
        'from': bookingData['from'] ?? '',
        'to': bookingData['to'] ?? '',
        'totalFare': bookingData['totalFare']?.toString() ?? '0.00',
        'quantity': bookingData['quantity'] ?? 1,
        'timestamp': bookingData['timestamp'] ?? FieldValue.serverTimestamp(),
        
        // Additional fields
        'startKm': bookingData['fromKm'] ?? 0,
        'endKm': bookingData['toKm'] ?? 0,
        'totalKm': (bookingData['toKm'] ?? 0) - (bookingData['fromKm'] ?? 0),
        'farePerPassenger': bookingData['farePerPassenger'] ?? [bookingData['totalFare'] ?? 37],
        'discountAmount': bookingData['discountAmount'] ?? '0.00',
        'discountBreakdown': bookingData['discountBreakdown'] ?? [],
        'route': bookingData['route'] ?? '',
        'direction': bookingData['direction'] ?? '',
        'placeCollection': bookingData['placeCollection'] ?? 'Place',
        
        // Status and type fields
        'status': status,
        'paidAt': FieldValue.serverTimestamp(),
        'paymentMethod': 'simulated',
        'documentType': 'preBooking',
        'ticketType': 'preBooking',
        'active': true,
        
        // Booking metadata
        'userId': bookingData['userId'],
        'conductorId': conductorId,
        'conductorName': bookingData['conductorName'],
        'busNumber': bookingData['busNumber'],
        'tripId': bookingData['tripId'],
        'preBookingId': widget.bookingId,
        'qrData': bookingData['qrData'],
        
        // Passenger info (optional)
        'passengerLatitude': bookingData['passengerLatitude'],
        'passengerLongitude': bookingData['passengerLongitude'],
        
        // Boarding status
        'boardingStatus': bookingData['boardingStatus'] ?? 'pending',
      }, SetOptions(merge: true));

      print('✅ PreBook: Saved to remittance/tickets collection with status $status');
      print('✅ PreBook: Ticket ID: ${widget.bookingId}');
      print('✅ PreBook: From: ${bookingData['from']} → To: ${bookingData['to']}');
    } catch (e) {
      print('❌ PreBook: Error updating remittance status: $e');
    }
  }

  void _showCustomSnackBar(String message, String type) {
    if (!mounted) return;
    
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
        duration: Duration(seconds: 3),
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
}