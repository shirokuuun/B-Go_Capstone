  import 'package:b_go/auth/conductor_login.dart';  
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/auth/conductor_login.dart';
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
    bool isLoading = true;

    @override
    void initState() {
      super.initState();
      loadInitialData();
      placesFuture = RouteService.fetchPlaces(widget.route, placeCollection: widget.placeCollection);
    }

  Future<void> loadInitialData() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  final conductorId = await RouteService.getConductorDocIdFromEmail(currentUser?.email ?? '');

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

    final conductorId = await RouteService.getConductorDocIdFromEmail(
      FirebaseAuth.instance.currentUser?.email ?? '',
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

    setState(() => isLoading = false);
  }
}


    String getRouteLabel(String placeCollection) {
      final route = widget.route.trim();

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

                        GestureDetector(
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
                      ],
                    ),
                  ),

                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (tickets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Text(
                        "No tickets for $selectedDate",
                        style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: tickets.length,
                      itemBuilder: (context, index) {
                        // Reverse the tickets so newest is at the top
                        final ticket = tickets.reversed.toList()[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Dismissible(
                            key: Key(ticket['id'] ?? index.toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              color: Colors.red,
                              child: const Icon(Icons.delete, color: Colors.white, size: 32),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Delete Ticket', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                  content: Text('Are you sure you want to delete this ticket?', style: GoogleFonts.outfit()),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: Text('Cancel', style: GoogleFonts.outfit()),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: Text('Delete', style: GoogleFonts.outfit(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (direction) async {
                              try {
                                final conductorId = await RouteService.getConductorDocIdFromEmail(
                                  FirebaseAuth.instance.currentUser?.email ?? '',
                                );

                                await RouteService.deleteTicket(
                                  conductorId!,
                                  selectedDate,
                                  ticket['id'],
                                );
                                setState(() {
                                  tickets.removeWhere((t) => t['id'] == ticket['id']);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Ticket deleted')),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to delete ticket: $e')),
                                );
                              }
                            },
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
                                            Text('Base Fare (Regular): ${baseFare is List ? (baseFare as List).first.toString() : baseFare} PHP', style: GoogleFonts.outfit(fontSize: 14)),
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
                                      Text(
                                        'Quantity: ${ticket['quantity']}',
                                        style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
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
