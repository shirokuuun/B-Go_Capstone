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

class _PreTicketQrsState extends State<PreTicketQrs> {
  late Future<List<Map<String, dynamic>>> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _ticketsFuture = _fetchAndCleanTickets();
  }

  Future<List<Map<String, dynamic>>> _fetchAndCleanTickets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final now = DateTime.now().toUtc().add(const Duration(hours: 8)); // PH time
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final tenPm = DateTime(now.year, now.month, now.day, 22);
    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('preTickets');
    final snapshot = await col
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThan: endOfDay)
        .get();
    // Remove tickets after 10pm
    if (now.isAfter(tenPm)) {
      for (var doc in snapshot.docs) {
        await col.doc(doc.id).delete();
      }
      return [];
    }
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
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
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          'Pre-Ticket QRs',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: 20,
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final tickets = snapshot.data ?? [];
          if (tickets.isEmpty) {
            return Center(
              child: Text('No pre-tickets for today.',
                  style: GoogleFonts.outfit(fontSize: 16)),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.all(width * 0.05),
            itemCount: tickets.length,
            separatorBuilder: (_, __) => SizedBox(height: width * 0.04),
            itemBuilder: (context, i) {
              final t = tickets[i];
              return GestureDetector(
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
                            Text('Fare: ${t['fare']} PHP',
                                style: GoogleFonts.outfit(fontSize: 14)),
                            Text('Passengers: ${t['quantity']}',
                                style: GoogleFonts.outfit(fontSize: 14)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey, size: 28),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}