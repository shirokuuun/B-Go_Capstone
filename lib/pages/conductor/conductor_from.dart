import 'package:b_go/pages/conductor/conductor_to.dart';
import 'package:b_go/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';

class ConductorFrom extends StatefulWidget {
  final String route;
  final String role;

  const ConductorFrom({Key? key, 
  required this.role, required this.route,

  }) : super(key: key);

  @override
  State<ConductorFrom> createState() => _ConductorFromState();
}

class _ConductorFromState extends State<ConductorFrom> {
  late Future<List<Map<String, dynamic>>> placesFuture;

  String selectedPlaceCollection = 'Place'; 

  List<Map<String, String>> routeDirections = [
    {'label': 'SM City Lipa - Batangas City', 'collection': 'Place'},
    {'label': 'Batangas City - SM City Lipa', 'collection': 'Place 2'},
  ];

  @override
  void initState() {
    super.initState();
    placesFuture = RouteService.fetchPlaces(widget.route, placeCollection: selectedPlaceCollection);
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
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => LoginPage(showRegisterPage: () {  },)),
                    (Route<dynamic> route) => false,
                  );
                },
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
                      child: DropdownButton<String>(
                        value: selectedPlaceCollection,
                        dropdownColor: const Color(0xFF1D2B53),
                        iconEnabledColor: Colors.white,
                        items: routeDirections.map((route) {
                          return DropdownMenuItem<String>(
                            value: route['collection'],
                            child: Text(
                              route['label']!,
                              style: GoogleFonts.bebasNeue(
                                fontSize: 30,
                                color: Colors.white,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              selectedPlaceCollection = newValue;
                              placesFuture = RouteService.fetchPlaces(widget.route, placeCollection: selectedPlaceCollection);
                            });
                          }
                        },
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
                        "From:",
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
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ConductorTo(
                                      route: widget.route,
                                      role: widget.role,
                                      from: item['name'],
                                      startKm: item['km'],
                                      placeCollection: selectedPlaceCollection,
                                    ),
                                  ),
                                );
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