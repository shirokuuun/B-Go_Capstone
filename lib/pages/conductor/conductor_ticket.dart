import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:elevated_ticket_widget/elevated_ticket_widget.dart';

class ConductorTicket extends StatefulWidget {
  final String route;

  ConductorTicket({Key? key, required this.route}) : super(key: key);

  @override
  State<ConductorTicket> createState() => _ConductorTicketState();
}

class _ConductorTicketState extends State<ConductorTicket> {
  @override
  Widget build(BuildContext context) {
    print('Building ConductorTicket');
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
                        fit: BoxFit.contain, // Ensures the image scales as needed
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
                    builder: (context, snapshot){
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

          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.03), // adjust as needed
                width: double.infinity,
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
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 30.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /*Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        "Ticket:",
                        style: GoogleFonts.bebasNeue(
                          fontSize: 45,
                          color: Colors.black87,
                        ),
                      ),
                    ),*/

                    const SizedBox(height: 50),

                    Center(
                      child: ElevatedTicketWidget(
                        height: 500,
                        width: 300,
                        elevation: 2,
                        backgroundColor:Colors.white,
                        child:  Padding(
                        padding: const EdgeInsets.all(16.0), 
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    width: 120,
                                    height: 25,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(color: Colors.black54, width: 1.5),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Ticket:',
                                        style: GoogleFonts.bebasNeue(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                  )
                                ],
                              )
                            ],
                          ),
                        )
                      ),
                    )
                  ],
                  
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
