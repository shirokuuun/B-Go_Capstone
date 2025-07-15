import 'package:b_go/pages/conductor/conductor_to.dart';
import 'package:b_go/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:b_go/pages/conductor/conductor_home.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // Added for jsonDecode
import 'package:permission_handler/permission_handler.dart';

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

  late List<Map<String, String>> routeDirections;

  @override
  void initState() {
    super.initState();
    
    if ('${widget.route.trim()}' == 'Rosario') {
    routeDirections = [
      {'label': 'SM City Lipa - Rosario', 'collection': 'Place'},
      {'label': 'Rosario - SM City Lipa', 'collection': 'Place 2'},
    ];
  } else if ('${widget.route.trim()}' == 'Batangas') {
    routeDirections = [
      {'label': 'SM City Lipa - Batangas City', 'collection': 'Place'},
      {'label': 'Batangas City - SM City Lipa', 'collection': 'Place 2'},
    ];
  }  else if ('${widget.route.trim()}' == 'Mataas na Kahoy') {
    routeDirections = [
      {'label': 'SM City Lipa - Mataas na Kahoy', 'collection': 'Place'},
      {'label': 'Mataas na Kahoy - SM City Lipa', 'collection': 'Place 2'},
    ];
  } else if ('${widget.route.trim()}' == 'Tiaong') {
    routeDirections = [
      {'label': 'SM City Lipa - Tiaong', 'collection': 'Place'},
      {'label': 'Tiaong - SM City Lipa', 'collection': 'Place 2'},
    ];
  }  else {
    // Default fallback
    routeDirections = [
      {'label': 'SM City Lipa - Unknown', 'collection': 'Place'},
      {'label': 'Unknown - SM City Lipa', 'collection': 'Place 2'},
    ];
  }

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
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => ConductorHome(
                        route: widget.route,
                        role: widget.role,
                        selectedIndex: 0, // go back to Home
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
          onTap: () async {
            // Camera action
            if (await Permission.camera.request().isGranted) {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => QRScanPage()),
              );
              if (result == true) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pre-ticket stored successfully!')));
              } else if (result == false) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to store pre-ticket.')));
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Camera permission is required to scan QR codes.')));
            }
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

class QRScanPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MobileScanner(
        onDetect: (capture) async {
          final barcode = capture.barcodes.first;
          final qrData = barcode.rawValue;
          if (qrData != null) {
            try {
              final data = parseQRData(qrData);
              await storePreTicketToFirestore(data);
              Navigator.of(context).pop(true);
            } catch (e) {
              Navigator.of(context).pop(false);
            }
          }
        },
      ),
    );
  }
}

Map<String, dynamic> parseQRData(String qrData) {
  return Map<String, dynamic>.from(jsonDecode(qrData));
}

Future<void> storePreTicketToFirestore(Map<String, dynamic> data) async {
  final route = data['route'];
  final tripsCollection = FirebaseFirestore.instance
      .collection('trips')
      .doc(route)
      .collection('trips');

  final snapshot = await tripsCollection.get();
  int maxTripNumber = 0;
  for (var doc in snapshot.docs) {
    final tripName = doc.id;
    final parts = tripName.split(' ');
    if (parts.length == 2 && int.tryParse(parts[1]) != null) {
      final num = int.parse(parts[1]);
      if (num > maxTripNumber) maxTripNumber = num;
    }
  }
  final tripNumber = maxTripNumber + 1;
  final tripDocName = "trip $tripNumber";

  await tripsCollection.doc(tripDocName).set({
    'from': data['from'],
    'to': data['to'],
    'startKm': data['fromKm'],
    'endKm': data['toKm'],
    'totalKm': (data['toKm'] as num) - (data['fromKm'] as num),
    'timestamp': FieldValue.serverTimestamp(),
    'active': true,
    'quantity': data['quantity'],
    'discountAmount': '',
    'farePerPassenger': data['fare'],
    'totalFare': data['amount'],
    'fareTypes': data['fareTypes'],
    'discountBreakdown': data['discountBreakdown'],
  });
}