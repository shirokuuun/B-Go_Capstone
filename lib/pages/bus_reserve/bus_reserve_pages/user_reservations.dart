import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:b_go/pages/bus_reserve/bus_reserve_pages/payment_view_page.dart';

class UserReservations extends StatefulWidget {
  const UserReservations({Key? key}) : super(key: key);

  @override
  State<UserReservations> createState() => _UserReservationsState();
}

class _UserReservationsState extends State<UserReservations> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    final titleFontSize = isMobile
        ? 20.0
        : isTablet
            ? 24.0
            : 28.0;
    final horizontalPadding = isMobile
        ? 16.0
        : isTablet
            ? 20.0
            : 24.0;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0091AD),
          title: Text('My Reservations', style: GoogleFonts.outfit()),
        ),
        body: Center(
          child: Text('Please log in to view reservations'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0091AD),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'My Reservations',
          style: GoogleFonts.outfit(
            fontSize: titleFontSize,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: EdgeInsets.all(horizontalPadding),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all'),
                  SizedBox(width: 8),
                  _buildFilterChip('Pending', 'pending'),
                  SizedBox(width: 8),
                  _buildFilterChip('Confirmed', 'confirmed'),
                  SizedBox(width: 8),
                  _buildFilterChip('Completed', 'completed'),
                  SizedBox(width: 8),
                  _buildFilterChip('Cancelled', 'cancelled'),
                ],
              ),
            ),
          ),

          // Reservations list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reservations')
                  .where('email', isEqualTo: user.email)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF0091AD),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 60, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          'Error loading reservations',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No reservations found',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Your bus reservations will appear here',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Sort the documents in memory instead of in the query
                var allDocs = snapshot.data!.docs;
                allDocs.sort((a, b) {
                  final aTimestamp = a['timestamp'] as Timestamp?;
                  final bTimestamp = b['timestamp'] as Timestamp?;

                  if (aTimestamp == null && bTimestamp == null) return 0;
                  if (aTimestamp == null) return 1;
                  if (bTimestamp == null) return -1;

                  return bTimestamp.compareTo(aTimestamp); // Descending order
                });

                // Filter reservations based on selected filter
                var filteredDocs = allDocs.where((doc) {
                  if (_selectedFilter == 'all') return true;
                  final status = doc['status'] as String?;
                  if (_selectedFilter == 'pending') {
                    return status == 'pending' || status == 'receipt_uploaded';
                  }
                  return status == _selectedFilter;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.filter_list_off,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No ${_selectedFilter} reservations',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(horizontalPadding),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final reservationId = doc.id;

                    return _buildReservationCard(
                      context,
                      reservationId,
                      data,
                      isMobile,
                      isTablet,
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF0091AD) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Color(0xFF0091AD) : Colors.grey.shade400,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: isMobile
                ? 12
                : isTablet
                    ? 14
                    : 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildReservationCard(
    BuildContext context,
    String reservationId,
    Map<String, dynamic> data,
    bool isMobile,
    bool isTablet,
  ) {
    final status = data['status'] as String? ?? 'pending';
    final from = data['from'] as String? ?? 'N/A';
    final to = data['to'] as String? ?? 'N/A';
    final selectedBusIds = List<String>.from(data['selectedBusIds'] ?? []);
    final timestamp = data['timestamp'] as Timestamp?;
    final departureDate = data['departureDate'];

    // Determine status color and icon
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusText = 'Pending Payment';
        break;
      case 'receipt_uploaded':
        statusColor = Colors.blue;
        statusIcon = Icons.receipt;
        statusText = 'Under Review';
        break;
      case 'confirmed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Confirmed';
        break;
      case 'completed':
        statusColor = Colors.purple;
        statusIcon = Icons.flag_circle;
        statusText = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
        statusText = status;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentViewPage(
              reservationId: reservationId,
              selectedBusIds: selectedBusIds,
              reservationDetails: data,
              status: status,
            ),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      SizedBox(width: 6),
                      Text(
                        statusText,
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),

            SizedBox(height: 12),

            // Route information
            Row(
              children: [
                Icon(Icons.location_on, color: Color(0xFF0091AD), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$from → $to',
                    style: GoogleFonts.outfit(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            SizedBox(height: 8),

            // Departure date
            if (departureDate != null)
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      color: Colors.grey.shade600, size: 16),
                  SizedBox(width: 8),
                  Text(
                    _formatDepartureDate(departureDate),
                    style: GoogleFonts.outfit(
                      fontSize: isMobile ? 12 : 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),

            SizedBox(height: 8),

            // Number of buses
            Row(
              children: [
                Icon(Icons.directions_bus,
                    color: Colors.grey.shade600, size: 16),
                SizedBox(width: 8),
                Text(
                  '${selectedBusIds.length} ${selectedBusIds.length == 1 ? 'Bus' : 'Buses'}',
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 12 : 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                Spacer(),
                Text(
                  '₱${selectedBusIds.length * 2000}',
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0091AD),
                  ),
                ),
              ],
            ),

            // Created date
            if (timestamp != null) ...[
              SizedBox(height: 8),
              Text(
                'Created: ${DateFormat('MMM d, yyyy • h:mm a').format(timestamp.toDate())}',
                style: GoogleFonts.outfit(
                  fontSize: isMobile ? 10 : 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDepartureDate(dynamic date) {
    if (date == null) return 'N/A';

    DateTime dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is DateTime) {
      dateTime = date;
    } else if (date is String) {
      return date;
    } else {
      return 'N/A';
    }

    return DateFormat('EEE, MMM d, yyyy').format(dateTime);
  }
}
