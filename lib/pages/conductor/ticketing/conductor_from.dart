import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:b_go/pages/conductor/conductor_home.dart';
import 'package:b_go/pages/conductor/sos.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:b_go/pages/conductor/ticketing/quantity_selection.dart';
import 'package:b_go/pages/conductor/ticketing/conductor_ticket.dart';
import 'package:b_go/main.dart';
import 'package:intl/intl.dart';

class ConductorFrom extends StatefulWidget {
  final String route;
  final String role;

  const ConductorFrom({
    Key? key,
    required this.role,
    required this.route,
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
    } else if ('${widget.route.trim()}' == 'Mataas na Kahoy') {
      routeDirections = [
        {'label': 'SM City Lipa - Mataas na Kahoy', 'collection': 'Place'},
        {'label': 'Mataas na Kahoy - SM City Lipa', 'collection': 'Place 2'},
      ];
    } else if ('${widget.route.trim()}' == 'Tiaong') {
      routeDirections = [
        {'label': 'SM City Lipa - Tiaong', 'collection': 'Place'},
        {'label': 'Tiaong - SM City Lipa', 'collection': 'Place 2'},
      ];
    } else {
      routeDirections = [
        {'label': 'SM City Lipa - Unknown', 'collection': 'Place'},
        {'label': 'Unknown - SM City Lipa', 'collection': 'Place 2'},
      ];
    }
    placesFuture = RouteService.fetchPlaces(widget.route,
        placeCollection: selectedPlaceCollection);
  }

  void _showToSelectionPage(Map<String, dynamic> fromPlace,
      List<Map<String, dynamic>> allPlaces) async {
    int fromIndex = allPlaces.indexOf(fromPlace);
    List<Map<String, dynamic>> toPlaces = allPlaces.sublist(fromIndex + 1);
    if (toPlaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('No valid drop-off locations after selected pick-up.')),
      );
      return;
    }
    final toPlace = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => _ToSelectionPageConductor(
          toPlaces: toPlaces,
          route: widget.route,
          role: widget.role,
          fromPlace: fromPlace,
          placeCollection: selectedPlaceCollection,
        ),
      ),
    );
    // No further action needed here; navigation handled in _ToSelectionPageConductor
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
            expandedHeight: 140,
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
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => ConductorHome(
                                    route: widget.route,
                                    role: widget.role,
                                    placeCollection: selectedPlaceCollection,
                                    selectedIndex: 0,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Ticketing',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 10.0),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SOSPage(
                                        route: widget.route,
                                        placeCollection:
                                            selectedPlaceCollection,
                                      ),
                                    ),
                                  );
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
                                  if (await Permission.camera
                                      .request()
                                      .isGranted) {
                                    final result =
                                        await Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (context) => QRScanPage()),
                                    );
                                    if (result == true) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Pre-ticket stored successfully!')),
                                      );
                                    } else if (result == false) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Failed to store pre-ticket.')),
                                      );
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Camera permission is required to scan QR codes.')),
                                    );
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
                  ),
                  // Route directions display (clickable)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedPlaceCollection =
                              selectedPlaceCollection == 'Place'
                                  ? 'Place 2'
                                  : 'Place';
                          placesFuture = RouteService.fetchPlaces(widget.route,
                              placeCollection: selectedPlaceCollection);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007A8F),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.swap_horiz, color: Colors.white),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                routeDirections.firstWhere((r) =>
                                    r['collection'] ==
                                    selectedPlaceCollection)['label']!,
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
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.02),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        "Select Location:",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: placesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text('Error:  ${snapshot.error}'));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(child: Text('No places found.'));
                        }
                        final myList = snapshot.data!;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
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
                                backgroundColor: const Color(0xFF0091AD),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 4),
                              ),
                              onPressed: () =>
                                  _showToSelectionPage(item, myList),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item['name'] ?? '',
                                    style: GoogleFonts.outfit(
                                        fontSize: 14, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (item['km'] != null)
                                    Text(
                                      '${item['km']} km',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.white70),
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
          ),
        ],
      ),
    );
  }
}

class _ToSelectionPageConductor extends StatelessWidget {
  final List<Map<String, dynamic>> toPlaces;
  final String route;
  final String role;
  final Map<String, dynamic> fromPlace;
  final String placeCollection;
  const _ToSelectionPageConductor({
    Key? key,
    required this.toPlaces,
    required this.route,
    required this.role,
    required this.fromPlace,
    required this.placeCollection,
  }) : super(key: key);

  String getRouteLabel(String route, String placeCollection) {
    final r = route.trim();
    if (r == 'Rosario') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - Rosario';
        case 'Place 2':
          return 'Rosario - SM City Lipa';
      }
    } else if (r == 'Batangas') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - Batangas City';
        case 'Place 2':
          return 'Batangas City - SM City Lipa';
      }
    } else if (r == 'Mataas na Kahoy') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - Mataas na Kahoy';
        case 'Place 2':
          return 'Mataas na Kahoy - SM City Lipa';
      }
    } else if (r == 'Tiaong') {
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
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF0091AD),
            expandedHeight: 140,
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
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Drop-off',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Route directions display (not clickable)
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
                          const Icon(Icons.swap_horiz, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              getRouteLabel(route, placeCollection),
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
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: EdgeInsets.only(top: size.height * 0.02, bottom: size.height * 0.08),
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
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text(
                          "Select Your Drop-off:",
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 2.2,
                        ),
                        itemCount: toPlaces.length,
                        itemBuilder: (context, index) {
                          final place = toPlaces[index];
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0091AD),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 4),
                            ),
                            onPressed: () async {
                              final to = place['name'];
                              final endKm = place['km'];

                              if (fromPlace['km'] >= endKm) {
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
                                  ),
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
                                  return const QuantitySelection();
                                },
                                transitionBuilder: (context, anim1, anim2, child) {
                                  return FadeTransition(
                                    opacity: anim1,
                                    child: child,
                                  );
                                },
                              );

                              if (result != null) {
                                final discountResult = await showDialog<Map<String, dynamic>>(
                                  context: context,
                                  builder: (context) => DiscountSelection(quantity: result['quantity']),
                                );

                                if (discountResult != null) {
                                  final List<double> discounts = List<double>.from(discountResult['discounts']);
                                  final List<String> selectedLabels = List<String>.from(discountResult['fareTypes']);
                                  final ticketDocName = await RouteService.saveTrip(
                                    route: route,
                                    from: fromPlace['name'],
                                    to: to,
                                    startKm: fromPlace['km'],
                                    endKm: endKm,
                                    quantity: result['quantity'],
                                    discountList: discounts,
                                    fareTypes: selectedLabels,
                                  );

                                  rootNavigatorKey.currentState?.pushReplacement(
                                    MaterialPageRoute(
                                      builder: (context) => ConductorTicket(
                                        route: route,
                                        ticketDocName: ticketDocName,
                                        placeCollection: placeCollection,
                                        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
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
                                  place['name'] ?? '',
                                  style: GoogleFonts.outfit(
                                      fontSize: 15, color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                                if (place['km'] != null)
                                  Text(
                                    '${place['km']} km',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.white70),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
