import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:b_go/pages/passenger/services/pre_ticket.dart';

class PreTicketQrs extends StatefulWidget {
  const PreTicketQrs({super.key});

  @override
  State<PreTicketQrs> createState() => _PreTicketQrsState();
}

class _PreTicketQrsState extends State<PreTicketQrs> with TickerProviderStateMixin {
  late Future<List<Map<String, dynamic>>> _ticketsFuture;
  late TabController _tabController;
  String _selectedFilter = 'all'; // 'all', 'pending', 'boarded', 'accomplished'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _ticketsFuture = _fetchAndCleanTickets();
    
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
              _selectedFilter = 'boarded';
              break;
            case 3:
              _selectedFilter = 'accomplished';
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

  Future<List<Map<String, dynamic>>> _fetchAndCleanTickets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('preTickets');
    
    // Calculate 30 days ago
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    
    // Clean up tickets older than 30 days (automatic deletion)
    try {
      final oldTicketsSnapshot = await col
          .where('createdAt', isLessThan: thirtyDaysAgo)
          .get();
      
      // Delete tickets older than 30 days
      for (var doc in oldTicketsSnapshot.docs) {
        await col.doc(doc.id).delete();
      }
      
      if (oldTicketsSnapshot.docs.isNotEmpty) {
        print('Cleaned up ${oldTicketsSnapshot.docs.length} tickets older than 30 days');
      }
    } catch (e) {
      print('Error cleaning up old tickets: $e');
    }
    
    // Fetch all remaining tickets (within 30 days)
    final snapshot = await col
        .where('createdAt', isGreaterThanOrEqualTo: thirtyDaysAgo)
        .orderBy('createdAt', descending: true)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  List<Map<String, dynamic>> _filterTickets(List<Map<String, dynamic>> tickets) {
    if (_selectedFilter == 'all') {
      return tickets;
    }
    return tickets.where((ticket) {
      final status = ticket['status'] ?? 'pending';
      return status == _selectedFilter;
    }).toList();
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
      
      setState(() {
        _ticketsFuture = _fetchAndCleanTickets();
      });
    } catch (e) {
      print('Error deleting ticket: $e');
      _showCustomSnackBar('Failed to delete ticket', 'error');
    }
  }

  void _showTicketDetails(Map<String, dynamic> ticket) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QRCodeFullScreenPage(
          from: ticket['from'] ?? '',
          to: ticket['to'] ?? '',
          km: ticket['km'] ?? '',
          fare: ticket['fare'] ?? '',
          quantity: ticket['quantity'] ?? 1,
          qrData: ticket['qrData'] ?? '',
          discountBreakdown: (ticket['discountBreakdown'] as List?)?.cast<String>(),
          showConfirmButton: false,
          route: ticket['route'] ?? 'Batangas',
        ),
      ),
    );
  }

  String _formatDate(dynamic createdAt) {
    if (createdAt == null) return 'Unknown date';
    
    DateTime date;
    if (createdAt is Timestamp) {
      date = createdAt.toDate();
    } else if (createdAt is DateTime) {
      date = createdAt;
    } else {
      return 'Unknown date';
    }
    
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else if (difference < 30) {
      final weeks = (difference / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
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
          'Pre-Ticket History',
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
            Tab(text: 'Boarded'),
            Tab(text: 'Accomplished'),
          ],
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final allTickets = snapshot.data ?? [];
          final filteredTickets = _filterTickets(allTickets);
          
          if (filteredTickets.isEmpty) {
            String emptyMessage = 'No pre-tickets found.';
            if (_selectedFilter != 'all') {
              emptyMessage = 'No $_selectedFilter pre-tickets found.';
            }
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
                  if (_selectedFilter == 'all')
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
          
          return TabBarView(
            controller: _tabController,
            children: List.generate(4, (index) {
              String filter = ['all', 'pending', 'boarded', 'accomplished'][index];
              List<Map<String, dynamic>> tickets = filter == 'all' ? allTickets : allTickets.where((ticket) {
                final status = ticket['status'] ?? 'pending';
                return status == filter;
              }).toList();
              
              if (tickets.isEmpty) {
                String emptyMessage = 'No pre-tickets found.';
                if (filter != 'all') {
                  emptyMessage = 'No $filter pre-tickets found.';
                }
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
                    ],
                  ),
                );
              }
              
              return ListView.separated(
                padding: EdgeInsets.all(width * 0.05),
                itemCount: tickets.length,
                separatorBuilder: (_, __) => SizedBox(height: width * 0.04),
                itemBuilder: (context, i) {
                  final t = tickets[i];
                  return Dismissible(
                    key: Key(t['id'] ?? i.toString()),
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
                          title: Text(
                            'Delete Ticket', 
                            style: GoogleFonts.outfit(fontSize: 20)
                          ),
                          content: Text(
                            'Are you sure you want to delete this ticket? This action cannot be undone.',
                            style: GoogleFonts.outfit(fontSize: 14)
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: Colors.grey[600]
                                )
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text(
                                'Delete',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  color: Colors.red
                                )
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) async {
                      await _deleteTicket(t['id']);
                      _showCustomSnackBar('Ticket deleted successfully', 'success');
                    },
                    child: GestureDetector(
                      onTap: () => _showTicketDetails(t),
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
                            QrImageView(
                              data: t['qrData'] ?? '',
                              size: width * 0.18,
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${t['from']} → ${t['to']}',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Total Fare: ${t['totalFare'] ?? t['fare']} PHP',
                                    style: GoogleFonts.outfit(fontSize: 14)
                                  ),
                                  Text(
                                    'Passengers: ${t['quantity']}',
                                    style: GoogleFonts.outfit(fontSize: 14)
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(t['status'] ?? 'pending'),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${t['status'] ?? 'pending'}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        _formatDate(t['createdAt']),
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: Colors.grey[600],
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
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'boarded':
        return Colors.blue;
      case 'accomplished':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}