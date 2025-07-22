import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:elevated_ticket_widget/elevated_ticket_widget.dart';
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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: const Color(0xFF1D2B53),
            leading: Padding(
              padding: const EdgeInsets.only(top: 18.0, left: 8.0),
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
            title: Padding(
              padding: const EdgeInsets.only(top: 22.0),
              child: Text(
                'Ticketing',
                style: GoogleFonts.outfit(
                  fontSize: 25,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SliverAppBar(
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF1D2B53),
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 20.0),
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
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 40.0),
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
                          backgroundColor: Color(0xFF1D2B53),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                   
                    Center(
                      child: latestTrip == null
                          ? Text(
                              'No ticket yet.',
                              style: GoogleFonts.bebasNeue(
                                fontSize: 20,
                                color: Colors.black54,
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.only(top: 20.0),
                              child: ElevatedTicketWidget(
                                width: MediaQuery.of(context).size.width * 0.9,
                                elevation: 2,
                                backgroundColor: Colors.white,
                                height: MediaQuery.of(context).size.height * 0.6,
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 120,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                border: Border.all(
                                                    color: Color(0xFF10B981),
                                                    width: 1.5),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'Ticket:',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 15,
                                                    color: Color(0xFF10B981),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'BATRASCO',
                                          style: GoogleFonts.outfit(
                                            fontSize: 25,
                                            color: Colors.black,
                                          ),
                                        ),
                                        Center(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              
                                              const SizedBox(height: 20),
                                              Text.rich(
                                                TextSpan(
                                                  style: GoogleFonts.bebasNeue(
                                                    fontSize: 18,
                                                    color: Colors.black87,
                                                    //height: 1.3,
                                                  ),
                                                  children: [
                                                    TextSpan(
                                                      text:
                                                          'Route: ${getRouteLabel(widget.placeCollection)}\n',
                                                      style:
                                                          GoogleFonts.outfit(
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                    TextSpan(
                                                        text:
                                                            'Date: $formattedDate\n',
                                                            style:
                                                              GoogleFonts.outfit(
                                                            fontSize: 18,
                                                          ),
                                                            ),
                                                    TextSpan(
                                                        text:
                                                            'Time: $formattedTime\n',
                                                            style:
                                                              GoogleFonts.outfit(
                                                            fontSize: 18,
                                                          ),),
                                                    TextSpan(
                                                        text:
                                                            'From: ${latestTrip!['from']}\n',
                                                        style:
                                                            GoogleFonts.outfit(
                                                          fontSize: 18,
                                                        ),),
                                                    TextSpan(
                                                        text:
                                                            'To: ${latestTrip!['to']}\n',
                                                        style:
                                                            GoogleFonts.outfit(
                                                          fontSize: 18,
                                                        ),),
                                                    TextSpan(
                                                        text:
                                                            'Regular: ${latestTrip!['farePerPassenger']}\n',
                                                        style:
                                                            GoogleFonts.outfit(
                                                          fontSize: 18,
                                                        ),),
                                                    TextSpan(
                                                        text:
                                                            'Discount: ${double.tryParse(latestTrip!['discountAmount'].toString())?.toStringAsFixed(2) ?? '0.00'}\n',
                                                        style:
                                                            GoogleFonts.outfit(
                                                          fontSize: 18,
                                                        ),),
                                                    TextSpan(
                                                        text:
                                                            'Quantity: ${latestTrip!['quantity']}\n',
                                                        style:
                                                            GoogleFonts.outfit(
                                                          fontSize: 18,
                                                        ),),
                                                    TextSpan(
                                                      text:
                                                          'Amount: ${latestTrip!['totalFare']}\n',
                                                      style:
                                                          GoogleFonts.outfit(
                                                        fontSize:
                                                            24,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                              
                                                     if (discountBreakdown != null) ...[
                                                      TextSpan(
                                                        text: '\nDiscount Breakdown:\n',
                                                        style: GoogleFonts.outfit(fontSize: 20, color: Colors.black),
                                                      ),
                                                      for (var line in discountBreakdown)
                                                        TextSpan(
                                                          text: '$line\n',
                                                          style: GoogleFonts.outfit(fontSize: 16, color: Colors.black87),
                                                        ),
                                                    ],
                                                  ],
                                                ),
                                                textAlign: TextAlign.start,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
