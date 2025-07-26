import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:b_go/pages/conductor/ticketing/conductor_from.dart';

class ConductorTicket extends StatefulWidget {
  final String route;
  final String ticketDocName;
  final String placeCollection; 
  final String date;

  ConductorTicket({Key? key, 
  required this.route, 
  required this.ticketDocName,
  required this.placeCollection,
  required this.date
 }) : super(key: key);

  @override
  State<ConductorTicket> createState() => _ConductorTicketState();
}

class _ConductorTicketState extends State<ConductorTicket> {

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


  String from = '';
  String to = '';
  num startKm = 0;
  num endKm = 0;
  int quantity = 0;
  double discount = 0.0;

  Map<String, dynamic>? latestTrip;

  @override
  void initState() {
    super.initState();
    fetchLatestTrip();
  }

  void fetchLatestTrip() async {
    final tripData =
        await RouteService.fetchTrip(widget.route, widget.date, widget.ticketDocName);
    setState(() {
      latestTrip = tripData;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic>? discountBreakdown = latestTrip?['discountBreakdown'];
    final timestamp = latestTrip?['timestamp'];
    final formattedDate = timestamp != null
        ? '${timestamp.toDate().toLocal().toString().split(' ')[0]}'
        : 'N/A';
    final formattedTime = timestamp != null
        ? TimeOfDay.fromDateTime(
                timestamp.toDate().add(const Duration(hours: 8)))
            .format(context)
        : 'N/A';
    final from = latestTrip?['from'] ?? '';
    final to = latestTrip?['to'] ?? '';
    final startKm = latestTrip?['startKm'] ?? '';
    final endKm = latestTrip?['endKm'] ?? '';
    final baseFare = latestTrip?['farePerPassenger'] ?? '';
    final quantity = latestTrip?['quantity'] ?? '';
    final totalFare = latestTrip?['totalFare'] ?? '';
    final discountAmount = latestTrip?['discountAmount'] ?? '';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: const Color(0xFF0091AD),
            leading: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConductorFrom(
                        route: widget.route,
                        role: 'conductor',
                      ),
                    ),
                  );
                },
              ),
            ),
            title: Text(
              'Ticketing',
              style: GoogleFonts.outfit(
                fontSize: 25,
                color: Colors.white,
              ),
            ),
          ),
          SliverAppBar(
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF0091AD),
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
                    child: Center(
                      child: Text(
                        getRouteLabel(widget.placeCollection),
                        style: GoogleFonts.outfit(
                          fontSize: 20,
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
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 30.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConductorFrom(
                                route: widget.route,
                                role: 'conductor',
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.add, color: Colors.white),
                        label: Text(
                          'New Ticket',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0091AD),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Center(
                      child: latestTrip == null
                          ? Text(
                              'No ticket yet.',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                color: Colors.black54,
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.only(top: 20.0),
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.95,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 16,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Receipt', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0091AD))),
                                    SizedBox(height: 16),
                                    Text('Route: ${getRouteLabel(widget.placeCollection)}', style: GoogleFonts.outfit(fontSize: 16)),
                                    Text('Date: $formattedDate', style: GoogleFonts.outfit(fontSize: 16)),
                                    Text('Time: $formattedTime', style: GoogleFonts.outfit(fontSize: 16)),
                                    Text('From: $from', style: GoogleFonts.outfit(fontSize: 16)),
                                    Text('To: $to', style: GoogleFonts.outfit(fontSize: 16)),
                                    Text('From KM: $startKm', style: GoogleFonts.outfit(fontSize: 16)),
                                    Text('To KM: $endKm', style: GoogleFonts.outfit(fontSize: 16)),
                                    Text('Base Fare (Regular): $baseFare PHP', style: GoogleFonts.outfit(fontSize: 16)),
                                    Text('Quantity: $quantity', style: GoogleFonts.outfit(fontSize: 16)),
                                    Text('Total Amount: $totalFare PHP', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                                    SizedBox(height: 16),
                                    Text('Discounts:', style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 16)),
                                    if (discountBreakdown != null)
                                      ...discountBreakdown.map((e) => Text(e.toString(), style: GoogleFonts.outfit(fontSize: 15))),
                                    if (discountBreakdown == null)
                                      Text('No discounts.', style: GoogleFonts.outfit(fontSize: 15)),
                                  ],
                                ),
                              ),
                            ),
                    ),
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
