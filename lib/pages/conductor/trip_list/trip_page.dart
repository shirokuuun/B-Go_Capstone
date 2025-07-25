  import 'package:b_go/auth/conductor_login.dart';  
  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:b_go/auth/conductor_login.dart';
  import 'package:b_go/pages/conductor/conductor_home.dart';
  import 'package:b_go/pages/conductor/route_service.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:intl/intl.dart';
  import 'package:firebase_auth/firebase_auth.dart';

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
      availableDates = await RouteService.fetchAvailableDates(widget.route, placeCollection: widget.placeCollection);
      if (availableDates.isNotEmpty) {
        selectedDate = availableDates[0];
        tickets = await RouteService.fetchTickets(widget.route, selectedDate, placeCollection: widget.placeCollection);
      }
      setState(() {
        isLoading = false;
      });
    }

    late Future<List<Map<String, dynamic>>> placesFuture;

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
      }

      return 'Unknown Route';
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
      body: CustomScrollView(
        slivers: [
            SliverAppBar(
              //pinned: true,
              floating: true,
              //expandedHeight: 75,
              backgroundColor: const Color(0xFF1D2B53),
              leading: Padding(
                padding: const EdgeInsets.only(top: 18.0, left: 8.0),
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
              title: Padding(
                padding: const EdgeInsets.only(top: 22.0),
                child: Text(
                  'Trips',
                  style: GoogleFonts.outfit(
                    fontSize: 25,
                    color: Colors.white,
                  ),
                ),
              ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.logout,
                  color: Colors.white,
                  ),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => ConductorLogin()),
                    (route) => false, // Removes all previous routes
                  );
                },
              ),
            ],
            ),

          SliverAppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF1D2B53),
          pinned: true,
          expandedHeight: 80,
          flexibleSpace: FlexibleSpaceBar(
            background: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF273469), // Slightly lighter than background
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      getRouteLabel(widget.placeCollection),
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
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

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: availableDates.contains(selectedDate)
                                        ? selectedDate
                                        : null,
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down),
                                    style: GoogleFonts.outfit(
                                      color: Colors.black87,
                                      fontSize: 16,
                                    ),
                                    onChanged: (String? newDate) async {
                                      if (newDate != null) {
                                        setState(() {
                                          isLoading = true;
                                          selectedDate = newDate;
                                        });
                                        tickets = await RouteService.fetchTickets(
                                          widget.route,
                                          selectedDate,
                                          placeCollection: widget.placeCollection,
                                        );
                                        setState(() => isLoading = false);
                                      }
                                    },
                                    items: availableDates.map((String date) {
                                      return DropdownMenuItem<String>(
                                        value: date,
                                        child: Text(date),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
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
                      final ticket = tickets[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
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
                                title: const Text('Delete Ticket'),
                                content: const Text('Are you sure you want to delete this ticket?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                          onDismissed: (direction) async {
                            try {
                              await RouteService.deleteTicket(
                                widget.route,
                                selectedDate,
                                ticket['id'],
                                placeCollection: 'Place', 
                              );

                              setState(() {
                                tickets.removeAt(index);
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
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.5),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              title: Text(
                                '${ticket['from']} to ${ticket['to']}',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '₱${ticket['totalFare']} - Quantity: ${ticket['quantity']}',
                                style: GoogleFonts.outfit(),
                              ),
                              onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text('Ticket Details'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('From: ${ticket['from']}'),
                                        Text('To: ${ticket['to']}'),
                                        Text('Fare: ₱${ticket['totalFare']}'),
                                        Text('Quantity: ${ticket['quantity']}'),
                                        Text('Time: ${ticket['timestamp'] != null ? DateFormat('MMM dd, yyyy hh:mm a')
                                        .format((ticket['timestamp'] as Timestamp).toDate()) 
                                              : 'N/A'}',
                                        ),
                                      ],
                                    ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                );
                                  },
                                );
                              },
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
