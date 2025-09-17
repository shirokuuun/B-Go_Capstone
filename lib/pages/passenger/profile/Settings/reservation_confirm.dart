import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:b_go/pages/passenger/services/pre_book.dart';

class ReservationConfirm extends StatefulWidget {
  const ReservationConfirm({super.key});

  @override
  State<ReservationConfirm> createState() => _ReservationConfirmState();
}

class _ReservationConfirmState extends State<ReservationConfirm> with TickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _bookingsFuture;
  late TabController _tabController;
  String _selectedFilter = 'all'; // 'all', 'pending', 'paid', 'boarded'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _bookingsFuture = _fetchAllBookings();
    
    // Listen to tab changes
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          switch (_tabController.index) {
            case 0:
              _selectedFilter = 'all';
              break;
            case 1:
              _selectedFilter = 'pending';
              break;
            case 2:
              _selectedFilter = 'paid';
              break;
            case 3:
              _selectedFilter = 'boarded';
              break;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchAllBookings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('preBookings');

    // Get all pre-bookings and filter in memory to avoid index requirements
    final snapshot = await col.get();

    final allBookings = snapshot.docs
        .where((doc) =>
            doc.data()['status'] == 'paid' ||
            doc.data()['status'] == 'pending_payment')
        .toList()
      ..sort((a, b) => (b.data()['createdAt'] as Timestamp)
          .compareTo(a.data()['createdAt'] as Timestamp));

    return allBookings.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  List<Map<String, dynamic>> _filterBookings(List<Map<String, dynamic>> bookings) {
    if (_selectedFilter == 'all') {
      return bookings;
    }
    return bookings.where((booking) {
      final status = booking['status'] ?? 'pending_payment';
      final boardingStatus = booking['boardingStatus'] ?? 'pending';
      
      switch (_selectedFilter) {
        case 'pending':
          return status == 'pending_payment';
        case 'paid':
          return status == 'paid' && boardingStatus == 'pending';
        case 'boarded':
          return status == 'paid' && boardingStatus == 'boarded';
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _deleteBooking(String bookingId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('preBookings');

    await col.doc(bookingId).delete();
    setState(() {
      _bookingsFuture = _fetchAllBookings();
    });
  }

  void _showBookingDetails(Map<String, dynamic> booking) {
    if (booking['status'] == 'pending_payment') {
      // For pending bookings, show a dialog to go back to payment
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title:
              Text('Pending Payment', style: GoogleFonts.outfit(fontSize: 20)),
          content: Text(
            'This booking is still pending payment. Would you like to go back to complete the payment?',
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel',
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Navigate to the payment page with the booking details
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => PreBookSummaryPage(
                      bookingId: booking['id'] ?? '',
                      route: booking['route'],
                      directionLabel: booking['direction'],
                      fromPlace: {
                        'name': booking['from'],
                        'km': booking['fromKm']?.toDouble() ?? 0.0,
                      },
                      toPlace: {
                        'name': booking['to'],
                        'km': booking['toKm']?.toDouble() ?? 0.0,
                      },
                      quantity: booking['quantity'],
                      fareTypes: List<String>.from(booking['fareTypes'] ?? []),
                      baseFare: booking['fare']?.toDouble() ?? 0.0,
                      totalAmount: booking['amount']?.toDouble() ?? 0.0,
                      discountBreakdown:
                          List<String>.from(booking['discountBreakdown'] ?? []),
                      passengerFares:
                          List<double>.from(booking['passengerFares'] ?? []),
                      paymentDeadline: booking['paymentDeadline'] != null 
                          ? (booking['paymentDeadline'] as Timestamp).toDate()
                          : null,
                    ),
                  ),
                );
              },
              child: Text('Go Back',
                  style: GoogleFonts.outfit(fontSize: 14, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0091AD),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } else {
      // For paid bookings, show the details page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BookingDetailsPage(
            booking: booking,
          ),
        ),
      );
    }
  }


  Color _getStatusColor(String status, String boardingStatus) {
    if (status == 'pending_payment') {
      return Colors.orange;
    } else if (status == 'paid' && boardingStatus == 'boarded') {
      return Colors.blue;
    } else if (status == 'paid') {
      return Colors.green;
    }
    return Colors.grey;
  }

  String _getStatusText(String status, String boardingStatus) {
    if (status == 'pending_payment') {
      return 'PENDING';
    } else if (status == 'paid' && boardingStatus == 'boarded') {
      return 'BOARDED';
    } else if (status == 'paid') {
      return 'PAID';
    }
    return 'UNKNOWN';
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0091AD),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          'Reservation Confirmations',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 20,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          tabs: [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Paid'),
            Tab(text: 'Boarded'),
          ],
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final allBookings = snapshot.data ?? [];
          
          return TabBarView(
            controller: _tabController,
            children: List.generate(4, (index) {
              String filter = ['all', 'pending', 'paid', 'boarded'][index];
              List<Map<String, dynamic>> bookings = _filterBookings(allBookings);
              
              if (bookings.isEmpty) {
                String emptyMessage = 'No reservations found.';
                if (filter != 'all') {
                  emptyMessage = 'No $filter reservations found.';
                }
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.confirmation_number_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        emptyMessage,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (filter == 'all')
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Your paid and pending pre-bookings will appear here.',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                );
              }
              
              return ListView.separated(
                padding: EdgeInsets.all(width * 0.05),
                itemCount: bookings.length,
                separatorBuilder: (_, __) => SizedBox(height: width * 0.04),
                itemBuilder: (context, i) {
                  final booking = bookings[i];
                  final boardingStatus = booking['boardingStatus'] ?? 'pending';

                  return Dismissible(
                    key: Key(booking['id'] ?? i.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      color: Colors.red,
                      child: Icon(Icons.delete, color: Colors.white, size: 32),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Delete Reservation',
                              style: GoogleFonts.outfit(fontSize: 20)),
                          content: Text(
                              'Are you sure you want to delete this reservation?',
                              style: GoogleFonts.outfit(fontSize: 14)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text('Cancel',
                                  style: GoogleFonts.outfit(
                                      fontSize: 14, color: Colors.grey[600])),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text('Delete',
                                  style: GoogleFonts.outfit(
                                      fontSize: 14, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) async {
                      await _deleteBooking(booking['id']);
                      _showCustomSnackBar('Reservation deleted', 'success');
                    },
                    child: GestureDetector(
                      onTap: () => _showBookingDetails(booking),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                        child: Row(
                          children: [
                            Container(
                              width: width * 0.18,
                              height: width * 0.18,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.confirmation_number,
                                size: width * 0.08,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${booking['from']} → ${booking['to']}',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Route: ${booking['route']}',
                                    style: GoogleFonts.outfit(
                                        fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  Text(
                                    'Total Amount: ${booking['amount']?.toStringAsFixed(2) ?? '0.00'} PHP',
                                    style: GoogleFonts.outfit(fontSize: 14),
                                  ),
                                  Text(
                                    'Passengers: ${booking['quantity']}',
                                    style: GoogleFonts.outfit(fontSize: 14),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(booking['status'] ?? 'pending_payment', boardingStatus),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _getStatusText(booking['status'] ?? 'pending_payment', boardingStatus),
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      if (boardingStatus == 'boarded') ...[
                                        SizedBox(width: 8),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'BOARDED',
                                            style: GoogleFonts.outfit(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: Colors.grey, size: 28),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          );
        },
      ),
    );
  }
}

class BookingDetailsPage extends StatelessWidget {
  final Map<String, dynamic> booking;

  const BookingDetailsPage({
    Key? key,
    required this.booking,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use the stored qrData from Firebase, which contains the proper JSON format
    final qrData = booking['qrData'] ?? '{}';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0091AD),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Reservation Details',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Success Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green[600],
                  size: 50,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Reservation Confirmed!',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your pre-booking has been paid and confirmed',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),

              // QR Code Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Boarding QR Code',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Show this to the conductor when boarding',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    Center(
                      child: Container(
                        width: 350.0,
                        height: 350.0,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: QrImageView(
                          data: qrData, // Use the stored qrData from Firebase
                          version: QrVersions.auto,
                          size: 218.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Booking Details
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking Details',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildDetailRow('Route:', booking['route'] ?? ''),
                    _buildDetailRow('Direction:', booking['direction'] ?? ''),
                    _buildDetailRow('From:', booking['from'] ?? ''),
                    _buildDetailRow('To:', booking['to'] ?? ''),
                    _buildDetailRow('From KM:', '${booking['fromKm']}'),
                    _buildDetailRow('To KM:', '${booking['toKm']}'),
                    _buildDetailRow('Quantity:', '${booking['quantity']}'),
                    _buildDetailRow('Total Amount:',
                        '${booking['amount']?.toStringAsFixed(2) ?? '0.00'} PHP'),
                    _buildDetailRow('Status:', 'PAID'),
                    // Show paid date if status is paid, or created date if pending
                    if (booking['status'] == 'paid' && booking['paidDate'] != null)
                      _buildDetailRow('Paid Date:', _formatDate(booking['paidDate']))
                    else if (booking['status'] == 'pending_payment' && booking['createdAt'] != null)
                      _buildDetailRow('Created Date:', _formatDate(booking['createdAt'])),
                    SizedBox(height: 16),

                    // Passenger Details
                    Text(
                      'Passenger Details',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    ...(booking['discountBreakdown'] as List<dynamic>? ?? [])
                        .map(
                      (detail) => Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          detail.toString(),
                          style: GoogleFonts.outfit(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Important Notes
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700], size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Important Notes',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '• The conductor will see your booking on their map',
                      style: GoogleFonts.outfit(
                          fontSize: 14, color: Colors.blue[700]),
                    ),
                    Text(
                      '• Your seats are guaranteed for this trip',
                      style: GoogleFonts.outfit(
                          fontSize: 14, color: Colors.blue[700]),
                    ),
                    Text(
                      '• Keep this confirmation for your records',
                      style: GoogleFonts.outfit(
                          fontSize: 14, color: Colors.blue[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    
    return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
}
