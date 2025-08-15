import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:b_go/pages/conductor/conductor_home.dart';
import 'package:b_go/pages/conductor/sos.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    } else if ('${widget.route.trim()}' == 'San Juan') {
    routeDirections = [
      {'label': 'SM City Lipa - San Juan', 'collection': 'Place'},
      {'label': 'San Juan - SM City Lipa', 'collection': 'Place 2'},
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
                                                'QR code scanned and stored successfully!')),
                                      );
                                    } else if (result == false) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Failed to process QR code.')),
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

          SliverPadding(
            padding: const EdgeInsets.only(top: 20.0),
          ),

          SliverToBoxAdapter(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = MediaQuery.of(context).size.height;
              final appBarHeight = 130.0; 
              final topPadding = MediaQuery.of(context).padding.top;

              return ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: screenHeight - appBarHeight - topPadding,
                ),
                child: Container(
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
                      const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Text(
                          "Select Location:",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                ),
                                onPressed: () => _showToSelectionPage(item, myList),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item['name'] ?? '',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (item['km'] != null)
                                      Text(
                                        '${item['km']} km',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
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
              );
            },
          ),
        )
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
    } else if (r == ' San Juan') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - San Juan';
        case 'Place 2':
          return 'San Juan - SM City Lipa';
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
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: size.height * 0.90,
              ),
              child: Container(
                margin: EdgeInsets.only(
                  top: size.height * 0.02,
                  bottom: size.height * 0.08,
                ),
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
                        "Select Your Drop-off:",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                            padding:
                                const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                          ),
                          onPressed: () async {
                            final to = place['name'];
                            final endKm = place['km'];

                            if (fromPlace['km'] >= endKm) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Invalid Destination'),
                                  content: Text(
                                      'The destination must be farther than the origin.'),
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

                            final result =
                                await showGeneralDialog<Map<String, dynamic>>(
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
                              final discountResult =
                                  await showDialog<Map<String, dynamic>>(
                                context: context,
                                builder: (context) => DiscountSelection(
                                    quantity: result['quantity']),
                              );

                              if (discountResult != null) {
                                final List<double> discounts =
                                    List<double>.from(discountResult['discounts']);
                                final List<String> selectedLabels =
                                    List<String>.from(discountResult['fareTypes']);
                                
                                // Check passenger count limit before proceeding
                                final user = FirebaseAuth.instance.currentUser;
                                if (user != null) {
                                  // Check capacity before creating ticket
                                  final conductorDoc = await FirebaseFirestore.instance
                                      .collection('conductors')
                                      .where('uid', isEqualTo: user.uid)
                                      .limit(1)
                                      .get();
                                  
                                  if (conductorDoc.docs.isNotEmpty) {
                                    final conductorData = conductorDoc.docs.first.data();
                                    final currentPassengerCount = conductorData['passengerCount'] ?? 0;
                                    final newPassengerCount = currentPassengerCount + result['quantity'];
                                    
                                    if (newPassengerCount > 27) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Cannot add ${result['quantity']} passengers. Bus capacity limit (27) would be exceeded. Current: $currentPassengerCount'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                  }
                                }
                                
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
                                      date: DateFormat('yyyy-MM-dd')
                                          .format(DateTime.now()),
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

class QRScanPage extends StatefulWidget {
  @override
  _QRScanPageState createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MobileScanner(
        onDetect: (capture) async {
          // Prevent multiple executions
          if (_isProcessing) {
            print('QR scan already in progress, ignoring duplicate detection');
            return;
          }
          
          setState(() {
            _isProcessing = true;
          });
          
          final barcode = capture.barcodes.first;
          final qrData = barcode.rawValue;
          print('🔍 QR Scan Debug - Raw barcode value: $qrData');
          print('🔍 QR Scan Debug - Barcode type: ${barcode.type}');
          print('🔍 QR Scan Debug - Barcode format: ${barcode.format}');
          
          if (qrData != null && qrData.isNotEmpty) {
            try {
              print('🔄 Processing QR scan: $qrData');
              final data = parseQRData(qrData);
              print('✅ Successfully parsed QR data: $data');
              await storePreTicketToFirestore(data);
              print('✅ Successfully stored to Firestore');
              Navigator.of(context).pop(true);
            } catch (e) {
              print('❌ Error processing QR scan: $e');
              // Show error message to conductor
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Scan failed: ${e.toString().replaceAll('Exception: ', '')}'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
              Navigator.of(context).pop(false);
            } finally {
              setState(() {
                _isProcessing = false;
              });
            }
          } else {
            print('❌ QR data is null or empty');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invalid QR code: No data detected'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
            setState(() {
              _isProcessing = false;
            });
          }
        },
      ),
    );
  }
}

Map<String, dynamic> parseQRData(String qrData) {
  print('🔍 ParseQRData - Raw QR data: $qrData');
  print('🔍 ParseQRData - Data length: ${qrData.length}');
  print('🔍 ParseQRData - Data type: ${qrData.runtimeType}');
  
  try {
    // First try to parse as JSON
    final result = Map<String, dynamic>.from(jsonDecode(qrData));
    print('✅ ParseQRData - Successfully parsed as JSON: $result');
    print('🔍 ParseQRData - Type field: ${result['type']}');
    print('🔍 ParseQRData - Route field: ${result['route']}');
    return result;
  } catch (e) {
    print('⚠️ ParseQRData - JSON parsing failed: $e');
    
    // Check if it's a simple string format (like the old PREBOOK_ format)
    if (qrData.startsWith('PREBOOK_')) {
      print('🔍 ParseQRData - Detected PREBOOK_ format, converting to JSON');
      final parts = qrData.split('_');
      if (parts.length >= 6) {
        final result = {
          'type': 'preBooking',
          'id': parts[1],
          'route': parts[2],
          'from': parts[3],
          'to': parts[4],
          'quantity': int.tryParse(parts[5]) ?? 1,
        };
        print('✅ ParseQRData - Successfully converted PREBOOK_ format: $result');
        return result;
      }
    }
    
    print('🔍 ParseQRData - Trying Dart Map literal format');
    // If JSON parsing fails, try to parse Dart Map literal format
    final result = _parseDartMapLiteral(qrData);
    print('✅ ParseQRData - Successfully parsed as Dart Map literal: $result');
    return result;
  }
}

Map<String, dynamic> _parseDartMapLiteral(String qrData) {
  // Remove outer braces
  String data = qrData.trim();
  if (data.startsWith('{') && data.endsWith('}')) {
    data = data.substring(1, data.length - 1);
  }
  
  Map<String, dynamic> result = {};
  
  // Split by commas, but be careful about commas inside values
  List<String> pairs = [];
  int braceCount = 0;
  int startIndex = 0;
  
  for (int i = 0; i < data.length; i++) {
    if (data[i] == '{') braceCount++;
    else if (data[i] == '}') braceCount--;
    else if (data[i] == ',' && braceCount == 0) {
      pairs.add(data.substring(startIndex, i).trim());
      startIndex = i + 1;
    }
  }
  // Add the last pair
  if (startIndex < data.length) {
    pairs.add(data.substring(startIndex).trim());
  }
  
  for (String pair in pairs) {
    if (pair.isEmpty) continue;
    
    // Find the first colon
    int colonIndex = pair.indexOf(':');
    if (colonIndex == -1) continue;
    
    String key = pair.substring(0, colonIndex).trim();
    String value = pair.substring(colonIndex + 1).trim();
    
    // Parse the value
    dynamic parsedValue = _parseValue(value);
    result[key] = parsedValue;
  }
  
  return result;
}

dynamic _parseValue(String value) {
  // Remove quotes if present
  if ((value.startsWith("'") && value.endsWith("'")) || 
      (value.startsWith('"') && value.endsWith('"'))) {
    return value.substring(1, value.length - 1);
  }
  
  // Try to parse as number - be more careful about this
  // First try exact integer parsing
  if (int.tryParse(value) != null) {
    return int.parse(value);
  }
  
  // Then try double parsing
  if (double.tryParse(value) != null) {
    double parsed = double.parse(value);
    // If it's a whole number, return as int
    if (parsed == parsed.toInt()) {
      return parsed.toInt();
    }
    return parsed;
  }
  
  // Try to parse as boolean
  if (value.toLowerCase() == 'true') return true;
  if (value.toLowerCase() == 'false') return false;
  
  // Try to parse as list
  if (value.startsWith('[') && value.endsWith(']')) {
    String listContent = value.substring(1, value.length - 1);
    List<String> items = listContent.split(',').map((e) => e.trim()).toList();
    return items.map((item) => _parseValue(item)).toList();
  }
  
  // Return as string
  return value;
}

Future<void> storePreTicketToFirestore(Map<String, dynamic> data) async {
  // Debug: Print the parsed data to see what we're working with
  print('Parsed QR data: $data');
  
  final route = data['route'];
  final type = data['type'] ?? 'preTicket'; // Default to preTicket for backward compatibility
  
  // Get conductor information first to validate route
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('User not authenticated');
  }
  
  final conductorDoc = await FirebaseFirestore.instance
      .collection('conductors')
      .where('uid', isEqualTo: user.uid)
      .limit(1)
      .get();
  
  if (conductorDoc.docs.isEmpty) {
    throw Exception('Conductor not found');
  }
  
  final conductorData = conductorDoc.docs.first.data();
  final conductorRoute = conductorData['route'];
  
  print('Conductor route: $conductorRoute');
  print('QR route: $route');
  print('QR type: $type');
  
  // Validate that the conductor can scan this QR code
  if (conductorRoute != route) {
    throw Exception('Invalid route. You are a $conductorRoute conductor but trying to scan a $route $type. Only $conductorRoute $type can be scanned.');
  }
  
  // Check passenger count limit before proceeding
  final currentPassengerCount = conductorData['passengerCount'] ?? 0;
  
  // Improved quantity parsing
  dynamic rawQuantity = data['quantity'];
  int quantity = 1; // Default value
  
  if (rawQuantity != null) {
    if (rawQuantity is int) {
      quantity = rawQuantity;
    } else if (rawQuantity is double) {
      quantity = rawQuantity.toInt();
    } else if (rawQuantity is String) {
      int? parsedInt = int.tryParse(rawQuantity);
      if (parsedInt != null) {
        quantity = parsedInt;
      } else {
        String cleanQuantity = rawQuantity.replaceAll(RegExp(r'[^\d.]'), '');
        if (cleanQuantity.isNotEmpty) {
          double? parsed = double.tryParse(cleanQuantity);
          if (parsed != null) {
            quantity = parsed.toInt();
          }
        }
      }
    }
  }
  
  print('Current passenger count: $currentPassengerCount');
  print('Parsed quantity: $quantity');
  
  final newPassengerCount = currentPassengerCount + quantity;
  
  if (newPassengerCount > 27) {
    throw Exception('Cannot add $quantity passengers. Bus capacity limit (27) would be exceeded. Current: $currentPassengerCount');
  }
  
  if (type == 'preBooking') {
    print('🔍 Processing pre-booking with type: $type');
    await _processPreBooking(data, user, conductorDoc, quantity);
  } else {
    print('🔍 Processing pre-ticket with type: $type');
    await _processPreTicket(data, user, conductorDoc, quantity);
  }
}

Future<void> _processPreTicket(Map<String, dynamic> data, User user, QuerySnapshot conductorDoc, int quantity) async {
  final qrDataString = jsonEncode(data);
  
  print('🔍 _processPreTicket - Searching for qrData: $qrDataString');
  print('🔍 _processPreTicket - qrData length: ${qrDataString.length}');
  
  // Get all preTickets with matching qrData (single where clause only)
  QuerySnapshot existingPreTicketQuery;
  try {
    existingPreTicketQuery = await FirebaseFirestore.instance
        .collectionGroup('preTickets')
        .where('qrData', isEqualTo: qrDataString)
        .get();
  } catch (e) {
    print('❌ Collection group query failed: $e');
    print('🔄 Trying alternative approach...');
    
    // Try to get all preTickets and filter in memory
    existingPreTicketQuery = await FirebaseFirestore.instance
        .collectionGroup('preTickets')
        .get();
  }
  
  print('🔍 _processPreTicket - Found ${existingPreTicketQuery.docs.length} documents');
  
  // Filter documents in memory to avoid compound index requirement
  DocumentSnapshot? pendingPreTicket;
  bool hasBoarded = false;
  
  for (var doc in existingPreTicketQuery.docs) {
    final docData = doc.data() as Map<String, dynamic>?;
    if (docData == null) continue;
    
    print('🔍 _processPreTicket - Document ${doc.id}: status = ${docData['status']}, qrData = ${docData['qrData']}');
    
    // Check if this document matches our qrData
    final docQrData = docData['qrData'];
    if (docQrData != qrDataString) {
      print('🔍 _processPreTicket - QR data mismatch, skipping');
      continue;
    }
    
    final status = docData['status'];
    if (status == 'boarded') {
      hasBoarded = true;
      break;
    } else if (status == 'pending' && pendingPreTicket == null) {
      pendingPreTicket = doc;
    }
  }
  
  if (hasBoarded) {
    throw Exception('This pre-ticket has already been scanned and boarded.');
  }
  
  if (pendingPreTicket == null) {
    throw Exception('No pending pre-ticket found with this QR code.');
  }
  
  print('Found pending pre-ticket: ${pendingPreTicket.id}');
  
  // Update pre-ticket status to "boarded"
  print('🔄 Updating pre-ticket status to boarded');
  await pendingPreTicket.reference.update({
    'status': 'boarded',
    'boardedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'scannedAt': FieldValue.serverTimestamp(),
  });
  print('✅ Successfully updated pre-ticket status to boarded');
  
  // Store scanned QR data in conductor's preTickets collection
  final conductorDocId = conductorDoc.docs.first.id;
  final conductorData = conductorDoc.docs.first.data() as Map<String, dynamic>;
  final busName = (conductorData['busNumber'] as dynamic?)?.toString() ?? 'unknown';
  
  print('🔄 Storing scanned QR data in conductor collection');
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .collection('preTickets')
      .add({
        'qrData': qrDataString,
        'originalDocumentId': pendingPreTicket.id,
        'originalCollection': pendingPreTicket.reference.parent.path,
        'scannedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
        'qr': true, // Indicates this came from QR scan
        'status': 'boarded',
        'data': data, // Store the parsed QR data
      });
  print('✅ Successfully stored QR data in conductor collection');
  
  // Increment passenger count
  print('🔄 About to increment passenger count by $quantity');
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .update({
        'passengerCount': FieldValue.increment(quantity)
      });
  print('✅ Successfully incremented passenger count by $quantity');
  
  // Create trip record in route-level collection
  await _createTripRecord(data, pendingPreTicket.id, user, 'preTicket');
  
  // Create conductor ticket record
  await _createConductorTicketRecord(data, pendingPreTicket.id, user, conductorDocId, 'preTicket');
}

Future<void> _processPreBooking(Map<String, dynamic> data, User user, QuerySnapshot conductorDoc, int quantity) async {
  final qrDataString = jsonEncode(data);
  
  print('🔍 _processPreBooking - Searching for qrData: $qrDataString');
  print('🔍 _processPreBooking - qrData length: ${qrDataString.length}');
  
  // Try collection group query first
  QuerySnapshot existingPreBookingQuery;
  try {
    existingPreBookingQuery = await FirebaseFirestore.instance
        .collectionGroup('preBookings')
        .where('qrData', isEqualTo: qrDataString)
        .where('status', isEqualTo: 'paid')
        .get();
    print('✅ Collection group query successful');
  } catch (e) {
    print('❌ Collection group query failed: $e');
    print('🔄 Trying alternative approach...');
    
    // Wait a moment for index to be built (if it's a timing issue)
    await Future.delayed(Duration(seconds: 2));
    
    try {
      existingPreBookingQuery = await FirebaseFirestore.instance
          .collectionGroup('preBookings')
          .where('qrData', isEqualTo: qrDataString)
          .where('status', isEqualTo: 'paid')
          .get();
      print('✅ Collection group query successful after delay');
    } catch (e2) {
      print('❌ Collection group query still failed after delay: $e2');
      print('🔄 Using fallback approach...');
      
      // Fallback: Get all preBookings and filter in memory
      existingPreBookingQuery = await FirebaseFirestore.instance
          .collectionGroup('preBookings')
          .get();
    }
  }
  
  print('🔍 _processPreBooking - Found ${existingPreBookingQuery.docs.length} documents');
  
  // Since we're querying for status == 'paid' directly, we should find the document
  DocumentSnapshot? paidPreBooking;
  bool hasBoarded = false;
  
  for (var doc in existingPreBookingQuery.docs) {
    final docData = doc.data() as Map<String, dynamic>?;
    if (docData == null) continue;
    
    print('🔍 _processPreBooking - Document ${doc.id}: status = ${docData['status']}');
    
    // Check if this document matches our qrData
    final docQrData = docData['qrData'];
    if (docQrData != qrDataString) {
      print('🔍 _processPreBooking - QR data mismatch, skipping');
      continue;
    }
    
    // Since we're querying for 'paid' status, we should find the document
    if (paidPreBooking == null) {
      paidPreBooking = doc;
    }
  }
  
  if (paidPreBooking == null) {
    throw Exception('No paid pre-booking found with this QR code. Please ensure payment is completed.');
  }
  
  // Check if this pre-booking has already been boarded
  final preBookingData = paidPreBooking.data() as Map<String, dynamic>;
  if (preBookingData['status'] == 'boarded' || preBookingData['boardingStatus'] == 'boarded') {
    throw Exception('This pre-booking has already been scanned and boarded.');
  }
  
  print('Found paid pre-booking: ${paidPreBooking.id}');
  
  // Update pre-booking status to "boarded"
  print('🔄 Updating pre-booking status to boarded');
  await paidPreBooking.reference.update({
    'status': 'boarded',
    'boardedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'scannedAt': FieldValue.serverTimestamp(),
    'boardingStatus': 'boarded', // Add explicit boarding status
  });
  print('✅ Successfully updated pre-booking status to boarded');
  
  // Store scanned QR data in conductor's preBookings collection
  final conductorDocId = conductorDoc.docs.first.id;
  final conductorData = conductorDoc.docs.first.data() as Map<String, dynamic>;
  final busName = (conductorData['busNumber'] as dynamic?)?.toString() ?? 'unknown';
  
  print('🔄 Storing scanned QR data in conductor collection');
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .collection('preBookings')
      .add({
        'qrData': qrDataString,
        'originalDocumentId': paidPreBooking.id,
        'originalCollection': paidPreBooking.reference.parent.path,
        'scannedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
        'qr': true, // Indicates this came from QR scan
        'status': 'boarded',
        'boardingStatus': 'boarded', // Add explicit boarding status
        'data': data, // Store the parsed QR data
      });
  print('✅ Successfully stored QR data in conductor collection');
  
  // Increment passenger count
  print('🔄 About to increment passenger count by $quantity');
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .update({
        'passengerCount': FieldValue.increment(quantity)
      });
  print('✅ Successfully incremented passenger count by $quantity');
  
  // Create trip record in route-level collection
  await _createTripRecord(data, paidPreBooking.id, user, 'preBooking');
  
  // Create conductor ticket record
  await _createConductorTicketRecord(data, paidPreBooking.id, user, conductorDocId, 'preBooking');
}

Future<void> _createTripRecord(Map<String, dynamic> data, String documentId, User user, String type) async {
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
    'documentId': documentId,
    'documentType': type,
    'scannedBy': user.uid,
  });
  
  print('✅ Successfully created trip record: $tripDocName for $type');
}

Future<void> _createConductorTicketRecord(Map<String, dynamic> data, String documentId, User user, String conductorDocId, String type) async {
  try {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);

    // Ensure the date document exists
    await FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorDocId)
        .collection('trips')
        .doc(formattedDate)
        .set({'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

    final ticketsCollection = FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorDocId)
        .collection('trips')
        .doc(formattedDate)
        .collection('tickets');

    // Compute next ticket number
    final ticketsSnapshot = await ticketsCollection.get();
    int maxTicketNumber = 0;
    for (var doc in ticketsSnapshot.docs) {
      final name = doc.id;
      final parts = name.split(' ');
      if (parts.length == 2 && int.tryParse(parts[1]) != null) {
        final n = int.parse(parts[1]);
        if (n > maxTicketNumber) maxTicketNumber = n;
      }
    }
    final nextTicketNumber = maxTicketNumber + 1;
    final conductorTicketDocName = 'ticket $nextTicketNumber';

    // Prepare values based on QR data
    final num startKm = (data['fromKm'] as num);
    final num endKm = (data['toKm'] as num);
    final num totalKm = endKm - startKm;
    final int qty = data['quantity'] as int;
    final double baseFare = (data['fare'] as num).toDouble();
    final double totalFare = (data['amount'] as num).toDouble();
    final double discountAmount = (baseFare * qty) - totalFare;
    final List<dynamic> passengerFaresDyn = (data['passengerFares'] as List?) ??
        List.generate(qty, (_) => baseFare);
    final List<String> passengerFares = passengerFaresDyn
        .map((e) => (e as num).toStringAsFixed(2))
        .toList();
    final List<dynamic>? discountBreakdown = data['discountBreakdown'] as List?;

    await ticketsCollection.doc(conductorTicketDocName).set({
      'from': data['from'],
      'to': data['to'],
      'startKm': startKm,
      'endKm': endKm,
      'totalKm': totalKm,
      'timestamp': FieldValue.serverTimestamp(),
      'active': true,
      'quantity': qty,
      'farePerPassenger': passengerFares,
      'totalFare': totalFare.toStringAsFixed(2),
      'discountAmount': discountAmount.toStringAsFixed(2),
      'discountBreakdown': discountBreakdown,
      'documentId': documentId,
      'documentType': type,
      'scannedBy': user.uid,
    });

    print('✅ Also created conductor ticket record: $conductorTicketDocName for $formattedDate ($type)');
  } catch (e) {
    print('❌ Failed to create conductor ticket record: $e');
  }
}
