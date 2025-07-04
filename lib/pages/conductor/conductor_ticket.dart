import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:elevated_ticket_widget/elevated_ticket_widget.dart';
import 'package:b_go/pages/conductor/conductor_from.dart';

class ConductorTicket extends StatefulWidget {
  final String route;
  final String tripDocName;
 

  ConductorTicket({Key? key, 
  required this.route, 
  required this.tripDocName,
 }) : super(key: key);

  @override
  State<ConductorTicket> createState() => _ConductorTicketState();
}

class _ConductorTicketState extends State<ConductorTicket> {
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
    final tripData = await RouteService.fetchTrip(widget.route, widget.tripDocName);
    setState(() {
      latestTrip = tripData;
    });
  }

  @override
  Widget build(BuildContext context) {

    final timestamp = latestTrip?['timestamp'];
  final formattedDate = timestamp != null
      ? '${timestamp.toDate().toLocal().toString().split(' ')[0]}'
      : 'N/A';
  final formattedTime = timestamp != null
    ? TimeOfDay.fromDateTime(timestamp.toDate().add(const Duration(hours: 8))).format(context)
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
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            title: Padding(
              padding: const EdgeInsets.only(top: 22.0),
              child: Text(
                'Ticketing',
                style: GoogleFonts.bebasNeue(
                  fontSize: 25,
                  color: Colors.white,
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(top: 15.0, right: 8.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // SOS action
                      },
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Image.asset(
                          'assets/sos-button.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(width: 20),
                    GestureDetector(
                      onTap: () {
                        // Camera action
                      },
                      child: SizedBox(
                        width: 40,
                        height: 30,
                        child: Image.asset(
                          'assets/photo-camera.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
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
                    FutureBuilder<String>(
                      future: RouteService.fetchRoutePlaceName(widget.route),
                      builder: (context, snapshot) {
                        String placeName = '';
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          placeName = '...';
                        } else if (snapshot.hasError) {
                          placeName = 'Error';
                        } else if (snapshot.hasData) {
                          placeName = snapshot.data!;
                        }
                        return Text(
                          'ROUTE: $placeName',
                          style: GoogleFonts.bebasNeue(
                            fontSize: 25,
                            color: Colors.white,
                          ),
                        );
                      },
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30.0),
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
                        style: GoogleFonts.bebasNeue(
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1D2B53),
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),


                    const SizedBox(height: 30),
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
                                height: 400,
                                width: 270,
                                elevation: 2,
                                backgroundColor: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 120,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(30),
                                                border: Border.all(color: Color(0xFF10B981), width: 1.5),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'Ticket:',
                                                  style: GoogleFonts.bebasNeue(
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
                                            style: GoogleFonts.bebasNeue(
                                              fontSize: 28,
                                              color: Colors.black,
                                            ),
                                          ),
                                        
                                        Center(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.center,
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
                                                      text: 'Route: ${widget.route}',
                                                      style: GoogleFonts.bebasNeue(
                                                        fontSize: 22,
                                                      ),
                                                      
                                                    ),
                                                    TextSpan(text: 'Date: $formattedDate\n'),
                                                    TextSpan(text: 'Time: $formattedTime\n'),
                                                    TextSpan(text: 'From: ${latestTrip!['from']}\n'),
                                                    TextSpan(text: 'To: ${latestTrip!['to']}\n'),
                                                    TextSpan(text: 'Regular: ${latestTrip!['farePerPassenger']}\n'),
                                                    TextSpan(text: 'Discount: ${double.tryParse(latestTrip!['discountAmount'].toString())?.toStringAsFixed(2) ?? '0.00'}\n'),
                                                    TextSpan(text: 'Quantity: ${latestTrip!['quantity']}\n'),
                                                    TextSpan(
                                                      text: 'Amount: ${latestTrip!['totalFare']}\n',
                                                      style: GoogleFonts.bebasNeue(
                                                        fontSize: 24, // 👈 Increase size here
                                                        color: Colors.black,
                                                      ),
                                                    ),

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