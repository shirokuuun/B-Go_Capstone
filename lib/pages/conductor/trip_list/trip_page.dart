  import 'package:b_go/auth/conductor_login.dart';  
  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:b_go/auth/conductor_login.dart';
  import 'package:b_go/pages/conductor/conductor_home.dart';
  import 'package:b_go/pages/conductor/route_service.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';

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
                onPressed: () {
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
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                    SizedBox(
                      height: 40,
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          getRouteLabel(widget.placeCollection),
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            ),

            
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.02),
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4))],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedDate.isNotEmpty
                            ? "Tickets for $selectedDate"
                            : "Select a date",
                        style: GoogleFonts.outfit(fontSize: 18),
                      ),
                    DropdownButton<String>(
                      value: availableDates.contains(selectedDate) ? selectedDate : null,
                      isExpanded: true,
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


                      if (isLoading)
                        Center(child: CircularProgressIndicator())
                      else if (tickets.isEmpty)
                        Text("No tickets for $selectedDate", style: GoogleFonts.outfit(fontSize: 18))
                      else
                       SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: ListView.builder(
                          itemCount: tickets.length,
                          itemBuilder: (context, index) {
                            final ticket = tickets[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 6,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
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
                                      builder: (context) => AlertDialog(
                                        title: Text(
                                          'Ticket Details',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                          ),
                                        ),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Active: ${ticket['active'] ? "Yes" : "No"}',
                                                style: TextStyle(color: ticket['active'] ? Colors.green : Colors.red),
                                              ),
                                              Text(
                                                'Time: ${ticket['timestamp'] != null ? (ticket['timestamp'] as Timestamp).toDate().toString() : 'N/A'}',
                                              ),
                                              Text('From: ${ticket['from']}'),
                                              Text('To: ${ticket['to']}'),
                                              Text('Quantity: ${ticket['quantity']}'),
                                              Text('Discount Amount: ₱${ticket['discountAmount']}'),
                                              const SizedBox(height: 10),
                                              const Text(
                                                'Discount Breakdown:',
                                                style: TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              ...List.generate((ticket['discountBreakdown'] as List).length, (i) {
                                                return Text(ticket['discountBreakdown'][i]);
                                              }),
                                              const SizedBox(height: 10),
                                              Text(
                                                'Total Fare: ₱${ticket['totalFare']}',
                                                style: TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            child: const Text('Close'),
                                            onPressed: () => Navigator.of(context).pop(),
                                          ),
                                          TextButton(
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                            onPressed: () async {
                                              await FirebaseFirestore.instance
                                              .collection('trips')
                                              .doc(widget.route)
                                              .collection('trips')
                                              .doc(selectedDate)
                                              .collection('tickets')
                                              .doc(ticket['id'])
                                              .delete();

                                            Navigator.of(context).pop();

                                            // Optionally refresh the ticket list
                                            setState(() {
                                              tickets.removeAt(index);
                                            });
                                            },
                                          ),
                                        ],
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        elevation: 10,
                                        backgroundColor: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      );
    }
  }
