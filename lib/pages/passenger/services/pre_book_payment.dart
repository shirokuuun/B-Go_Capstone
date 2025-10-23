import 'package:b_go/pages/passenger/services/pre_book_payment_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:b_go/services/payment_service.dart';
import 'package:b_go/services/realtime_location_service.dart';

/// Payment page for pre-booking
/// Handles payment UI, timer countdown, payment processing, and status updates
class PreBookPaymentPage extends StatefulWidget {
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
  final DateTime? paymentDeadline;

  const PreBookPaymentPage({
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
    this.paymentDeadline,
  }) : super(key: key);

  @override
  State<PreBookPaymentPage> createState() => _PreBookPaymentPageState();
}

class _PreBookPaymentPageState extends State<PreBookPaymentPage>
    with WidgetsBindingObserver {
  late Timer _timer;
  late Timer _paymentStatusTimer;
  late DateTime _deadline;
  int _remainingSeconds = 600; // 10 minutes in seconds
  final RealtimeLocationService _locationService = RealtimeLocationService();

  @override
  void initState() {
    super.initState();
    // Use passed deadline or create new one
    _deadline =
        widget.paymentDeadline ?? DateTime.now().add(Duration(minutes: 10));
    _startTimer();
    _startPaymentStatusCheck();

    // Add app lifecycle observer for background/foreground handling
    WidgetsBinding.instance.addObserver(this);
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds = _deadline.difference(DateTime.now()).inSeconds;
        if (_remainingSeconds <= 0) {
          _timer.cancel();
          _paymentStatusTimer.cancel();
          _showTimeoutDialog();
        }
      });
    });
  }

  void _startPaymentStatusCheck() {
    _paymentStatusTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _checkPaymentStatus();
    });
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Payment Timeout', style: GoogleFonts.outfit(fontSize: 20)),
        content: Text(
          'Your payment time has expired. The pre-booking has been cancelled.',
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              // Navigate back to home page
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/home',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0091AD),
            ),
            child: Text('OK',
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App is going to background - switch to background tracking
        _locationService.handleAppBackgrounded();
        break;
      case AppLifecycleState.resumed:
        // App is coming to foreground - switch back to foreground tracking
        _locationService.handleAppForegrounded();
        break;
      case AppLifecycleState.detached:
        // App is being terminated - stop all tracking
        _locationService.stopTracking();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _paymentStatusTimer.cancel();

    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Don't stop real-time location tracking when page is disposed
    // The location service should continue running for the conductor to see real-time updates
    // It will be stopped when the passenger is scanned by the conductor
    super.dispose();
  }

  Future<void> cancelPreBooking(BuildContext context) async {
    try {
      // Delete the booking from Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showCustomSnackBar(
            'User not authenticated. Please try again.', 'error');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .doc(widget.bookingId)
          .delete();

      _showCustomSnackBar('Pre-booking cancelled and deleted!', 'success');

      // Navigate back to home page by popping all pages until we reach the home page
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/home',
        (route) => false, // Remove all previous routes
      );
    } catch (e) {
      print('Error cancelling booking: $e');
      _showCustomSnackBar(
          'Error cancelling booking. Please try again.', 'error');
    }
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final formattedTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final startKm = widget.fromPlace['km'] is num
        ? widget.fromPlace['km']
        : num.tryParse(widget.fromPlace['km'].toString()) ?? 0;
    final endKm = widget.toPlace['km'] is num
        ? widget.toPlace['km']
        : num.tryParse(widget.toPlace['km'].toString()) ?? 0;
    final distance = endKm - startKm;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0091AD),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Go back to the previous page (PreBook)
            Navigator.of(context).pop();
          },
        ),
        title: Text('Payment Page',
            style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: size.height * 0.04),
            // Timer Section
            Container(
              padding: EdgeInsets.all(20),
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _remainingSeconds <= 60
                    ? Colors.red[50]
                    : Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _remainingSeconds <= 60
                      ? Colors.red[200]!
                      : Colors.orange[200]!,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Payment Timeout',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _remainingSeconds <= 60
                          ? Colors.red[700]
                          : Colors.orange[700],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Please complete your payment before the timer runs out',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Booking Summary Card
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking Summary',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildDetailRow('Booking ID', widget.bookingId),
                      _buildDetailRow('Route', widget.route),
                      _buildDetailRow('Direction', widget.directionLabel),
                      _buildDetailRow('Date', formattedDate),
                      _buildDetailRow('Time', formattedTime),
                      _buildDetailRow('From', widget.fromPlace['name']),
                      _buildDetailRow('To', widget.toPlace['name']),
                      _buildDetailRow(
                          'Distance', '${distance.toStringAsFixed(1)} km'),
                      _buildDetailRow('Passengers', widget.quantity.toString()),
                      SizedBox(height: 16),
                      Divider(),
                      SizedBox(height: 8),
                      Text(
                        'Fare Breakdown',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 12),
                      ...widget.discountBreakdown.map((breakdown) => Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text(
                              breakdown,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          )),
                      SizedBox(height: 16),
                      Divider(),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Amount',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '₱${widget.totalAmount.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0091AD),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Pay Now Button - Navigate to PaymentPage
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate to PaymentPage with all booking details
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaymentPage(
                              bookingId: widget.bookingId,
                              route: widget.route,
                              directionLabel: widget.directionLabel,
                              fromPlace: widget.fromPlace,
                              toPlace: widget.toPlace,
                              quantity: widget.quantity,
                              fareTypes: widget.fareTypes,
                              baseFare: widget.baseFare,
                              totalAmount: widget.totalAmount,
                              discountBreakdown: widget.discountBreakdown,
                              passengerFares: widget.passengerFares,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0091AD),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Pay Now',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Cancel Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Cancel Booking',
                                style: GoogleFonts.outfit(fontSize: 18)),
                            content: Text(
                              'Are you sure you want to cancel this booking?',
                              style: GoogleFonts.outfit(fontSize: 14),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text('No',
                                    style: GoogleFonts.outfit(fontSize: 14)),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  cancelPreBooking(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: Text('Yes, Cancel',
                                    style: GoogleFonts.outfit(
                                        fontSize: 14, color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel Booking',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkPaymentStatus() async {
    try {
      final paymentStatus =
          await PaymentService.checkPaymentStatus(widget.bookingId);

      print('Payment status check result: $paymentStatus');

      if (paymentStatus != null) {
        // Handle both API response format and direct Firestore format
        final status = paymentStatus['status'] ??
            paymentStatus['paymentStatus'] ??
            'pending';
        final isTestMode = paymentStatus['testMode'] ?? false;
        final paymentError = paymentStatus['paymentError'];

        print(
            '🔍 Payment status check: $status, testMode: $isTestMode, error: $paymentError');

        if (status == 'paid') {
          _timer.cancel();
          _paymentStatusTimer.cancel();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isTestMode
                  ? 'Test payment successful! Your reservation is confirmed.'
                  : 'Payment successful! Your reservation is confirmed.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          // Navigate to home page
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/home',
            (route) => false,
          );
        } else if (status == 'payment_failed' || status == 'failed') {
          _timer.cancel();
          _paymentStatusTimer.cancel();

          String errorMsg = 'Payment failed. Please try again.';
          if (paymentError != null && paymentError.isNotEmpty) {
            errorMsg = 'Payment failed: $paymentError';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ $errorMsg'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        } else if (status == 'payment_expired' || status == 'expired') {
          _timer.cancel();
          _paymentStatusTimer.cancel();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⏰ Payment session expired. Please try again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        } else if (status == 'cancelled') {
          _timer.cancel();
          _paymentStatusTimer.cancel();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Payment was cancelled.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        // For 'pending_payment' or 'payment_initiated' status, continue monitoring
      }
    } catch (e) {
      print('Error checking payment status: $e');
      // Don't show error to user unless it's critical
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
}