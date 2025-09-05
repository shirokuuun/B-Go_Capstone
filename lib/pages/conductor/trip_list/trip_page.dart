  import 'package:b_go/auth/conductor_login.dart';  
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/conductor_home.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:b_go/auth/auth_services.dart';

  class TripsPage extends StatefulWidget {
    final String route;
    final String role;
    final String placeCollection;
  
    TripsPage({Key? key, required this.route, required this.role, required this.placeCollection}) : super(key: key);

    @override
    _TripsPageState createState() => _TripsPageState();
  }

  class _TripsPageState extends State<TripsPage> {
    List<String> availableDates = [];
    String selectedDate = '';
    List<Map<String, dynamic>> tickets = [];
    List<Map<String, dynamic>> filteredTickets = [];
    bool isLoading = true;
    String selectedTicketType = 'All'; // 'All', 'Pre-tickets', 'Pre-bookings', 'Manual'

    @override
    void initState() {
      super.initState();
      loadInitialData();
      placesFuture = RouteService.fetchPlaces(widget.route, placeCollection: widget.placeCollection);
    }

  Future<void> loadInitialData() async {
  final currentUser = FirebaseAuth.instance.currentUser;
      final conductorId = await RouteService.getConductorDocIdFromUid(currentUser?.uid ?? '');

  if (conductorId == null) {
    // Show error if conductorId could not be retrieved
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conductor ID not found. Please contact admin.')),
    );
    setState(() {
      isLoading = false;
    });
    return;
  }

  availableDates = await RouteService.fetchAvailableDates(conductorId);

  if (availableDates.isNotEmpty) {
    selectedDate = availableDates[0];

    tickets = await RouteService.fetchTickets(
      conductorId: conductorId, 
      date: selectedDate,
    );
    
    // Initialize filtered tickets
    filteredTickets = tickets;
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

    tickets = await RouteService.fetchTickets(
      conductorId: conductorId,
      date: formattedDate,
    );
    
    // Update filtered tickets
    _applyFilter();

    setState(() => isLoading = false);
  }
}

  void _applyFilter() {
    if (selectedTicketType == 'All') {
      filteredTickets = tickets;
    } else {
      filteredTickets = tickets.where((ticket) {
        String ticketType = ticket['ticketType'] ?? 'Manual';
        return ticketType == selectedTicketType;
      }).toList();
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Filter Tickets',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0091AD),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('All'),
            _buildFilterOption('Pre-tickets'),
            _buildFilterOption('Pre-bookings'),
            _buildFilterOption('Manual'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.outfit(color: Color(0xFF0091AD)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(String option) {
    return ListTile(
      title: Text(
        option,
        style: GoogleFonts.outfit(
          fontSize: 16,
          color: selectedTicketType == option ? Color(0xFF0091AD) : Colors.black87,
          fontWeight: selectedTicketType == option ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      leading: Radio<String>(
        value: option,
        groupValue: selectedTicketType,
        onChanged: (value) {
          setState(() {
            selectedTicketType = value!;
            _applyFilter();
          });
          Navigator.pop(context);
        },
        activeColor: Color(0xFF0091AD),
      ),
    );
  }

  String _getTicketStatus(Map<String, dynamic> ticket) {
    // Check the actual status field from Firebase
    String status = ticket['status'] ?? 'boarded';
    
    // Check for various geofencing completion statuses
    switch (status.toLowerCase()) {
      case 'accomplished':
      case 'completed':
      case 'dropped_off':
      case 'finished':
        return 'Accomplished';
      case 'boarded':
      case 'active':
      case 'in_progress':
        return 'Boarded';
      default:
        // Check for geofencing indicators
        if (ticket['dropOffTimestamp'] != null || 
            ticket['dropOffLocation'] != null ||
            ticket['geofenceStatus'] == 'completed') {
          return 'Accomplished';
        }
        return 'Boarded';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accomplished':
        return Colors.green;
      case 'boarded':
        return Colors.orange;
      default:
        return Colors.grey;
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
                    // App bar content
                    Padding(
                      padding: const EdgeInsets.only(top: 50.0),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                              icon: Icon(
                                Icons.logout,
                                color: Colors.white,
                              ),
                              onPressed: () async {
                                final authServices = AuthServices();
                                await authServices.signOut();
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (context) => ConductorLogin()),
                                  (route) => false, // Removes all previous routes
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Route display
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F1F1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          selectedDate.isNotEmpty ? selectedDate : 'Select a date',
                                          style: GoogleFonts.outfit(
                                            color: Colors.black87,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: _showFilterDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                    const Icon(Icons.filter_list, size: 20, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      selectedTicketType == 'All' ? 'Filter' : selectedTicketType,
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
                      child: Text(
                        selectedTicketType == 'All' 
                            ? "No tickets for $selectedDate"
                            : "No $selectedTicketType tickets for $selectedDate",
                        style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredTickets.length,
                      itemBuilder: (context, index) {
                        // Reverse the tickets so newest is at the top
                        final ticket = filteredTickets.reversed.toList()[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Container(
                            child: GestureDetector(
                              onTap: () {
                                final discountBreakdown = ticket['discountBreakdown'] as List<dynamic>?;
                                final timestamp = ticket['timestamp'];
                                final formattedDate = timestamp != null
                                    ? DateFormat('yyyy-MM-dd').format((timestamp as Timestamp).toDate())
                                    : 'N/A';
                                final formattedTime = timestamp != null
                                    ? DateFormat('hh:mm a').format((timestamp as Timestamp).toDate())
                                    : 'N/A';
                                final fromKm = ticket['startKm'] ?? '';
                                final toKm = ticket['endKm'] ?? '';
                                final baseFare = ticket['farePerPassenger'] ?? '';
                                final quantity = ticket['quantity'] ?? '';
                                final totalFare = ticket['totalFare'] ?? '';
                                
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Receipt', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0091AD))),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Route: ${getRouteLabel(widget.placeCollection)}', style: GoogleFonts.outfit(fontSize: 14)),
                                          Text('Date: $formattedDate', style: GoogleFonts.outfit(fontSize: 14)),
                                          Text('Time: $formattedTime', style: GoogleFonts.outfit(fontSize: 14)),
                                          Text('From: ${ticket['from']}', style: GoogleFonts.outfit(fontSize: 14)),
                                          Text('To: ${ticket['to']}', style: GoogleFonts.outfit(fontSize: 14)),
                                          Text('From KM: $fromKm', style: GoogleFonts.outfit(fontSize: 14)),
                                          Text('To KM: $toKm', style: GoogleFonts.outfit(fontSize: 14)),
                                          Text('Base Fare (Regular): ${baseFare is List ? baseFare.first.toString() : baseFare} PHP', style: GoogleFonts.outfit(fontSize: 14)),
                                          Text('Quantity: $quantity', style: GoogleFonts.outfit(fontSize: 14)),
                                          Text('Total Amount: $totalFare PHP', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
                                          SizedBox(height: 16),
                                          Text('Discounts:', style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 14)),
                                          if (discountBreakdown != null)
                                            ...discountBreakdown.map((e) => Text(e.toString(), style: GoogleFonts.outfit(fontSize: 13))),
                                          if (discountBreakdown == null)
                                            Text('No discounts.', style: GoogleFonts.outfit(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('Close', style: GoogleFonts.outfit()),
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
                                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${ticket['from']} → ${ticket['to']}',
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          '${ticket['totalFare']} pesos',
                                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Color(0xFF0091AD), fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Quantity: ${ticket['quantity']}',
                                          style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(_getTicketStatus(ticket)).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _getStatusColor(_getTicketStatus(ticket)).withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            _getTicketStatus(ticket),
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _getStatusColor(_getTicketStatus(ticket)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Date: ' + (ticket['timestamp'] != null ? DateFormat('yyyy-MM-dd').format((ticket['timestamp'] as Timestamp).toDate()) : 'N/A'),
                                      style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
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
  }
