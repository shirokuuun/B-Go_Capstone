import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:b_go/pages/passenger/services/pre_book.dart';

class ReservationConfirm extends StatefulWidget {
  const ReservationConfirm({super.key});

  @override
  State<ReservationConfirm> createState() => _ReservationConfirmState();
}

class _ReservationConfirmState extends State<ReservationConfirm> with TickerProviderStateMixin {
  late Stream<List<Map<String, dynamic>>> _bookingsStream;
  late TabController _tabController;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _bookingsStream = _fetchAllBookingsStream();
    
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
            case 4:
              _selectedFilter = 'accomplished';
              break;
            case 5:
              _selectedFilter = 'cancelled';
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

  Stream<List<Map<String, dynamic>>> _fetchAllBookingsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('preBookings');

    // Use snapshots() for real-time updates
    return col.snapshots().map((snapshot) {
      final allBookings = snapshot.docs
          .where((doc) =>
              doc.data()['status'] == 'paid' ||
              doc.data()['status'] == 'pending_payment' ||
              doc.data()['status'] == 'boarded' ||
              doc.data()['status'] == 'accomplished' ||
              doc.data()['status'] == 'cancelled')
          .toList()
        ..sort((a, b) => (b.data()['createdAt'] as Timestamp)
            .compareTo(a.data()['createdAt'] as Timestamp));

      return allBookings.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;

        // Debug logging
        print('📋 Pre-booking ${doc.id}: status=${data['status']}');

        return data;
      }).toList();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchAllBookings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('preBookings');

    final snapshot = await col.get();

    final allBookings = snapshot.docs
        .where((doc) =>
            doc.data()['status'] == 'paid' ||
            doc.data()['status'] == 'pending_payment' ||
            doc.data()['status'] == 'boarded' ||
            doc.data()['status'] == 'accomplished' ||
            doc.data()['status'] == 'cancelled')
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
      
      switch (_selectedFilter) {
        case 'pending':
          return status == 'pending_payment';
        case 'paid':
          return status == 'paid';
        case 'boarded':
          return status == 'boarded';
        case 'accomplished':
          return status == 'accomplished';
        case 'cancelled':
          return status == 'cancelled';
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
      _bookingsStream = _fetchAllBookingsStream();
    });
  }

  void _showBookingDetails(Map<String, dynamic> booking) {
    if (booking['status'] == 'pending_payment') {
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
                Navigator.of(context).pop();
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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BookingDetailsPage(
            booking: booking,
          ),
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_payment':
        return Colors.orange;
      case 'boarded':
        return Colors.blue;
      case 'paid':
        return Colors.green;
      case 'accomplished':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending_payment':
        return 'PENDING';
      case 'boarded':
        return 'BOARDED';
      case 'paid':
        return 'PAID';
      case 'accomplished':
        return 'ACCOMPLISHED';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return 'UNKNOWN';
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

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    final appBarFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final tabFontSize = isMobile ? 12.0 : isTablet ? 14.0 : 16.0;
    final cardPadding = isMobile ? 12.0 : isTablet ? 16.0 : 20.0;
    final horizontalPadding = isMobile ? 16.0 : isTablet ? 20.0 : 24.0;

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
            fontSize: appBarFontSize,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          labelStyle: GoogleFonts.outfit(fontSize: tabFontSize),
          unselectedLabelStyle: GoogleFonts.outfit(fontSize: tabFontSize),
          tabs: [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Paid'),
            Tab(text: 'Boarded'),
            Tab(text: 'Accomplished'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _bookingsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final allBookings = snapshot.data ?? [];
          
          return TabBarView(
            controller: _tabController,
            children: List.generate(6, (index) {
              String filter = ['all', 'pending', 'paid', 'boarded', 'accomplished', 'cancelled'][index];
              
              // Filter bookings for current tab
              List<Map<String, dynamic>> bookings;
              if (filter == 'all') {
                bookings = allBookings;
              } else {
                String statusToMatch;
                switch (filter) {
                  case 'pending':
                    statusToMatch = 'pending_payment';
                    break;
                  case 'accomplished':
                    statusToMatch = 'accomplished';
                    break;
                  default:
                    statusToMatch = filter;
                }
                bookings = allBookings.where((b) => b['status'] == statusToMatch).toList();
              }
              
              if (bookings.isEmpty) {
                String emptyMessage = filter == 'all' 
                    ? 'No reservations found.'
                    : 'No $filter reservations found.';
                    
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
                padding: EdgeInsets.all(horizontalPadding),
                itemCount: bookings.length,
                separatorBuilder: (_, __) => SizedBox(height: cardPadding),
                itemBuilder: (context, i) {
                  final booking = bookings[i];

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
                        padding: EdgeInsets.symmetric(vertical: cardPadding, horizontal: cardPadding),
                        child: Row(
                          children: [
                            Container(
                              width: isMobile ? 60.0 : isTablet ? 70.0 : 80.0,
                              height: isMobile ? 60.0 : isTablet ? 70.0 : 80.0,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.confirmation_number,
                                size: isMobile ? 24.0 : isTablet ? 28.0 : 32.0,
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
                                          color: _getStatusColor(booking['status'] ?? 'pending_payment'),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _getStatusText(booking['status'] ?? 'pending_payment'),
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
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
    final qrData = booking['qrData'] ?? '{}';
    final status = booking['status'] ?? 'paid';
    final isBoarded = status == 'boarded';
    final isAccomplished = status == 'accomplished';
    final isCancelled = status == 'cancelled';

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
              // Status Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isCancelled ? Colors.red[100] :
                         isAccomplished ? Colors.purple[100] : 
                         isBoarded ? Colors.blue[100] : Colors.green[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCancelled ? Icons.cancel :
                  isAccomplished ? Icons.flag_circle :
                  isBoarded ? Icons.directions_bus : Icons.check_circle,
                  color: isCancelled ? Colors.red[600] :
                         isAccomplished ? Colors.purple[600] :
                         isBoarded ? Colors.blue[600] : Colors.green[600],
                  size: 50,
                ),
              ),
              SizedBox(height: 16),
              Text(
                isCancelled ? 'Reservation Cancelled' :
                isAccomplished ? 'Journey Completed!' :
                isBoarded ? 'Successfully Boarded!' : 'Reservation Confirmed!',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isCancelled ? Colors.red[700] :
                         isAccomplished ? Colors.purple[700] :
                         isBoarded ? Colors.blue[700] : Colors.green[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                isCancelled ? ''
                : isAccomplished ? 'You have successfully completed your journey'
                : isBoarded 
                  ? 'You have successfully boarded the bus'
                  : 'Your pre-booking has been paid and confirmed',
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
                  color: isCancelled ? Colors.red[50] :
                         isAccomplished ? Colors.purple[50] :
                         isBoarded ? Colors.blue[50] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isCancelled ? Colors.red[200]! :
                                    isAccomplished ? Colors.purple[200]! :
                                    isBoarded ? Colors.blue[200]! : Colors.grey[300]!),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isCancelled ? 'Reservation Cancelled' :
                      isAccomplished ? 'Journey Completed' :
                      isBoarded ? 'Boarding Confirmed' : 'Boarding QR Code',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isCancelled ? Colors.red[700] :
                               isAccomplished ? Colors.purple[700] :
                               isBoarded ? Colors.blue[700] : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      isCancelled ? 'This reservation was cancelled because the trip ended and you did not board the bus'
                      : isAccomplished ? 'Your journey has been completed successfully'
                      : isBoarded 
                        ? 'This QR code has been scanned and validated'
                        : 'Show this to the conductor when boarding',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: isCancelled ? Colors.red[600] :
                               isAccomplished ? Colors.purple[600] :
                               isBoarded ? Colors.blue[600] : Colors.grey[600],
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
                          border: Border.all(color: isCancelled ? Colors.red[200]! :
                                            isAccomplished ? Colors.purple[200]! :
                                            isBoarded ? Colors.blue[200]! : Colors.grey[300]!),
                        ),
                        child: isCancelled
                          ? Stack(
                              children: [
                                QrImageView(
                                  data: qrData,
                                  version: QrVersions.auto,
                                  size: 350.0,
                                  backgroundColor: Colors.white,
                                ),
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.cancel,
                                            color: Colors.white,
                                            size: 60,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'CANCELLED',
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : isAccomplished 
                            ? Stack(
                                children: [
                                  QrImageView(
                                    data: qrData,
                                    version: QrVersions.auto,
                                    size: 350.0,
                                    backgroundColor: Colors.white,
                                  ),
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.flag_circle,
                                              color: Colors.white,
                                              size: 60,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'COMPLETED',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : isBoarded 
                              ? Stack(
                                  children: [
                                    QrImageView(
                                      data: qrData,
                                      version: QrVersions.auto,
                                      size: 350.0,
                                      backgroundColor: Colors.white,
                                    ),
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                                size: 60,
                                              ),
                                              SizedBox(height: 8),
                                              Text(
                                                'SCANNED',
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : QrImageView(
                                  data: qrData,
                                  version: QrVersions.auto,
                                  size: 350.0,
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
                    _buildDetailRow('Status:', isCancelled ? 'CANCELLED' :
                                           isAccomplished ? 'ACCOMPLISHED' : 
                                           isBoarded ? 'BOARDED' : 'PAID'),
                    // Show different dates based on status
                    if (isCancelled) ...[
                      if (booking['cancelledAt'] != null)
                        _buildDetailRow('Cancelled Date:', _formatDate(booking['cancelledAt'])),
                      if (booking['cancelledReason'] != null)
                        _buildDetailRow('Cancellation Reason:', booking['cancelledReason']),
                    ] else if (isAccomplished) ...[
                      if (booking['dropOffTimestamp'] != null)
                        _buildDetailRow('Completed Date:', _formatDate(booking['dropOffTimestamp'])),
                      if (booking['dropOffLocation'] != null)
                        _buildDetailRow('Drop-off Location:', 'Recorded'),
                    ] else if (isBoarded) ...[
                      if (booking['boardedAt'] != null)
                        _buildDetailRow('Boarded Date:', _formatDate(booking['boardedAt'])),
                      if (booking['scannedBy'] != null)
                        _buildDetailRow('Scanned By:', 'Conductor'),
                    ] else if (booking['status'] == 'paid' && booking['paidDate'] != null)
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
                  color: isCancelled ? Colors.red[50] :
                         isAccomplished ? Colors.purple[50] :
                         isBoarded ? Colors.green[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isCancelled ? Colors.red[200]! :
                                    isAccomplished ? Colors.purple[200]! :
                                    isBoarded ? Colors.green[200]! : Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCancelled ? Icons.cancel :
                          isAccomplished ? Icons.flag_circle :
                          isBoarded ? Icons.check_circle : Icons.info, 
                          color: isCancelled ? Colors.red[700] :
                                 isAccomplished ? Colors.purple[700] :
                                 isBoarded ? Colors.green[700] : Colors.blue[700], 
                          size: 20
                        ),
                        SizedBox(width: 8),
                        Text(
                          isCancelled ? 'Reservation Cancelled' :
                          isAccomplished ? 'Journey Completed' :
                          isBoarded ? 'Boarding Complete' : 'Important Notes',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isCancelled ? Colors.red[700] :
                                   isAccomplished ? Colors.purple[700] :
                                   isBoarded ? Colors.green[700] : Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    if (isCancelled) ...[
                      Text(
                        '• This reservation was cancelled because the trip ended',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: Colors.red[700]),
                      ),
                      Text(
                        '• You did not board the bus before the trip ended',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: Colors.red[700]),
                      ),
                      Text(
                        '• Please make a new reservation for your next trip',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: Colors.red[700]),
                      ),
                    ] else if (isAccomplished) ...[
                      Text(
                        '• You have successfully completed your journey',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: Colors.purple[700]),
                      ),
                      Text(
                        '• Thank you for using our service',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: Colors.purple[700]),
                      ),
                      Text(
                        '• We hope you had a pleasant trip!',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: Colors.purple[700]),
                      ),
                    ] else if (isBoarded) ...[
                      Text(
                        '• You have successfully boarded the bus',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: Colors.green[700]),
                      ),
                      Text(
                        '• Your seat is confirmed and reserved',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: Colors.green[700]),
                      ),
                      Text(
                        '• Enjoy your journey!',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: Colors.green[700]),
                      ),
                    ] else ...[
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