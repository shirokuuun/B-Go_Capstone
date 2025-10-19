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
                        _buildSummaryRow('Number of Buses',
                            '${widget.selectedBusIds.length}'),
                        _buildSummaryRow(
                            'Total Amount', '₱${_calculateTotalAmount()}'),
                        _buildSummaryRow('Status', _getStatusText()),
                        if (widget.reservationDetails['timestamp'] != null)
                          _buildSummaryRow(
                              'Created Date',
                              _formatDate(
                                  widget.reservationDetails['timestamp'])),
                        if (widget.reservationDetails['departureDate'] != null)
                          _buildSummaryRow(
                              'Departure Date',
                              _formatDate(
                                  widget.reservationDetails['departureDate'])),
                        if (widget.reservationDetails['departureTime'] != null)
                          _buildSummaryRow('Departure Time',
                              widget.reservationDetails['departureTime']),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Detailed Booking Information
                  _buildBookingDetailsCard(),

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

  Widget _buildBookingDetailsCard() {
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
          Text(
            'Detailed Information',
            style: GoogleFonts.outfit(
              fontSize: sectionFontSize,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0091AD),
            ),
          ),
          SizedBox(height: 16),
          _buildDetailRow('Route:',
              '${widget.reservationDetails['from']} → ${widget.reservationDetails['to']}'),
          _buildDetailRow(
              'Trip Type:',
              widget.reservationDetails['isRoundTrip'] == true
                  ? 'Round Trip'
                  : 'One Way'),
          _buildDetailRow('Buses Selected:', '${widget.selectedBusIds.length}'),
          _buildDetailRow('Amount per Bus:', '₱2,000.00'),
          _buildDetailRow('Total Amount:', '₱${_calculateTotalAmount()}'),
          _buildDetailRow('Status:', _getStatusText()),

          // Show dates based on status
          if (widget.status == 'pending' &&
              widget.reservationDetails['timestamp'] != null) ...[
            _buildDetailRow('Created:',
                _formatDate(widget.reservationDetails['timestamp'])),
          ],

          if (widget.status == 'receipt_uploaded') ...[
            if (widget.reservationDetails['receiptUploadedAt'] != null)
              _buildDetailRow('Receipt Uploaded:',
                  _formatDate(widget.reservationDetails['receiptUploadedAt'])),
          ],

          if (widget.status == 'confirmed') ...[
            if (widget.reservationDetails['approvedAt'] != null)
              _buildDetailRow('Confirmed At:',
                  _formatDate(widget.reservationDetails['approvedAt'])),
            if (widget.reservationDetails['approvedBy'] != null)
              _buildDetailRow(
                  'Approved By:', widget.reservationDetails['approvedBy']),
          ],

          if (widget.status == 'completed') ...[
            if (widget.reservationDetails['completedAt'] != null)
              _buildDetailRow('Completed At:',
                  _formatDate(widget.reservationDetails['completedAt'])),
            if (widget.reservationDetails['completedBy'] != null)
              _buildDetailRow(
                  'Completed By:', widget.reservationDetails['completedBy']),
          ],

          if (widget.status == 'cancelled') ...[
            if (widget.reservationDetails['cancelledAt'] != null)
              _buildDetailRow('Cancelled At:',
                  _formatDate(widget.reservationDetails['cancelledAt'])),
            if (widget.reservationDetails['cancelledReason'] != null)
              _buildDetailRow('Cancellation Reason:',
                  widget.reservationDetails['cancelledReason']),
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

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';

    DateTime dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is DateTime) {
      dateTime = date;
    } else {
      return 'N/A';
    }

    return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
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
                          width: qrSize * 0.6,
                          height: qrSize * 0.6,
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
          _buildDetailRow('Amount:', '₱${_calculateTotalAmount()}'),
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
          _buildDetailRow('Amount Paid:', '₱${_calculateTotalAmount()}'),
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
          _buildDetailRow('Amount Paid:', '₱${_calculateTotalAmount()}'),
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
          if (widget.reservationDetails['rejectedAt'] != null)
            _buildDetailRow('Cancelled At:',
                _formatDate(widget.reservationDetails['rejectedAt'])),
          if (widget.reservationDetails['rejectedBy'] != null)
            _buildDetailRow(
                'Cancelled By:', widget.reservationDetails['rejectedBy']),
          if (widget.reservationDetails['rejectionReason'] != null)
            _buildDetailRow(
                'Reason:', widget.reservationDetails['rejectionReason']),
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

  int _calculateTotalAmount() {
    return widget.selectedBusIds.length * 2000;
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

      // Update the reservation details to reflect the new status
      widget.reservationDetails['status'] = 'receipt_uploaded';
      widget.reservationDetails['receiptUrl'] = downloadUrl;
      widget.reservationDetails['receiptUploadedAt'] =
          FieldValue.serverTimestamp();
    } catch (e) {
      _showCustomSnackBar('Error uploading receipt: $e', 'error');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
}
