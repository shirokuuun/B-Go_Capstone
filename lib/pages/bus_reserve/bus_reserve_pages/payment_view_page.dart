import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

class PaymentViewPage extends StatefulWidget {
  final String reservationId;
  final List<String> selectedBusIds;
  final Map<String, dynamic> reservationDetails;
  final String status;

  const PaymentViewPage({
    Key? key,
    required this.reservationId,
    required this.selectedBusIds,
    required this.reservationDetails,
    required this.status,
  }) : super(key: key);

  @override
  State<PaymentViewPage> createState() => _PaymentViewPageState();
}

class _PaymentViewPageState extends State<PaymentViewPage> {
  File? _receiptImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  bool _isCancelling = false;
  List<Map<String, dynamic>> _busDetails = [];
  bool _isLoadingBusDetails = true;

  @override
  void initState() {
    super.initState();
    _fetchBusDetails();
  }

  Future<void> _fetchBusDetails() async {
    try {
      List<Map<String, dynamic>> details = [];

      for (String conductorId in widget.selectedBusIds) {
        DocumentSnapshot conductorDoc = await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorId)
            .get();

        if (conductorDoc.exists) {
          Map<String, dynamic> data =
              conductorDoc.data() as Map<String, dynamic>;
          details.add({
            'registrationNumber': data['registrationNumber'] ?? 'N/A',
            'plateNumber': data['plateNumber'] ?? 'N/A',
            'name': data['name'] ?? 'N/A',
            'driverName': data['driverName'] ?? 'N/A',
          });
        }
      }

      setState(() {
        _busDetails = details;
        _isLoadingBusDetails = false;
      });
    } catch (e) {
      print('Error fetching bus details: $e');
      setState(() {
        _isLoadingBusDetails = false;
      });
    }
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

  Future<void> _cancelReservation() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Cancel Reservation',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to cancel this reservation?',
                style: GoogleFonts.outfit(fontSize: 16),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No refunds will be issued for cancelled reservations.',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text(
                'No, Keep It',
                style: GoogleFonts.outfit(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Yes, Cancel',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      // Update reservation status to cancelled
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancellationReason': 'Cancelled by user - No refund',
        'cancelledBy': 'user',
      });

      // Update conductor documents - make buses available again
      for (String conductorId in widget.selectedBusIds) {
        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorId)
            .update({
          'busAvailabilityStatus': 'no-reservation',
          'availableForReservation': true,
          'reservationId': FieldValue.delete(),
          'reservationDetails': FieldValue.delete(),
        });
      }

      _showCustomSnackBar(
        'Reservation cancelled successfully. No refunds will be issued.',
        'success',
      );

      // Wait a moment then pop back to reservations list
      await Future.delayed(Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showCustomSnackBar('Error cancelling reservation: $e', 'error');
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    final titleFontSize = isMobile
        ? 20.0
        : isTablet
            ? 24.0
            : 28.0;
    final sectionFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final horizontalPadding = isMobile
        ? 16.0
        : isTablet
            ? 20.0
            : 24.0;
    final verticalPadding = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;

    // Check if cancellation button should be shown (not for completed or already cancelled)
    final canCancel =
        widget.status != 'completed' && widget.status != 'cancelled';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: const Color(0xFF0091AD),
            leading: Padding(
              padding: EdgeInsets.only(top: 18.0, left: 8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
            title: Padding(
              padding: EdgeInsets.only(top: 22.0),
              child: Text(
                'Reservation Details',
                style: GoogleFonts.outfit(
                  fontSize: titleFontSize,
                  color: Colors.white,
                ),
              ),
            ),
            centerTitle: true,
            actions: canCancel
                ? [
                    Padding(
                      padding: EdgeInsets.only(top: 18, right: 8),
                      child: IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.white),
                        onPressed: _isCancelling ? null : _cancelReservation,
                        tooltip: 'Cancel Reservation',
                      ),
                    ),
                  ]
                : null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),

                  // Status Icon Header
                  _buildStatusHeader(),

                  SizedBox(height: 24),

                  // Cancellation Warning (if applicable)
                  if (canCancel) _buildCancellationWarning(),

                  if (canCancel) SizedBox(height: 24),

                  // Reservation Summary
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF0091AD).withOpacity(0.1),
                      border:
                          Border.all(color: Color(0xFF0091AD).withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.receipt,
                                color: Color(0xFF0091AD), size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Reservation Summary',
                              style: GoogleFonts.outfit(
                                fontSize: sectionFontSize,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0091AD),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        _buildSummaryRow(
                            'Reservation ID', widget.reservationId),
                        _buildSummaryRow(
                            'From', widget.reservationDetails['from'] ?? 'N/A'),
                        _buildSummaryRow(
                            'To', widget.reservationDetails['to'] ?? 'N/A'),
                        _buildSummaryRow(
                            'Trip Type',
                            widget.reservationDetails['isRoundTrip'] == true
                                ? 'Round Trip'
                                : 'One Way'),
                        _buildSummaryRow('Passenger',
                            widget.reservationDetails['fullName'] ?? 'N/A'),
                        _buildSummaryRow('Email',
                            widget.reservationDetails['email'] ?? 'N/A'),
                        _buildSummaryRow(
                            'Passengers',
                            widget.reservationDetails['passengerCount']
                                    ?.toString() ??
                                'N/A'),
                        _buildSummaryRow(
                            'Total Amount', '₱${_calculateTotalAmount()}.00'),
                        _buildSummaryRow('Status', _getStatusText()),
                        if (widget.reservationDetails['timestamp'] != null)
                          _buildSummaryRow(
                              'Created Date',
                              _formatDate(
                                  widget.reservationDetails['timestamp'])),
                        if (widget.reservationDetails['departureDate'] != null)
                          _buildSummaryRow(
                              'Departure Date',
                              _formatDateOnly(widget.reservationDetails[
                                  'departureDate'])),
                        if (widget.reservationDetails['departureTime'] != null)
                          _buildSummaryRow('Departure Time',
                              widget.reservationDetails['departureTime']),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Bus Details Section
                  if (!_isLoadingBusDetails && _busDetails.isNotEmpty)
                    _buildBusDetailsSection(),

                  if (!_isLoadingBusDetails && _busDetails.isNotEmpty)
                    SizedBox(height: 24),

                  // Status-specific content
                  if (widget.status == 'pending') ...[
                    _buildPendingPaymentContent(),
                  ] else if (widget.status == 'receipt_uploaded') ...[
                    _buildReceiptUploadedContent(),
                  ] else if (widget.status == 'confirmed') ...[
                    _buildConfirmedContent(),
                  ] else if (widget.status == 'completed') ...[
                    _buildCompletedContent(),
                  ] else if (widget.status == 'cancelled') ...[
                    _buildCancelledContent(),
                  ],

                  SizedBox(height: 24),

                  // Important Notes
                  _buildImportantNotes(),

                  SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        top: false,
        left: false,
        right: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: verticalPadding),
          child: canCancel
              ? Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: Size(
                              double.infinity,
                              isMobile
                                  ? 45
                                  : isTablet
                                      ? 50
                                      : 55),
                        ),
                        onPressed: _isCancelling ? null : _cancelReservation,
                        child: _isCancelling
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                'Cancel Reservation',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: isMobile
                                      ? 12
                                      : isTablet
                                          ? 18
                                          : 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0091AD),
                          minimumSize: Size(
                              double.infinity,
                              isMobile
                                  ? 45
                                  : isTablet
                                      ? 50
                                      : 55),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Back',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: isMobile
                                ? 13
                                : isTablet
                                    ? 18
                                    : 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0091AD),
                    minimumSize: Size(
                        double.infinity,
                        isMobile
                            ? 45
                            : isTablet
                                ? 50
                                : 55),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Back to Reservations',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: isMobile
                          ? 16
                          : isTablet
                              ? 18
                              : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCancellationWarning() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade700, size: 24),
              SizedBox(width: 8),
              Text(
                'Cancellation Policy',
                style: GoogleFonts.outfit(
                  fontSize: isMobile
                      ? 16
                      : isTablet
                          ? 18
                          : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '• You can cancel this reservation at any time\n'
            '• No refunds will be issued for cancelled reservations\n'
            '• The bus will become available for other users\n'
            '• This action cannot be undone',
            style: GoogleFonts.outfit(
              fontSize: isMobile
                  ? 14
                  : isTablet
                      ? 16
                      : 18,
              color: Colors.red.shade800,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusSubtitle;

    switch (widget.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusTitle = 'Pending Payment';
        statusSubtitle = 'Please complete your payment to confirm reservation';
        break;
      case 'receipt_uploaded':
        statusColor = Colors.blue;
        statusIcon = Icons.receipt;
        statusTitle = 'Receipt Uploaded';
        statusSubtitle = 'Waiting for admin verification';
        break;
      case 'confirmed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusTitle = 'Reservation Confirmed';
        statusSubtitle = 'Your bus reservation is confirmed';
        break;
      case 'completed':
        statusColor = Colors.purple;
        statusIcon = Icons.flag_circle;
        statusTitle = 'Journey Completed';
        statusSubtitle = 'You have successfully completed your journey';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusTitle = 'Reservation Cancelled';
        statusSubtitle = 'This reservation has been cancelled';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
        statusTitle = 'Unknown Status';
        statusSubtitle = '';
    }

    return Center(
      child: Column(
        children: [
          Container(
            width: isMobile ? 70 : 80,
            height: isMobile ? 70 : 80,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: isMobile ? 40 : 50,
            ),
          ),
          SizedBox(height: 12),
          Text(
            statusTitle,
            style: GoogleFonts.outfit(
              fontSize: isMobile
                  ? 20
                  : isTablet
                      ? 24
                      : 28,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          SizedBox(height: 4),
          Text(
            statusSubtitle,
            style: GoogleFonts.outfit(
              fontSize: isMobile
                  ? 12
                  : isTablet
                      ? 14
                      : 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.outfit(
                fontSize: isMobile
                    ? 12
                    : isTablet
                        ? 14
                        : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: isMobile
                    ? 12
                    : isTablet
                        ? 14
                        : 16,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusDetailsSection() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final sectionFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_bus, color: Color(0xFF0091AD), size: 24),
              SizedBox(width: 8),
              Text(
                'Bus Details',
                style: GoogleFonts.outfit(
                  fontSize: sectionFontSize,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0091AD),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ..._busDetails.asMap().entries.map((entry) {
            int index = entry.key;
            Map<String, dynamic> bus = entry.value;

            return Column(
              children: [
                if (index > 0) Divider(height: 24, thickness: 1),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF0091AD).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Color(0xFF0091AD).withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bus ${index + 1}',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile
                              ? 14
                              : isTablet
                                  ? 16
                                  : 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0091AD),
                        ),
                      ),
                      SizedBox(height: 8),
                      _buildBusDetailRow('Driver Name:', bus['driverName']),
                      _buildBusDetailRow('Conductor Name:', bus['name']),
                      _buildBusDetailRow('Plate Number:', bus['plateNumber']),
                      _buildBusDetailRow(
                          'Registration #:', bus['registrationNumber']),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildBusDetailRow(String label, String value) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: isMobile
                    ? 12
                    : isTablet
                        ? 14
                        : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: isMobile
                    ? 12
                    : isTablet
                        ? 14
                        : 16,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingPaymentContent() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final sectionFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final subtitleFontSize = isMobile
        ? 14.0
        : isTablet
            ? 16.0
            : 18.0;
    final qrSize = isMobile
        ? 200.0
        : isTablet
            ? 250.0
            : 300.0;

    return Column(
      children: [
        // QR Code Section
        Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Scan to Pay',
                  style: GoogleFonts.outfit(
                    fontSize: sectionFontSize,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0091AD),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  width: qrSize,
                  height: qrSize,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/payment-qr.jpg',
                          width: qrSize * 0.8,
                          height: qrSize * 0.8,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.qr_code_2,
                              size: qrSize * 0.6,
                              color: Colors.grey.shade400,
                            );
                          },
                        ),
                        SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Amount: ₱${_calculateTotalAmount()}',
                  style: GoogleFonts.outfit(
                    fontSize: subtitleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0091AD),
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 24),

        // Receipt Upload Section
        _buildReceiptUploadSection(),
      ],
    );
  }

  Widget _buildReceiptUploadedContent() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final sectionFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt, color: Colors.blue.shade700, size: 24),
              SizedBox(width: 8),
              Text(
                'Receipt Information',
                style: GoogleFonts.outfit(
                  fontSize: sectionFontSize,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0091AD),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildDetailRow(
              'Receipt Status:', 'Uploaded - Awaiting Verification'),
          if (widget.reservationDetails['receiptUploadedAt'] != null)
            _buildDetailRow('Uploaded At:',
                _formatDate(widget.reservationDetails['receiptUploadedAt'])),
          _buildDetailRow('Amount:', '₱${_calculateTotalAmount()}.00'),
        ],
      ),
    );
  }

  Widget _buildConfirmedContent() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final sectionFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
              SizedBox(width: 8),
              Text(
                'Confirmation Details',
                style: GoogleFonts.outfit(
                  fontSize: sectionFontSize,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0091AD),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildDetailRow('Payment Status:', 'Verified & Confirmed'),
          if (widget.reservationDetails['approvedAt'] != null)
            _buildDetailRow('Confirmed At:',
                _formatDate(widget.reservationDetails['approvedAt'])),
          if (widget.reservationDetails['approvedBy'] != null)
            _buildDetailRow(
                'Approved By:', widget.reservationDetails['approvedBy']),
          _buildDetailRow('Amount Paid:', '₱${_calculateTotalAmount()}.00'),
        ],
      ),
    );
  }

  Widget _buildCompletedContent() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final sectionFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_circle, color: Colors.purple.shade700, size: 24),
              SizedBox(width: 8),
              Text(
                'Journey Summary',
                style: GoogleFonts.outfit(
                  fontSize: sectionFontSize,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0091AD),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildDetailRow('Journey Status:', 'Completed Successfully'),
          if (widget.reservationDetails['completedAt'] != null)
            _buildDetailRow('Completed At:',
                _formatDate(widget.reservationDetails['completedAt'])),
          if (widget.reservationDetails['completedBy'] != null)
            _buildDetailRow(
                'Completed By:', widget.reservationDetails['completedBy']),
          _buildDetailRow('Amount Paid:', '₱${_calculateTotalAmount()}.00'),
        ],
      ),
    );
  }

  Widget _buildCancelledContent() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final sectionFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cancel, color: Colors.red.shade700, size: 24),
              SizedBox(width: 8),
              Text(
                'Cancellation Details',
                style: GoogleFonts.outfit(
                  fontSize: sectionFontSize,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0091AD),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildDetailRow('Status:', 'Cancelled'),
          if (widget.reservationDetails['cancelledAt'] != null)
            _buildDetailRow('Cancelled At:',
                _formatDate(widget.reservationDetails['cancelledAt'])),
          if (widget.reservationDetails['cancelledBy'] != null)
            _buildDetailRow(
                'Cancelled By:', widget.reservationDetails['cancelledBy']),
          if (widget.reservationDetails['cancellationReason'] != null)
            _buildDetailRow(
                'Reason:', widget.reservationDetails['cancellationReason']),
        ],
      ),
    );
  }

  Widget _buildReceiptUploadSection() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final sectionFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final subtitleFontSize = isMobile
        ? 14.0
        : isTablet
            ? 16.0
            : 18.0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Payment Receipt',
            style: GoogleFonts.outfit(
              fontSize: sectionFontSize,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0091AD),
            ),
          ),
          SizedBox(height: 12),
          if (_receiptImage == null)
            GestureDetector(
              onTap: _pickReceiptImage,
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap to upload receipt',
                      style: GoogleFonts.outfit(
                        fontSize: subtitleFontSize,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _receiptImage!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (_receiptImage != null) ...[
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickReceiptImage,
                    icon: Icon(Icons.edit, size: 18),
                    label: Text('Retake'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _uploadReceipt,
                    icon: _isUploading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.upload, size: 18),
                    label: Text(_isUploading ? 'Uploading...' : 'Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0091AD),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImportantNotes() {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    Color noteColor;
    IconData noteIcon;
    String noteTitle;
    List<String> notePoints;

    switch (widget.status) {
      case 'pending':
        noteColor = Colors.orange;
        noteIcon = Icons.info;
        noteTitle = 'Payment Instructions';
        notePoints = [
          'Scan the QR code to make payment',
          'Upload your payment receipt',
          'Wait for admin verification',
          'You will receive confirmation via email',
        ];
        break;
      case 'receipt_uploaded':
        noteColor = Colors.blue;
        noteIcon = Icons.schedule;
        noteTitle = 'Under Verification';
        notePoints = [
          'Your receipt is being verified by admin',
          'This usually takes a few minutes',
          'You will be notified once approved',
          'Check your email for updates',
        ];
        break;
      case 'confirmed':
        noteColor = Colors.green;
        noteIcon = Icons.check_circle;
        noteTitle = 'Reservation Confirmed';
        notePoints = [
          'Your bus reservation is confirmed',
          'Your seats are guaranteed for this trip',
          'Arrive at the pickup location on time',
          'Keep this confirmation for your records',
        ];
        break;
      case 'completed':
        noteColor = Colors.purple;
        noteIcon = Icons.flag_circle;
        noteTitle = 'Journey Completed';
        notePoints = [
          'You have successfully completed your journey',
          'Thank you for using our service',
          'We hope you had a pleasant trip',
          'Rate your experience if you haven\'t already',
        ];
        break;
      case 'cancelled':
        noteColor = Colors.red;
        noteIcon = Icons.cancel;
        noteTitle = 'Reservation Cancelled';
        notePoints = [
          'This reservation has been cancelled',
          'Please make a new reservation if needed',
          'Contact support for refund inquiries',
          'Check cancellation policy for more details',
        ];
        break;
      default:
        noteColor = Colors.grey;
        noteIcon = Icons.info;
        noteTitle = 'Important Information';
        notePoints = [
          'Keep this confirmation for your records',
          'Contact support if you have any questions',
        ];
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: noteColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: noteColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(noteIcon, color: noteColor, size: 20),
              SizedBox(width: 8),
              Text(
                noteTitle,
                style: GoogleFonts.outfit(
                  fontSize: isMobile
                      ? 14
                      : isTablet
                          ? 16
                          : 18,
                  fontWeight: FontWeight.w600,
                  color: noteColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...notePoints
              .map((point) => Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $point',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile
                            ? 12
                            : isTablet
                                ? 14
                                : 16,
                        color: noteColor.withOpacity(0.9),
                      ),
                    ),
                  ))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: isMobile
                    ? 12
                    : isTablet
                        ? 14
                        : 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: isMobile
                    ? 12
                    : isTablet
                        ? 14
                        : 16,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _calculateTotalAmount() {
    return widget.selectedBusIds.length * 2000;
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';

    DateTime dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is DateTime) {
      dateTime = date;
    } else if (date is String) {
      // If it's already a formatted string, return it
      return date;
    } else {
      return 'N/A';
    }

    return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
  }

  String _formatDateOnly(dynamic date) {
    if (date == null) return 'N/A';

    DateTime dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is DateTime) {
      dateTime = date;
    } else if (date is String) {
      // If it's already a formatted string, return it
      return date;
    } else {
      return 'N/A';
    }

    return DateFormat('EEE, MMM d, yyyy').format(dateTime);
  }

  String _getStatusText() {
    switch (widget.status) {
      case 'pending':
        return 'Pending Payment';
      case 'receipt_uploaded':
        return 'Receipt Uploaded';
      case 'confirmed':
        return 'Confirmed';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return widget.status;
    }
  }

  Future<void> _pickReceiptImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _receiptImage = File(image.path);
        });
      }
    } catch (e) {
      _showCustomSnackBar('Error picking image: $e', 'error');
    }
  }

  Future<void> _uploadReceipt() async {
    if (_receiptImage == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // Upload image to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child('receipts').child(
          '${widget.reservationId}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putFile(_receiptImage!);
      final downloadUrl = await storageRef.getDownloadURL();

      // Update reservation with receipt URL
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId)
          .update({
        'receiptUrl': downloadUrl,
        'receiptUploadedAt': FieldValue.serverTimestamp(),
        'status': 'receipt_uploaded',
      });

      // Update conductor documents
      for (String conductorId in widget.selectedBusIds) {
        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorId)
            .update({
          'reservationDetails.receiptUrl': downloadUrl,
          'reservationDetails.receiptUploadedAt': FieldValue.serverTimestamp(),
          'reservationDetails.status': 'receipt_uploaded',
        });
      }

      _showCustomSnackBar(
        'Receipt uploaded successfully! Admin will verify your payment.',
        'success',
      );

      // Clear the image after successful upload
      setState(() {
        _receiptImage = null;
      });

      // Navigate back after delay so user can see the success message
      await Future.delayed(Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showCustomSnackBar('Error uploading receipt: $e', 'error');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
}
