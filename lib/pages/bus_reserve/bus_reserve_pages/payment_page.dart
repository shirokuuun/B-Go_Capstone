import 'package:b_go/pages/bus_reserve/bus_reserve_pages/bus_home.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:async';
import 'package:b_go/services/expired_reservation_service.dart';

class PaymentPage extends StatefulWidget {
  final String reservationId;
  final List<String> selectedBusIds;
  final Map<String, dynamic> reservationDetails;

  const PaymentPage({
    Key? key,
    required this.reservationId,
    required this.selectedBusIds,
    required this.reservationDetails,
  }) : super(key: key);

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  File? _receiptImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Start the expired reservation service if not already running
    if (!ExpiredReservationService.isRunning) {
      ExpiredReservationService.startService();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    
    // Responsive sizing
    final titleFontSize = isMobile ? 20.0 : isTablet ? 24.0 : 28.0;
    final subtitleFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final sectionFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final qrSize = isMobile ? 200.0 : isTablet ? 250.0 : 300.0;
    final horizontalPadding = isMobile ? 16.0 : isTablet ? 20.0 : 24.0;
    final verticalPadding = isMobile ? 12.0 : isTablet ? 16.0 : 20.0;
    
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
                'Payment',
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
                  
                  // Reservation Summary
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF0091AD).withOpacity(0.1),
                      border: Border.all(color: Color(0xFF0091AD).withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.receipt, color: Color(0xFF0091AD), size: 24),
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
                        _buildSummaryRow('From', widget.reservationDetails['from'] ?? 'N/A'),
                        _buildSummaryRow('To', widget.reservationDetails['to'] ?? 'N/A'),
                        _buildSummaryRow('Trip Type', widget.reservationDetails['isRoundTrip'] == true ? 'Round Trip' : 'One Way'),
                        _buildSummaryRow('Passenger', widget.reservationDetails['fullName'] ?? 'N/A'),
                        _buildSummaryRow('Email', widget.reservationDetails['email'] ?? 'N/A'),
                        _buildSummaryRow('Reservation ID', widget.reservationId),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Payment Instructions
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Payment Instructions',
                              style: GoogleFonts.outfit(
                                fontSize: sectionFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          '1. Scan the QR code below to make payment\n'
                          '2. Take a screenshot of your payment receipt\n'
                          '3. Upload the receipt using the button below\n'
                          '4. Wait for admin verification\n'
                          '5. You will receive confirmation once verified',
                          style: GoogleFonts.outfit(
                            fontSize: subtitleFontSize,
                            color: Colors.blue.shade800,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
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
                  Container(
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
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                  ),
                  
                  SizedBox(height: 24),
                  
                  // Status Information
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.orange.shade700, size: 24),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your reservation is pending payment verification. You will receive an email confirmation once verified by our admin.',
                            style: GoogleFonts.outfit(
                              fontSize: subtitleFontSize,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
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
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0091AD),
              minimumSize: Size(double.infinity, isMobile ? 45 : isTablet ? 50 : 55),
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => BusHome(),
                ),
              );
            },
            child: Text(
              'Back to Home',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: isMobile ? 16 : isTablet ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
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
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 12 : isTablet ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: isMobile ? 12 : isTablet ? 14 : 16,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _calculateTotalAmount() {
    // Calculate total based on number of selected buses
    // Each bus costs 2000 as defined in reservation_service.dart
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
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('receipts')
          .child('${widget.reservationId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
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

      _showCustomSnackBar('Receipt uploaded successfully! Admin will verify your payment.', 'success');

      // Clear the image after successful upload
      setState(() {
        _receiptImage = null;
      });

    } catch (e) {
      _showCustomSnackBar('Error uploading receipt: $e', 'error');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
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

}
