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

  Future<List<Map<String, dynamic>>> _fetchAndCleanTickets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final now = DateTime.now(); // Use device local time
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('preTickets');
    
    // Only fetch tickets for today
    final snapshot = await col
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThan: endOfDay)
        .get();
    
    // Clean up old tickets from previous days (not current day)
    final yesterday = startOfDay.subtract(const Duration(days: 1));
    final oldTicketsSnapshot = await col
        .where('createdAt', isLessThan: startOfDay)
        .get();
    
    // Delete tickets from previous days
    for (var doc in oldTicketsSnapshot.docs) {
      await col.doc(doc.id).delete();
    }
    
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
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('preTickets');
    await col.doc(ticketId).delete();
    setState(() {
      _ticketsFuture = _fetchAndCleanTickets();
    });
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
          'Pre-Ticket QRs',
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
              child: Text(emptyMessage,
                  style: GoogleFonts.outfit(fontSize: 16)),
            );
          }
          
          return TabBarView(
            controller: _tabController,
            children: List.generate(4, (index) {
              String filter = ['all', 'pending', 'boarded', 'accomplished'][index];
              List<Map<String, dynamic>> tickets = filter == 'all' ? allTickets : _filterTickets(allTickets);
              
              if (tickets.isEmpty) {
                String emptyMessage = 'No pre-tickets found.';
                if (filter != 'all') {
                  emptyMessage = 'No $filter pre-tickets found.';
                }
                return Center(
                  child: Text(emptyMessage,
                      style: GoogleFonts.outfit(fontSize: 16)),
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
                          title: Text('Delete Ticket'),
                          content: Text('Are you sure you want to delete this ticket?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) async {
                      await _deleteTicket(t['id']);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ticket deleted')),
                      );
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
                                  Text('Total Fare: ${t['totalFare'] ?? t['fare']} PHP',
                                      style: GoogleFonts.outfit(fontSize: 14)),
                                  Text('Passengers: ${t['quantity']}',
                                      style: GoogleFonts.outfit(fontSize: 14)),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(t['status'] ?? 'pending'),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Status: ${t['status'] ?? 'pending'}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
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