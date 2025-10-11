import 'package:b_go/auth/conductor_login.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/conductor_home.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:b_go/auth/auth_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TripsPage extends StatefulWidget {
  final String route;
  final String role;
  final String placeCollection;

  TripsPage({
    Key? key,
    required this.route,
    required this.role,
    required this.placeCollection,
  }) : super(key: key);

  @override
  _TripsPageState createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  List<String> availableDates = [];
  String selectedDate = '';
  List<Map<String, dynamic>> tickets = [];
  List<Map<String, dynamic>> filteredTickets = [];
  bool isLoading = true;
  String selectedTicketType =
      'All'; // 'All', 'preTicket', 'preBooking', 'Manual'

  @override
  void initState() {
    super.initState();
    loadInitialData();
    placesFuture = RouteService.fetchPlaces(widget.route,
        placeCollection: widget.placeCollection);
  }

  Future<void> loadInitialData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final conductorId =
        await RouteService.getConductorDocIdFromUid(currentUser?.uid ?? '');

    if (conductorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Conductor ID not found. Please contact admin.')),
      );
      setState(() {
        isLoading = false;
      });
      return;
    }

    availableDates = await RouteService.fetchAvailableDates(conductorId);

    // ✅ UPDATED: Always prioritize today's date first
    final prefs = await SharedPreferences.getInstance();
    final todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Check if today's date exists in available dates
    if (availableDates.contains(todayDate)) {
      selectedDate = todayDate;
    } else {
      // Fall back to saved date if today is not available
      String? savedDate = prefs.getString('trips_selected_date');
      if (savedDate != null && availableDates.contains(savedDate)) {
        selectedDate = savedDate;
      } else if (availableDates.isNotEmpty) {
        // Last resort: use first available date
        selectedDate = availableDates[0];
      }
    }

    if (selectedDate.isNotEmpty) {
      tickets = await RouteService.fetchTickets(
        conductorId: conductorId,
        date: selectedDate,
      );

      // Sort tickets by timestamp
      tickets.sort((a, b) {
        final aTimestamp = a['timestamp'] as Timestamp?;
        final bTimestamp = b['timestamp'] as Timestamp?;

        if (aTimestamp == null && bTimestamp == null) return 0;
        if (aTimestamp == null) return 1;
        if (bTimestamp == null) return -1;

        return aTimestamp.compareTo(bTimestamp);
      });

      // Initialize filtered tickets
      _applyFilter();
    }

    setState(() {
      isLoading = false;
    });
  }

  late Future<List<Map<String, dynamic>>> placesFuture;

  Future<void> _showDatePicker(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isNotEmpty
          ? DateTime.parse(selectedDate)
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0091AD),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);

      final conductorId = await RouteService.getConductorDocIdFromUid(
        FirebaseAuth.instance.currentUser?.uid ?? '',
      );

      if (conductorId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conductor ID not found.')),
        );
        return;
      }

      setState(() {
        selectedDate = formattedDate;
        isLoading = true;
      });

      // ✅ FIX 2: Save selected date to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('trips_selected_date', formattedDate);

      tickets = await RouteService.fetchTickets(
        conductorId: conductorId,
        date: formattedDate,
      );

      // Sort tickets by timestamp
      tickets.sort((a, b) {
        final aTimestamp = a['timestamp'] as Timestamp?;
        final bTimestamp = b['timestamp'] as Timestamp?;

        if (aTimestamp == null && bTimestamp == null) return 0;
        if (aTimestamp == null) return 1;
        if (bTimestamp == null) return -1;

        return aTimestamp.compareTo(bTimestamp);
      });

      // Update filtered tickets
      _applyFilter();

      setState(() => isLoading = false);
    }
  }

  void _applyFilter() {
    if (selectedTicketType == 'All') {
      filteredTickets = tickets;
    } else {
      // ✅ FIX 3: Use correct ticketType values from Firestore
      filteredTickets = tickets.where((ticket) {
        String ticketType = ticket['ticketType'] ?? 'Manual';

        // Match the exact values stored in Firestore
        if (selectedTicketType == 'preTicket') {
          return ticketType == 'preTicket';
        } else if (selectedTicketType == 'preBooking') {
          return ticketType == 'preBooking';
        } else if (selectedTicketType == 'Manual') {
          return ticketType == 'Manual' || ticketType.isEmpty;
        }

        return false;
      }).toList();
    }
    setState(() {}); // Update UI after filtering
  }

  void _showFilterDialog() {
    // ✅ FIX 4: Calculate counts using correct ticketType values
    final allCount = tickets.length;
    final preTicketsCount = tickets.where((t) {
      String ticketType = t['ticketType'] ?? 'Manual';
      return ticketType == 'preTicket';
    }).length;
    final preBookingsCount = tickets.where((t) {
      String ticketType = t['ticketType'] ?? 'Manual';
      return ticketType == 'preBooking';
    }).length;
    final manualCount = tickets.where((t) {
      String ticketType = t['ticketType'] ?? 'Manual';
      return ticketType == 'Manual' || ticketType.isEmpty;
    }).length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.filter_list, color: Color(0xFF0091AD), size: 24),
            SizedBox(width: 12),
            Text(
              'Filter Tickets',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0091AD),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('All', allCount, 'All'),
            _buildFilterOption('Pre-tickets', preTicketsCount, 'preTicket'),
            _buildFilterOption('Pre-bookings', preBookingsCount, 'preBooking'),
            _buildFilterOption('Manual', manualCount, 'Manual'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.outfit(
                color: Color(0xFF0091AD),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ FIX 5: Updated to accept filterValue parameter
  Widget _buildFilterOption(String displayName, int count, String filterValue) {
    final isSelected = selectedTicketType == filterValue;
    return InkWell(
      onTap: () {
        setState(() {
          selectedTicketType = filterValue;
          _applyFilter();
        });
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Color(0xFF0091AD).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Color(0xFF0091AD) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
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
                  color: isSelected ? Color(0xFF0091AD) : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected ? Color(0xFF0091AD) : Colors.transparent,
              ),
              child: isSelected
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
              child: Text(
                displayName,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: isSelected ? Color(0xFF0091AD) : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? Color(0xFF0091AD) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTicketStatus(Map<String, dynamic> ticket) {
    String status = ticket['status'] ?? 'pending';
    String ticketType = ticket['ticketType'] ?? 'Manual';
    bool isActive = ticket['active'] ?? true;

    bool isAccomplished() {
      // For manual tickets, active: false means accomplished
      if (ticketType == 'Manual' && isActive == false) {
        return true;
      }

      return ticket['accomplishedAt'] != null ||
          ticket['dropOffTimestamp'] != null ||
          ticket['dropOffLocation'] != null ||
          ticket['geofenceStatus'] == 'completed' ||
          ticket['tripCompleted'] == true ||
          ticket['completedAt'] != null ||
          status.toLowerCase() == 'accomplished' ||
          status.toLowerCase() == 'completed' ||
          status.toLowerCase() == 'dropped_off' ||
          status.toLowerCase() == 'finished';
    }

    bool isBoarded() {
      return ticket['scannedBy'] != null ||
          ticket['boardedAt'] != null ||
          ticket['scannedAt'] != null ||
          status.toLowerCase() == 'boarded' ||
          status.toLowerCase() == 'active' ||
          status.toLowerCase() == 'in_progress';
    }

    // PRE-TICKETS
    if (ticketType == 'preTicket') {
      if (isAccomplished()) return 'Accomplished';
      if (isBoarded()) return 'Boarded';
      if (status.toLowerCase() == 'paid') return 'Paid';
      if (status.toLowerCase() == 'pending') return 'Pending';
      if (status.toLowerCase() == 'cancelled') return 'Cancelled';
      return 'Pending';
    }

    // PRE-BOOKINGS
    if (ticketType == 'preBooking') {
      if (isAccomplished()) return 'Accomplished';
      if (isBoarded()) return 'Boarded';
      if (status.toLowerCase() == 'paid' ||
          status.toLowerCase() == 'pending_payment') return 'Paid';
      if (status.toLowerCase() == 'pending') return 'Pending';
      if (status.toLowerCase() == 'cancelled') return 'Cancelled';
      return 'Paid';
    }

    // MANUAL TICKETS
    if (ticketType == 'Manual') {
      if (isAccomplished()) return 'Accomplished';
      if (isActive) return 'Boarded';
      return 'Accomplished';
    }

    // Default fallback
    if (isAccomplished()) return 'Accomplished';
    if (isBoarded()) return 'Boarded';
    if (status.toLowerCase() == 'paid') return 'Paid';
    if (status.toLowerCase() == 'pending') return 'Pending';
    if (status.toLowerCase() == 'cancelled') return 'Cancelled';

    return 'Boarded';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accomplished':
        return Colors.green;
      case 'boarded':
        return Colors.orange;
      case 'paid':
        return Colors.blue;
      case 'pending':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // ✅ FIX 6: Updated to show user-friendly display names
  String _getTicketTypeDisplay(String ticketType) {
    switch (ticketType) {
      case 'preTicket':
        return 'Pre-ticket';
      case 'preBooking':
        return 'Pre-booking';
      case 'Manual':
        return 'Manual';
      default:
        return 'Manual';
    }
  }

  String getRouteLabel(String placeCollection) {
    final route = widget.route;

    if (route == 'Rosario') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - Rosario';
        case 'Place 2':
          return 'Rosario - SM City Lipa';
      }
    } else if (route == 'Batangas') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - Batangas City';
        case 'Place 2':
          return 'Batangas City - SM City Lipa';
      }
    } else if (route == 'Mataas na Kahoy') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - Mataas na Kahoy';
        case 'Place 2':
          return 'Mataas na Kahoy - SM City Lipa';
      }
    } else if (route == 'Mataas Na Kahoy Palengke') {
      switch (placeCollection) {
        case 'Place':
          return 'Lipa Palengke - Mataas na Kahoy';
        case 'Place 2':
          return 'Mataas na Kahoy - Lipa Palengke';
      }
    } else if (route == 'Tiaong') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - Tiaong';
        case 'Place 2':
          return 'Tiaong - SM City Lipa';
      }
    } else if (route == 'San Juan') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - San Juan';
        case 'Place 2':
          return 'San Juan - SM City Lipa';
      }
    }

    return 'Unknown Route';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF0091AD),
            expandedHeight: 145,
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
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => ConductorHome(
                                    route: widget.route,
                                    role: 'Conductor',
                                    placeCollection: widget.placeCollection,
                                    selectedIndex: 0,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Trips',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 10.0),
                          child: IconButton(
                            icon: Icon(Icons.logout, color: Colors.white),
                            onPressed: () async {
                              final authServices = AuthServices();
                              await authServices.signOut();
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (context) => ConductorLogin()),
                                (route) => false,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF007A8F),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              getRouteLabel(widget.placeCollection),
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedDate.isNotEmpty
                              ? "Tickets for $selectedDate"
                              : "Select a date",
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _showDatePicker(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F1F1),
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today,
                                          size: 20, color: Colors.grey),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          selectedDate.isNotEmpty
                                              ? selectedDate
                                              : 'Select a date',
                                          style: GoogleFonts.outfit(
                                            color: Colors.black87,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down,
                                          color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: _showFilterDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0091AD),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.filter_list,
                                        size: 20, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      selectedTicketType == 'All'
                                          ? 'Filter'
                                          : _getFilterDisplayName(
                                              selectedTicketType),
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (filteredTickets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(height: 16),
                            Text(
                              selectedTicketType == 'All'
                                  ? "No tickets for $selectedDate"
                                  : "No ${_getFilterDisplayName(selectedTicketType)} tickets for $selectedDate",
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredTickets.length,
                      itemBuilder: (context, index) {
                        final ticket = filteredTickets[index];
                        final ticketNumber = index + 1;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              final discountBreakdown =
                                  ticket['discountBreakdown']
                                          as List<dynamic>? ??
                                      [];
                              final timestamp = ticket['timestamp'];
                              final formattedDate = timestamp != null
                                  ? DateFormat('yyyy-MM-dd')
                                      .format((timestamp as Timestamp).toDate())
                                  : 'N/A';
                              final formattedTime = timestamp != null
                                  ? DateFormat('hh:mm a')
                                      .format((timestamp as Timestamp).toDate())
                                  : 'N/A';
                              final fromKm = ticket['startKm'] ?? '';
                              final toKm = ticket['endKm'] ?? '';
                              final baseFare = ticket['farePerPassenger'] ?? '';
                              final quantity = ticket['quantity'] ?? '';
                              final totalFare = ticket['totalFare'] ?? '';

                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(
                                    'Receipt',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0091AD),
                                    ),
                                  ),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Route: ${getRouteLabel(widget.placeCollection)}',
                                          style:
                                              GoogleFonts.outfit(fontSize: 14),
                                        ),
                                        Text(
                                          'Date: $formattedDate',
                                          style:
                                              GoogleFonts.outfit(fontSize: 14),
                                        ),
                                        Text(
                                          'Time: $formattedTime',
                                          style:
                                              GoogleFonts.outfit(fontSize: 14),
                                        ),
                                        Text(
                                          'From: ${ticket['from']}',
                                          style:
                                              GoogleFonts.outfit(fontSize: 14),
                                        ),
                                        Text(
                                          'To: ${ticket['to']}',
                                          style:
                                              GoogleFonts.outfit(fontSize: 14),
                                        ),
                                        Text(
                                          'From KM: $fromKm',
                                          style:
                                              GoogleFonts.outfit(fontSize: 14),
                                        ),
                                        Text(
                                          'To KM: $toKm',
                                          style:
                                              GoogleFonts.outfit(fontSize: 14),
                                        ),
                                        Text(
                                          'Base Fare (Regular): ${baseFare is List ? (baseFare.isNotEmpty ? baseFare.first.toString() : '0') : baseFare} PHP',
                                          style:
                                              GoogleFonts.outfit(fontSize: 14),
                                        ),
                                        Text(
                                          'Quantity: $quantity',
                                          style:
                                              GoogleFonts.outfit(fontSize: 14),
                                        ),
                                        Text(
                                          'Total Amount: $totalFare PHP',
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Discounts:',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (discountBreakdown.isNotEmpty)
                                          ...discountBreakdown.map(
                                            (e) => Text(
                                              e.toString(),
                                              style: GoogleFonts.outfit(
                                                  fontSize: 13),
                                            ),
                                          ),
                                        if (discountBreakdown.isEmpty)
                                          Text(
                                            'No discounts.',
                                            style: GoogleFonts.outfit(
                                                fontSize: 13),
                                          ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(
                                        'Close',
                                        style: GoogleFonts.outfit(
                                          color: Color(0xFF0091AD),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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
                              padding: const EdgeInsets.symmetric(
                                vertical: 18,
                                horizontal: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF0091AD)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '#$ticketNumber',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0091AD),
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(
                                                  _getTicketStatus(ticket))
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _getStatusColor(
                                                    _getTicketStatus(ticket))
                                                .withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          _getTicketStatus(ticket),
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _getStatusColor(
                                                _getTicketStatus(ticket)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${ticket['from']} → ${ticket['to']}',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        '${ticket['totalFare']} pesos',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0091AD),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Quantity: ${ticket['quantity']}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        ticket['timestamp'] != null
                                            ? DateFormat('hh:mm a').format(
                                                (ticket['timestamp']
                                                        as Timestamp)
                                                    .toDate())
                                            : 'N/A',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Date: ' +
                                            (ticket['timestamp'] != null
                                                ? DateFormat('yyyy-MM-dd')
                                                    .format((ticket['timestamp']
                                                            as Timestamp)
                                                        .toDate())
                                                : 'N/A'),
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      // ✅ Show user-friendly ticket type display
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _getTicketTypeDisplay(
                                              ticket['ticketType'] ?? 'Manual'),
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // ✅ Helper method to get display name for filter button
  String _getFilterDisplayName(String filterValue) {
    switch (filterValue) {
      case 'preTicket':
        return 'Pre-tickets';
      case 'preBooking':
        return 'Pre-bookings';
      case 'Manual':
        return 'Manual';
      default:
        return 'All';
    }
  }
}
