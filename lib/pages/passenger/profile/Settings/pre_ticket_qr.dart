import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:b_go/pages/passenger/services/pre_ticket.dart';

class PreTicketQrs extends StatefulWidget {
  const PreTicketQrs({super.key});

  @override
  State<PreTicketQrs> createState() => _PreTicketQrsState();
}

class _PreTicketQrsState extends State<PreTicketQrs> with TickerProviderStateMixin {
  late Stream<List<Map<String, dynamic>>> _ticketsStream;
  late TabController _tabController;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _ticketsStream = _fetchTicketsStream();
    
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
              _selectedFilter = 'boarded';
              break;
            case 3:
              _selectedFilter = 'accomplished';
              break;
            case 4:
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

  Stream<List<Map<String, dynamic>>> _fetchTicketsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);
    
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('preTickets');
    
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    
    return col
        .where('createdAt', isGreaterThanOrEqualTo: thirtyDaysAgo)
        .snapshots()
        .map((snapshot) {
      final tickets = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          })
          .toList()
        ..sort((a, b) => (b['createdAt'] as Timestamp)
            .compareTo(a['createdAt'] as Timestamp));
      
      return tickets;
    });
  }

  Future<void> _deleteTicket(String ticketId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preTickets');
      
      await col.doc(ticketId).delete();
    } catch (e) {
      print('Error deleting ticket: $e');
      _showCustomSnackBar('Failed to delete ticket', 'error');
    }
  }

  Future<void> _cancelTicket(String ticketId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preTickets');
      
      await col.doc(ticketId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      
      _showCustomSnackBar('Ticket cancelled successfully', 'success');
    } catch (e) {
      print('Error cancelling ticket: $e');
      _showCustomSnackBar('Failed to cancel ticket', 'error');
    }
  }

  void _showTicketDetails(Map<String, dynamic> ticket) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TicketDetailsPage(
          ticket: ticket,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'boarded':
        return Colors.blue;
      case 'accomplished':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'PENDING';
      case 'boarded':
        return 'BOARDED';
      case 'accomplished':
        return 'ACCOMPLISHED';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return 'UNKNOWN';
    }
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
          'Pre-Ticket History',
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
            Tab(text: 'Boarded'),
            Tab(text: 'Accomplished'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _ticketsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final allTickets = snapshot.data ?? [];
          
          return TabBarView(
            controller: _tabController,
            children: List.generate(5, (index) {
              String filter = ['all', 'pending', 'boarded', 'accomplished', 'cancelled'][index];
              
              List<Map<String, dynamic>> tickets;
              if (filter == 'all') {
                tickets = allTickets;
              } else {
                tickets = allTickets.where((t) {
                  final status = (t['status'] ?? 'pending').toString().toLowerCase();
                  return status == filter;
                }).toList();
              }
              
              if (tickets.isEmpty) {
                String emptyMessage = filter == 'all' 
                    ? 'No pre-tickets found.'
                    : 'No $filter pre-tickets found.';
                    
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
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
                            'Tickets are automatically deleted after 30 days',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }
              
              return ListView.separated(
                padding: EdgeInsets.all(horizontalPadding),
                itemCount: tickets.length,
                separatorBuilder: (_, __) => SizedBox(height: cardPadding),
                itemBuilder: (context, i) {
                  final ticket = tickets[i];
                  final status = (ticket['status'] ?? 'pending').toString().toLowerCase();

                  return Dismissible(
                    key: Key(ticket['id'] ?? i.toString()),
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
                          title: Text('Delete Ticket',
                              style: GoogleFonts.outfit(fontSize: 20)),
                          content: Text(
                              'Are you sure you want to delete this ticket?',
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
                      await _deleteTicket(ticket['id']);
                      _showCustomSnackBar('Ticket deleted', 'success');
                    },
                    child: GestureDetector(
                      onTap: () => _showTicketDetails(ticket),
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
                                Icons.receipt_long,
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
                                    '${ticket['from']} → ${ticket['to']}',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Route: ${ticket['route'] ?? 'Batangas'}',
                                    style: GoogleFonts.outfit(
                                        fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  Text(
                                    'Total Fare: ${ticket['totalFare'] ?? ticket['fare']} PHP',
                                    style: GoogleFonts.outfit(fontSize: 14),
                                  ),
                                  Text(
                                    'Passengers: ${ticket['quantity']}',
                                    style: GoogleFonts.outfit(fontSize: 14),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(status),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          _getStatusText(status),
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

class TicketDetailsPage extends StatelessWidget {
  final Map<String, dynamic> ticket;

  const TicketDetailsPage({
    Key? key,
    required this.ticket,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final qrData = ticket['qrData'] ?? '{}';
    final status = (ticket['status'] ?? 'pending').toString().toLowerCase();
    final isBoarded = status == 'boarded';
    final isAccomplished = status == 'accomplished';
    final isCancelled = status == 'cancelled';
    final isPending = status == 'pending';

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
          'Pre-Ticket Details',
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
                         isBoarded ? Colors.blue[100] : 
                         isPending ? Colors.orange[100] : Colors.green[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCancelled ? Icons.cancel :
                  isAccomplished ? Icons.flag_circle :
                  isBoarded ? Icons.directions_bus :
                  isPending ? Icons.pending : Icons.check_circle,
                  color: isCancelled ? Colors.red[600] :
                         isAccomplished ? Colors.purple[600] :
                         isBoarded ? Colors.blue[600] :
                         isPending ? Colors.orange[600] : Colors.green[600],
                  size: 50,
                ),
              ),
              SizedBox(height: 16),
              Text(
                isCancelled ? 'Ticket Cancelled' :
                isAccomplished ? 'Journey Completed!' :
                isBoarded ? 'Successfully Boarded!' :
                isPending ? 'Ticket Pending' : 'Ticket Confirmed!',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isCancelled ? Colors.red[700] :
                         isAccomplished ? Colors.purple[700] :
                         isBoarded ? Colors.blue[700] :
                         isPending ? Colors.orange[700] : Colors.green[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                isCancelled ? ''
                : isAccomplished ? 'You have successfully completed your journey'
                : isBoarded 
                  ? 'You have successfully boarded the bus'
                  : isPending 
                    ? 'Your ticket is waiting to be scanned'
                    : 'Your pre-ticket has been confirmed',
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
                         isBoarded ? Colors.blue[50] :
                         isPending ? Colors.orange[50] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isCancelled ? Colors.red[200]! :
                                    isAccomplished ? Colors.purple[200]! :
                                    isBoarded ? Colors.blue[200]! :
                                    isPending ? Colors.orange[200]! : Colors.grey[300]!),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isCancelled ? 'Ticket Cancelled' :
                      isAccomplished ? 'Journey Completed' :
                      isBoarded ? 'Boarding Confirmed' :
                      isPending ? 'Boarding QR Code' : 'Boarding QR Code',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isCancelled ? Colors.red[700] :
                               isAccomplished ? Colors.purple[700] :
                               isBoarded ? Colors.blue[700] :
                               isPending ? Colors.orange[700] : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      isCancelled ? 'This ticket was cancelled'
                      : isAccomplished ? 'Your journey has been completed successfully'
                      : isBoarded 
                        ? 'This QR code has been scanned and validated'
                        : 'Show this to the conductor when boarding',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: isCancelled ? Colors.red[600] :
                               isAccomplished ? Colors.purple[600] :
                               isBoarded ? Colors.blue[600] :
                               isPending ? Colors.orange[600] : Colors.grey[600],
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
                                            isBoarded ? Colors.blue[200]! :
                                            isPending ? Colors.orange[200]! : Colors.grey[300]!),
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

              // Ticket Details
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
                      'Ticket Details',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildDetailRow('Route:', ticket['route'] ?? 'Batangas'),
                    _buildDetailRow('From:', ticket['from'] ?? ''),
                    _buildDetailRow('To:', ticket['to'] ?? ''),
                    _buildDetailRow('Distance:', '${ticket['km'] ?? ''} km'),
                    _buildDetailRow('Quantity:', '${ticket['quantity']}'),
                    _buildDetailRow('Total Fare:',
                        '${ticket['totalFare'] ?? ticket['fare'] ?? '0.00'} PHP'),
                    _buildDetailRow('Status:', _getStatusText(status)),
                    if (isCancelled && ticket['cancelledAt'] != null)
                      _buildDetailRow('Cancelled Date:', _formatDate(ticket['cancelledAt']))
                    else if (isAccomplished && ticket['accomplishedAt'] != null)
                      _buildDetailRow('Completed Date:', _formatDate(ticket['accomplishedAt']))
                    else if (isBoarded && ticket['boardedAt'] != null)
                      _buildDetailRow('Boarded Date:', _formatDate(ticket['boardedAt']))
                    else if (ticket['createdAt'] != null)
                      _buildDetailRow('Created Date:', _formatDate(ticket['createdAt'])),
                    SizedBox(height: 16),

                    // Passenger Details
                    if (ticket['discountBreakdown'] != null) ...[
                      Text(
                        'Passenger Details',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      ...(ticket['discountBreakdown'] as List<dynamic>? ?? [])
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
                         isBoarded ? Colors.green[50] :
                         isPending ? Colors.orange[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isCancelled ? Colors.red[200]! :
                                    isAccomplished ? Colors.purple[200]! :
                                    isBoarded ? Colors.green[200]! :
                                    isPending ? Colors.orange[200]! : Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCancelled ? Icons.cancel :
                          isAccomplished ? Icons.flag_circle :
                          isBoarded ? Icons.check_circle :
                          isPending ? Icons.pending : Icons.info, 
                          color: isCancelled ? Colors.red[700] :
                                 isAccomplished ? Colors.purple[700] :
                                 isBoarded ? Colors.green[700] :
                                 isPending ? Colors.orange[700] : Colors.blue[700], 
                          size: 20
                        ),
                        SizedBox(width: 8),
                        Text(
                          isCancelled ? 'Ticket Cancelled' :
                          isAccomplished ? 'Journey Completed' :
                          isBoarded ? 'Boarding Complete' :
                          isPending ? 'Pending Scan' : 'Important Notes',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isCancelled ? Colors.red[700] :
                                   isAccomplished ? Colors.purple[700] :
                                   isBoarded ? Colors.green[700] :
                                   isPending ? Colors.orange[700] : Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    if (isCancelled) ...[
                      Text(
                        '• This ticket was cancelled',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: Colors.red[700]),
                      ),
                      Text(
                        '• Please create a new ticket for your next trip',
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
                    ] else if (isPending) ...[
                      Text(
                        '• Show this QR code to the conductor when boarding',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: Colors.orange[700]),
                      ),
                      Text(
                        '• Make sure the conductor scans your ticket',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: Colors.orange[700]),
                      ),
                      Text(
                        '• Keep this ticket until journey completion',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: Colors.orange[700]),
                      ),
                    ] else ...[
                      Text(
                        '• Show this QR code to the conductor when boarding',
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: Colors.blue[700]),
                      ),
                      Text(
                        '• Your ticket is valid for boarding',
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

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'PENDING';
      case 'boarded':
        return 'BOARDED';
      case 'accomplished':
        return 'ACCOMPLISHED';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return 'UNKNOWN';
    }
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