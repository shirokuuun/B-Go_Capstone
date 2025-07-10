import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:b_go/pages/conductor/quantity_selection.dart';
import 'package:b_go/pages/conductor/conductor_ticket.dart';
import 'package:b_go/main.dart';


class ConductorTo extends StatefulWidget {
  final String route;
  final String role;
  final String from;
  final num startKm;
  final String placeCollection;
  

  const ConductorTo({Key? key, 
  required this.route, 
  required this.role, 
  required this.from, 
  required this.startKm,
  required this.placeCollection
  }) : super(key: key);

  @override
  State<ConductorTo> createState() => _ConductorToState();
}

class _ConductorToState extends State<ConductorTo> {
  late Future<List<Map<String, dynamic>>> placesFuture;

  String getRouteLabel(String placeCollection) {
  switch (placeCollection) {
    case 'Place':
      return 'SM City Lipa - Batangas City';
    case 'Place 2':
      return 'Batangas City - SM City Lipa';
    default:
      return 'Unknown Route';
  }
}


  @override
  void initState() {
    super.initState();
    placesFuture = RouteService.fetchPlaces(widget.route, placeCollection: widget.placeCollection);
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
                   SizedBox(
                    height: 40,
                     child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        getRouteLabel(widget.placeCollection),
                        style: GoogleFonts.bebasNeue(
                          fontSize: 30,
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
                margin: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.02), // adjust as needed
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        "To:",
                        style: GoogleFonts.bebasNeue(
                          fontSize: 25,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: placesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const Center(child: Text('No places found.'));
                        }
                        final myList = snapshot.data!;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 2.2,
                          ),
                          itemCount: myList.length,
                          itemBuilder: (context, index) {
                            final item = myList[index];
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1D2B53),
                                elevation: 0,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                              ),

                              onPressed: () async {
                                final to = item['name'];
                                final endKm = item['km'];

                                if (widget.startKm >= endKm) {
                                  showDialog(
                                    context: context, 
                                    builder: (context) => AlertDialog(
                                      title: Text('Invalid Destination'),
                                      content: Text('The destination must be farther than the origin.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text('OK'),
                                        )
                                      ],
                                    )
                                    );
                                    return;
                                }

                                final result = await showGeneralDialog<Map<String, dynamic>>(
                                  context: context,
                                  barrierDismissible: true,
                                  barrierLabel: "Quantity",
                                  barrierColor: Colors.black.withOpacity(0.3), 
                                  transitionDuration: Duration(milliseconds: 200),
                                  pageBuilder: (context, anim1, anim2) {
                                    return QuantitySelection(
                                      onConfirm: (quantity) {
                                        Navigator.of(context).pop({
                                          'quantity': quantity,
                                        });
                                      },
                                    );
                                  },
                                  transitionBuilder: (context, anim1, anim2, child) {
                                    return FadeTransition(
                                      opacity: anim1,
                                      child: child,
                                    );
                                  },
                                );

                                if (result != null) {
                                  final discount = await showDialog<double>(
                                    context: context,
                                    builder: (context) => DiscountSelection(),
                                  );

                                  if (discount != null) {
                                    final tripDocName = await RouteService.saveTrip(
                                      route: widget.route,
                                      from: widget.from,
                                      to: to,
                                      startKm: widget.startKm,
                                      endKm: endKm,
                                      quantity: result['quantity'],
                                      discount: discount,
                                    );

                              rootNavigatorKey.currentState?.pushReplacement(
                                    MaterialPageRoute(
                                    builder: (context) => ConductorTicket(
                                      route: widget.route,
                                      tripDocName: tripDocName,
                                      placeCollection: widget.placeCollection,  
                                      ),
                                    ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Discount not selected')),
                                    );          
                                  }
                                }
                              },
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item['name'] ?? '',
                                    style: GoogleFonts.bebasNeue(fontSize: 16, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (item['km'] != null)
                                    Text(
                                      '${item['km']} km',
                                      style: TextStyle(fontSize: 12, color: Colors.white70),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
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