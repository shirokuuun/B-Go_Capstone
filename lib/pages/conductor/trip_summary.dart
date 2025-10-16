import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TripSummary extends StatefulWidget {
  final String route;
  final String role;

  const TripSummary({
    Key? key,
    required this.route,
    required this.role,
  }) : super(key: key);

  @override
  State<TripSummary> createState() => _TripSummaryState();
}

class _TripSummaryState extends State<TripSummary> {
  String selectedFilter = 'all'; // 'all', 'trip1', 'trip2', etc.

  void _showFilterBottomSheet(
      List<String> availableTrips, Map<String, dynamic>? dailyTripData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.filter_list, color: Color(0xFF0091AD), size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Filter by Trip',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, size: 24),
                      onPressed: () => Navigator.pop(context),
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            selectedFilter = 'all';
                          });
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: selectedFilter == 'all'
                                ? Color(0xFF0091AD).withOpacity(0.1)
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                  color: Colors.grey.shade200, width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selectedFilter == 'all'
                                        ? Color(0xFF0091AD)
                                        : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                  color: selectedFilter == 'all'
                                      ? Color(0xFF0091AD)
                                      : Colors.transparent,
                                ),
                                child: selectedFilter == 'all'
                                    ? Center(
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              SizedBox(width: 16),
                              Text(
                                'All Trips',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: selectedFilter == 'all'
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: selectedFilter == 'all'
                                      ? Color(0xFF0091AD)
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ...availableTrips.map((trip) {
                        final tripNum = trip.replaceAll('trip', '');
                        final tripData = dailyTripData?[trip];
                        final direction = tripData?['direction'] ?? 'Unknown';

                        return InkWell(
                          onTap: () {
                            setState(() {
                              selectedFilter = trip;
                            });
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              color: selectedFilter == trip
                                  ? Color(0xFF0091AD).withOpacity(0.1)
                                  : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                    color: Colors.grey.shade200, width: 1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selectedFilter == trip
                                          ? Color(0xFF0091AD)
                                          : Colors.grey.shade400,
                                      width: 2,
                                    ),
                                    color: selectedFilter == trip
                                        ? Color(0xFF0091AD)
                                        : Colors.transparent,
                                  ),
                                  child: selectedFilter == trip
                                      ? Center(
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Trip $tripNum',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: selectedFilter == trip
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: selectedFilter == trip
                                              ? Color(0xFF0091AD)
                                              : Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        direction,
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF0091AD),
            expandedHeight: 80,
            flexibleSpace: FlexibleSpaceBar(
              background: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 50.0),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Trip Summary',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conductors')
                  .where('uid',
                      isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .limit(1)
                  .snapshots(),
              builder: (context, conductorSnapshot) {
                if (conductorSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (!conductorSnapshot.hasData ||
                    conductorSnapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('Conductor not found'),
                    ),
                  );
                }

                final conductorDoc = conductorSnapshot.data!.docs.first;
                final conductorId = conductorDoc.id;
                final conductorData =
                    conductorDoc.data() as Map<String, dynamic>;
                final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('conductors')
                      .doc(conductorId)
                      .collection('dailyTrips')
                      .doc(today)
                      .snapshots(),
                  builder: (context, dailyTripSnapshot) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('conductors')
                          .doc(conductorId)
                          .collection('remittance')
                          .doc(today)
                          .collection('tickets')
                          .snapshots(),
                      builder: (context, remittanceSnapshot) {
                        return _buildSummaryContent(
                          context,
                          conductorData,
                          conductorId,
                          dailyTripSnapshot,
                          remittanceSnapshot,
                          today,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryContent(
    BuildContext context,
    Map<String, dynamic> conductorData,
    String conductorId,
    AsyncSnapshot<DocumentSnapshot> dailyTripSnapshot,
    AsyncSnapshot<QuerySnapshot> remittanceSnapshot,
    String today,
  ) {
    final currentPassengers = conductorData['passengerCount'] ?? 0;
    final activeTrip = conductorData['activeTrip'];
    final currentTripId = activeTrip?['tripId'];

    Map<String, dynamic>? dailyTripData;
    List<String> availableTrips = [];
    Map<String, String> tripIds = {};

    if (dailyTripSnapshot.hasData && dailyTripSnapshot.data!.exists) {
      dailyTripData = dailyTripSnapshot.data!.data() as Map<String, dynamic>?;
      if (dailyTripData != null) {
        int tripNum = 1;
        while (dailyTripData['trip$tripNum'] != null) {
          availableTrips.add('trip$tripNum');
          tripIds['trip$tripNum'] =
              dailyTripData['trip$tripNum']['tripId'] ?? '';
          tripNum++;
        }
      }
    }

    int totalTicketsToday = 0;
    double totalRevenueToday = 0.0;
    int totalPassengersToday = 0;
    int manualTickets = 0;
    int preTickets = 0;
    int preBookings = 0;
    List<Map<String, dynamic>> filteredTickets = [];
    Set<String> processedBookingIds = {}; // ✅ Track processed pre-bookings to avoid duplicates

    // Get the selected trip ID
    String? selectedTripId;
    if (selectedFilter != 'all') {
      selectedTripId = tripIds[selectedFilter];
      print('🔍 Selected Filter: $selectedFilter');
      print('🔍 Selected Trip ID: $selectedTripId');
    }

    // Process remittance tickets (completed trips) - THIS IS THE PRIMARY SOURCE
    if (remittanceSnapshot.hasData) {
      print(
          '📦 Total remittance tickets: ${remittanceSnapshot.data!.docs.length}');

      for (var doc in remittanceSnapshot.data!.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final ticketTripId = data['tripId'];

        bool includeTicket = false;
        if (selectedFilter == 'all') {
          includeTicket = true;
        } else {
          // Only include tickets that match the selected trip's tripId
          if (selectedTripId != null && ticketTripId == selectedTripId) {
            includeTicket = true;
          }
        }

        if (includeTicket) {
          // Get ticketType - check multiple possible field names
          final ticketType = (data['ticketType'] ??
                  data['documentType'] ??
                  data['type'] ??
                  'manual')
              .toString()
              .toLowerCase();

          final quantity = (data['quantity'] as num?)?.toInt() ?? 1;
          final fare =
              double.tryParse(data['totalFare']?.toString() ?? '0') ?? 0.0;
          final from = data['from'] ?? 'Unknown';
          final to = data['to'] ?? 'Unknown';

          // ✅ For pre-bookings, track the booking ID to avoid double counting
          if (ticketType == 'prebooking' || ticketType == 'pre-booking') {
            final bookingId = data['bookingId'] ?? data['documentId'];
            if (bookingId != null) {
              if (processedBookingIds.contains(bookingId)) {
                print('⚠️ Skipping duplicate pre-booking: $bookingId');
                continue; // Skip this duplicate
              }
              processedBookingIds.add(bookingId);
            }
          }

          totalTicketsToday++;
          totalPassengersToday += quantity;
          totalRevenueToday += fare;

          filteredTickets.add({
            'from': from,
            'to': to,
            'quantity': quantity,
            'fare': fare,
            'type': ticketType,
          });

          // Count ticket types
          if (ticketType == 'manual') {
            manualTickets++;
          } else if (ticketType == 'preticket' || ticketType == 'pre-ticket') {
            preTickets++;
          } else if (ticketType == 'prebooking' ||
              ticketType == 'pre-booking') {
            preBookings++;
          } else {
            manualTickets++;
          }
        }
      }
    }
    print(
        '🎫 Final counts - Manual: $manualTickets, PreTickets: $preTickets, PreBookings: $preBookings');
    print('💰 Total Revenue: ₱$totalRevenueToday');
    print('👥 Total Passengers: $totalPassengersToday');

    // Calculate destination counts from filtered tickets
    Map<String, int> destinationCounts = {};
    for (var ticket in filteredTickets) {
      final to = ticket['to'] as String;
      final quantity = ticket['quantity'] as int;
      destinationCounts[to] = (destinationCounts[to] ?? 0) + quantity;
    }

    int tripCount = availableTrips.length;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0091AD).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFF0091AD).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF0091AD)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Summary for Today',
                      style: GoogleFonts.outfit(
                          fontSize: 14, color: Colors.grey[600]),
                    ),
                    Text(
                      DateFormat('MMMM dd, yyyy').format(DateTime.now()),
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0091AD),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (availableTrips.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Viewing:',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showFilterBottomSheet(availableTrips, dailyTripData),
                  icon: Icon(Icons.filter_list, size: 18),
                  label: Text(
                    selectedFilter == 'all'
                        ? 'All Trips'
                        : selectedFilter.replaceAll('trip', 'Trip '),
                    style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0091AD),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          _buildInfoCard(
            icon: Icons.route,
            title: selectedFilter == 'all' ? 'Total Trips' : 'Selected Trip',
            value: selectedFilter == 'all'
                ? '$tripCount'
                : selectedFilter.replaceAll('trip', 'Trip '),
            subtitle: selectedFilter == 'all'
                ? (tripCount % 2 == 0
                    ? 'Round trip ${(tripCount / 2).floor()} complete'
                    : 'Trip $tripCount in progress')
                : dailyTripData?[selectedFilter]?['direction'] ??
                    'No direction',
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          if (selectedFilter == 'all') ...[
            _buildInfoCard(
              icon: Icons.people,
              title: 'Current Passengers on Bus',
              value: '$currentPassengers',
              subtitle: 'Active passengers on current trip',
              color: Colors.green,
            ),
            const SizedBox(height: 16),
          ],
          _buildInfoCard(
            icon: Icons.person_outline,
            title: selectedFilter == 'all'
                ? 'Total Passengers'
                : 'Trip Passengers',
            value: '$totalPassengersToday',
            subtitle: selectedFilter == 'all'
                ? 'Across all $tripCount trip(s)'
                : 'For ${selectedFilter.replaceAll("trip", "Trip ")}',
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.attach_money,
            title: selectedFilter == 'all' ? 'Total Revenue' : 'Trip Revenue',
            value: '₱${totalRevenueToday.toStringAsFixed(2)}',
            subtitle: 'From $totalTicketsToday ticket(s)',
            color: Colors.purple,
          ),
          const SizedBox(height: 24),
          Text(
            'Ticket Breakdown',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _buildTicketTypeCard('Manual Tickets', manualTickets,
              Icons.confirmation_number, Colors.blue),
          const SizedBox(height: 8),
          _buildTicketTypeCard(
              'Pre-Tickets', preTickets, Icons.qr_code, Colors.green),
          const SizedBox(height: 8),
          _buildTicketTypeCard(
              'Pre-Bookings', preBookings, Icons.book_online, Colors.orange),
          const SizedBox(height: 24),
          if (destinationCounts.isNotEmpty) ...[
            Text(
              selectedFilter == 'all'
                  ? 'Passengers by Destination (All Trips)'
                  : 'Passengers by Destination',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ...destinationCounts.entries.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF0091AD)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: GoogleFonts.outfit(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0091AD),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${entry.value} pax',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedFilter == 'all'
                        ? 'This summary shows all trips completed today. Revenue and passenger counts accumulate with each trip.'
                        : 'This summary shows data for ${selectedFilter.replaceAll("trip", "Trip ")} only. Revenue, passenger counts, and destinations are specific to this trip.',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.outfit(
                        fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                      fontSize: 24, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketTypeCard(
      String title, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: GoogleFonts.outfit(
                    fontSize: 16, fontWeight: FontWeight.w500)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}