import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:b_go/pages/conductor/conductor_departure.dart';
import 'package:b_go/pages/conductor/sos.dart';
import 'package:b_go/pages/conductor/passenger_status_service.dart';
import 'package:b_go/services/direction_validation_service.dart';
import 'package:b_go/services/thermal_printer_service.dart';
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
  Future<List<Map<String, dynamic>>>? placesFuture;
  String selectedPlaceCollection = 'Place';
  late List<Map<String, String>> routeDirections;

  // Thermal Printer Service
  final ThermalPrinterService _printerService = ThermalPrinterService();

  final Map<String, String> _routeFirestoreNames = {
    'Batangas': 'Batangas',
    'Rosario': 'Rosario',
    'Mataas na Kahoy': 'Mataas na Kahoy',
    'Mataas Na Kahoy Palengke': 'Mataas Na Kahoy Palengke',
    'Tiaong': 'Tiaong',
    'San Juan': 'San Juan',
  };

  @override
  void initState() {
    super.initState();
    _initializeRouteDirections();
    _checkActiveTrip();
  }

  @override
  void dispose() {
    _printerService.disconnectPrinter();
    super.dispose();
  }

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
    } else if (route == 'Mataas Na Kahoy Palengke') {
      switch (placeCollection) {
        case 'Place':
          return 'Lipa Palengke - Mataas na Kahoy';
        case 'Place 2':
          return 'Mataas na Kahoy - Lipa Palengke';
      }
    } else if (route == 'Tiaong') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - Tiaong';
        case 'Place 2':
          return 'Tiaong - SM City Lipa';
      }
    } else if (route == 'San Juan') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - San Juan';
        case 'Place 2':
          return 'San Juan - SM City Lipa';
      }
    }

    return 'Unknown Route';
  }

  Future<void> _printScannedTicket(
      Map<String, dynamic> ticketData, String ticketType) async {
    try {
      if (!_printerService.isConnected) {
        await ThermalPrinterService.showPrinterConnectionDialog(
          context,
          (ip, port) async {
            final connected = await _printerService.connectPrinter(ip, port);
            if (!connected) {
              if (mounted) {
                _showCustomSnackBar('Failed to connect to printer', 'error');
              }
              return;
            }
            await _performScannedTicketPrint(ticketData, ticketType);
          },
        );
      } else {
        await _performScannedTicketPrint(ticketData, ticketType);
      }
    } catch (e) {
      print('Error printing scanned ticket: $e');
      if (mounted) {
        _showCustomSnackBar('Error: ${e.toString()}', 'error');
      }
    }
  }

  Future<void> _performScannedTicketPrint(
      Map<String, dynamic> ticketData, String ticketType) async {
    try {
      final from = ticketData['from']?.toString() ?? 'N/A';
      final to = ticketData['to']?.toString() ?? 'N/A';
      final fromKm = ticketData['fromKm']?.toString() ?? '0';
      final toKm = ticketData['toKm']?.toString() ?? '0';

      String baseFare = '0.00';
      final fareData =
          ticketData['fare'] ?? ticketData['amount'] ?? ticketData['totalFare'];
      if (fareData != null) {
        if (fareData is num) {
          baseFare = fareData.toStringAsFixed(2);
        } else if (fareData is String) {
          baseFare = fareData;
        }
      }

      final quantity = (ticketData['quantity'] as num?)?.toInt() ?? 1;
      final totalFare = (ticketData['totalFare'] ??
              ticketData['totalAmount'] ??
              ticketData['amount'] ??
              '0.00')
          .toString();
      final discountAmount = ticketData['discountAmount']?.toString() ?? '0.00';

      List<String>? discountBreakdown;
      if (ticketData['discountBreakdown'] != null) {
        discountBreakdown = List<String>.from(
            (ticketData['discountBreakdown'] as List).map((e) => e.toString()));
      }

      final success = await _printerService.printManualTicket(
        route: getRouteLabel(selectedPlaceCollection),
        from: from,
        to: to,
        fromKm: fromKm,
        toKm: toKm,
        baseFare: baseFare,
        quantity: quantity,
        totalFare: totalFare,
        discountAmount: discountAmount,
        discountBreakdown: discountBreakdown,
      );

      if (mounted) {
        if (success) {
          _showCustomSnackBar(
            '$ticketType receipt printed successfully!',
            'success',
          );
        } else {
          _showCustomSnackBar(
            'Failed to print $ticketType receipt',
            'error',
          );
        }
      }
    } catch (e) {
      print('Error performing scanned ticket print: $e');
      if (mounted) {
        _showCustomSnackBar('Print error: ${e.toString()}', 'error');
      }
    }
  }

  void _initializeRouteDirections() {
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
    } else if ('${widget.route}' == 'Mataas na Kahoy') {
      routeDirections = [
        {'label': 'SM City Lipa - Mataas na Kahoy', 'collection': 'Place'},
        {'label': 'Mataas na Kahoy - SM City Lipa', 'collection': 'Place 2'},
      ];
    } else if ('${widget.route.trim()}' == 'Mataas Na Kahoy Palengke') {
      routeDirections = [
        {'label': 'Lipa Palengke - Mataas na Kahoy', 'collection': 'Place'},
        {'label': 'Mataas na Kahoy - Lipa Palengke', 'collection': 'Place 2'},
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
  }

  Future<void> _checkActiveTrip() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final conductorDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (conductorDoc.docs.isNotEmpty) {
        final conductorData = conductorDoc.docs.first.data();
        final activeTrip = conductorData['activeTrip'];

        if (activeTrip != null && activeTrip['isActive'] == true) {
          if (mounted) {
            setState(() {
              selectedPlaceCollection =
                  activeTrip['placeCollection'] ?? 'Place';
            });
          }
        }
      }
    } catch (e) {
      print('Error checking active trip: $e');
    }

    if (!mounted) return;

    print('🔍 ConductorFrom: Route: "${widget.route}"');
    print('🔍 ConductorFrom: Selected collection: "$selectedPlaceCollection"');

    String firestoreRouteName =
        _routeFirestoreNames[widget.route] ?? widget.route;
    print('🔍 ConductorFrom: Firestore route name: "$firestoreRouteName"');

    if (mounted) {
      setState(() {
        placesFuture = RouteService.fetchPlaces(firestoreRouteName,
            placeCollection: selectedPlaceCollection);
      });
    }
  }

  void _showCustomSnackBar(String message, String type) {
    Color backgroundColor;
    IconData icon;
    Color iconColor;

    switch (type) {
      case 'success':
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        iconColor = Colors.white;
        break;
      case 'error':
        backgroundColor = Colors.red;
        icon = Icons.error;
        iconColor = Colors.white;
        break;
      case 'warning':
        backgroundColor = Colors.orange;
        icon = Icons.warning;
        iconColor = Colors.white;
        break;
      default:
        backgroundColor = Colors.grey;
        icon = Icons.info;
        iconColor = Colors.white;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 12,
                color: backgroundColor,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.all(16),
        action: SnackBarAction(
          label: '✕',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showToSelectionPage(Map<String, dynamic> fromPlace,
      List<Map<String, dynamic>> allPlaces) async {
    if (!mounted) return;

    int fromIndex = allPlaces.indexOf(fromPlace);
    List<Map<String, dynamic>> toPlaces = allPlaces.sublist(fromIndex + 1);
    if (toPlaces.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('No valid drop-off locations after selected pick-up.')),
        );
      }
      return;
    }

    if (mounted) {
      await Navigator.of(context).push<Map<String, dynamic>>(
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
    }
  }

  void _openQRScanner() async {
    if (await Permission.camera.request().isGranted) {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => QRScanPage(),
        ),
      );

      if (result is Map<String, dynamic>) {
        final success = result['success'] as bool;

        if (success) {
          final ticketType = result['type'] as String;
          final ticketData = result['data'] as Map<String, dynamic>;

          if (ticketType == 'preTicket') {
            _showCustomSnackBar(
              'Pre-ticket scanned successfully!',
              'success',
            );
          } else if (ticketType == 'preBooking') {
            _showCustomSnackBar(
              'Pre-booking scanned successfully!',
              'success',
            );
          }

          await _printScannedTicket(ticketData, ticketType);
        } else {
          final error =
              result['error'] as String? ?? 'Failed to process QR code';
          _showCustomSnackBar(error, 'error');
        }
      }
    } else {
      _showCustomSnackBar(
        'Camera permission is required to scan QR codes.',
        'error',
      );
    }
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
                                  builder: (context) => ConductorDeparture(
                                    route: widget.route,
                                    role: widget.role,
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SOSPage(
                                      route: widget.route,
                                      placeCollection: selectedPlaceCollection,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.sos,
                                color: Colors.red,
                                size: 24.0,
                              ),
                              tooltip: 'SOS',
                            ),
                            IconButton(
                              onPressed: _openQRScanner,
                              icon: const Icon(
                                Icons.qr_code_scanner,
                                color: Colors.white,
                                size: 24.0,
                              ),
                              tooltip: 'Scan QR Code',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 4.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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
                            const Icon(Icons.swap_horiz,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                routeDirections.firstWhere((r) =>
                                    r['collection'] ==
                                    selectedPlaceCollection)['label']!,
                                style: GoogleFonts.outfit(
                                  fontSize:
                                      MediaQuery.of(context).size.width < 360
                                          ? 14
                                          : 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
          const SliverPadding(
            padding: EdgeInsets.only(top: 20.0),
          ),
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenHeight = MediaQuery.of(context).size.height;
                final screenWidth = MediaQuery.of(context).size.width;
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
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(35)),
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
                        if (placesFuture == null)
                          const Center(child: CircularProgressIndicator())
                        else
                          FutureBuilder<List<Map<String, dynamic>>>(
                            key: ValueKey(
                                'places_future_${widget.route}_$selectedPlaceCollection'),
                            future: placesFuture,
                            builder: (context, snapshot) {
                              if (!mounted) {
                                return const SizedBox.shrink();
                              }
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return Center(
                                    child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.error_outline,
                                        size: 48, color: Colors.red),
                                    const SizedBox(height: 16),
                                    Text('Error: ${snapshot.error}'),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          String firestoreRouteName =
                                              _routeFirestoreNames[
                                                      widget.route] ??
                                                  widget.route;
                                          placesFuture =
                                              RouteService.fetchPlaces(
                                                  firestoreRouteName,
                                                  placeCollection:
                                                      selectedPlaceCollection);
                                        });
                                      },
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ));
                              } else if (!snapshot.hasData ||
                                  snapshot.data == null ||
                                  snapshot.data!.isEmpty) {
                                return const Center(
                                    child: Text('No places found.'));
                              }

                              final myList = snapshot.data!;
                              final isSmallScreen = screenWidth < 360;
                              final isMediumScreen = screenWidth < 400;

                              double aspectRatio;
                              double fontSize;
                              double kmFontSize;

                              if (isSmallScreen) {
                                aspectRatio = 1.8;
                                fontSize = 12;
                                kmFontSize = 10;
                              } else if (isMediumScreen) {
                                aspectRatio = 2.0;
                                fontSize = 13;
                                kmFontSize = 11;
                              } else {
                                aspectRatio = 2.2;
                                fontSize = 14;
                                kmFontSize = 12;
                              }

                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
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
                                          vertical: 4, horizontal: 4),
                                    ),
                                    onPressed: () =>
                                        _showToSelectionPage(item, myList),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            item['name'] ?? '',
                                            style: GoogleFonts.outfit(
                                              fontSize: fontSize,
                                              color: Colors.white,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (item['km'] != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            '${(item['km'] as num).toInt()} km',
                                            style: TextStyle(
                                              fontSize: kmFontSize,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
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
    } else if (r == 'Mataas Na Kahoy Palengke') {
      switch (placeCollection) {
        case 'Place':
          return 'Lipa Palengke - Mataas na Kahoy';
        case 'Place 2':
          return 'Mataas na Kahoy - Lipa Palengke';
      }
    } else if (r == 'Tiaong') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - Tiaong';
        case 'Place 2':
          return 'Tiaong - SM City Lipa';
      }
    } else if (r == 'San Juan') {
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
    final screenWidth = size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 400;

    double aspectRatio;
    double fontSize;
    double kmFontSize;

    if (isSmallScreen) {
      aspectRatio = 1.8;
      fontSize = 12;
      kmFontSize = 10;
    } else if (isMediumScreen) {
      aspectRatio = 2.0;
      fontSize = 13;
      kmFontSize = 11;
    } else {
      aspectRatio = 2.2;
      fontSize = 15;
      kmFontSize = 11;
    }

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
                  Padding(
                    padding: const EdgeInsets.only(top: 50.0),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
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
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 4.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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
                            const Icon(Icons.swap_horiz,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                getRouteLabel(route, placeCollection),
                                style: GoogleFonts.outfit(
                                  fontSize: screenWidth < 360 ? 14 : 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(35)),
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
                          childAspectRatio: aspectRatio,
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
                                  vertical: 4, horizontal: 4),
                            ),
                            onPressed: () async {
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
                                transitionBuilder:
                                    (context, anim1, anim2, child) {
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
                                      List<double>.from(
                                          discountResult['discounts']);
                                  final List<String> selectedLabels =
                                      List<String>.from(
                                          discountResult['fareTypes']);

                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  if (user != null) {
                                    final conductorDoc = await FirebaseFirestore
                                        .instance
                                        .collection('conductors')
                                        .where('uid', isEqualTo: user.uid)
                                        .limit(1)
                                        .get();

                                    if (conductorDoc.docs.isNotEmpty) {
                                      final conductorData =
                                          conductorDoc.docs.first.data();
                                      final conductorDocId =
                                          conductorDoc.docs.first.id;
                                      final currentPassengerCount =
                                          conductorData['passengerCount'] ?? 0;

                                      final activeTripId =
                                          conductorData['activeTrip']
                                              ?['tripId'];
                                      final preBookingsQuery =
                                          activeTripId != null
                                              ? await FirebaseFirestore.instance
                                                  .collection('conductors')
                                                  .doc(conductorDocId)
                                                  .collection('preBookings')
                                                  .where('tripId',
                                                      isEqualTo: activeTripId)
                                                  .get()
                                              : await FirebaseFirestore.instance
                                                  .collection('conductors')
                                                  .doc(conductorDocId)
                                                  .collection('preBookings')
                                                  .get();

                                      int preBookedPassengers = 0;
                                      if (preBookingsQuery.docs.isNotEmpty) {
                                        preBookedPassengers =
                                            preBookingsQuery.docs.where((doc) {
                                          final data = doc.data();
                                          final isForCurrentTrip =
                                              activeTripId == null ||
                                                  data['tripId'] ==
                                                      activeTripId ||
                                                  data['tripId'] == null;
                                          return data['route'] == route &&
                                              (data['status'] == 'paid' ||
                                                  data['status'] ==
                                                      'pending_payment') &&
                                              data['boardingStatus'] !=
                                                  'boarded' &&
                                              isForCurrentTrip;
                                        }).fold<int>(0, (sum, doc) {
                                          final data = doc.data();
                                          return sum +
                                              ((data['quantity'] as int?) ?? 1);
                                        });
                                      }

                                      final totalPassengers =
                                          currentPassengerCount +
                                              preBookedPassengers;
                                      final newPassengerCount =
                                          totalPassengers + result['quantity'];

                                      if (newPassengerCount > 27) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Cannot add ${result['quantity']} passengers. Bus capacity limit (27) would be exceeded. Current: $currentPassengerCount boarded + $preBookedPassengers pre-booked = $totalPassengers total'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }
                                    }
                                  }

                                  final ticketDocName =
                                      await RouteService.saveTrip(
                                    route: route,
                                    from: fromPlace['name'],
                                    to: place['name'],
                                    startKm: fromPlace['km'],
                                    endKm: endKm,
                                    quantity: result['quantity'],
                                    discountList: discounts,
                                    fareTypes: selectedLabels,
                                  );

                                  rootNavigatorKey.currentState
                                      ?.pushReplacement(
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
                                    SnackBar(
                                        content: Text('Discount not selected')),
                                  );
                                }
                              }
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    place['name'] ?? '',
                                    style: GoogleFonts.outfit(
                                        fontSize: fontSize,
                                        color: Colors.white),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (place['km'] != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${(place['km'] as num).toInt()} km',
                                    style: TextStyle(
                                        fontSize: kmFontSize,
                                        color: Colors.white70),
                                  ),
                                ],
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
      appBar: AppBar(
        title: Text('Scan QR Code', style: GoogleFonts.outfit(fontSize: 18)),
        backgroundColor: Color(0xFF0091AD),
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(
        onDetect: (capture) async {
          if (_isProcessing) {
            print('QR scan already in progress, ignoring duplicate detection');
            return;
          }

          setState(() {
            _isProcessing = true;
          });

          final barcode = capture.barcodes.first;
          final qrData = barcode.rawValue;

          if (qrData != null && qrData.isNotEmpty) {
            try {
              final data = parseQRData(qrData);
              await storePreTicketToFirestore(data);

              Navigator.of(context).pop({
                'success': true,
                'type': data['type'] ?? 'preTicket',
                'data': data,
              });
            } catch (e) {
              Navigator.of(context).pop({
                'success': false,
                'error': e.toString().replaceAll('Exception: ', ''),
              });
            } finally {
              setState(() {
                _isProcessing = false;
              });
            }
          } else {
            Navigator.of(context).pop({
              'success': false,
              'error': 'Invalid QR code: No data detected',
            });
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
  try {
    final Map<String, dynamic> data = jsonDecode(qrData);
    return data;
  } catch (e) {
    throw Exception('Invalid QR code format: $e');
  }
}

Future<void> storePreTicketToFirestore(Map<String, dynamic> data) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('User not authenticated');

  final qrDataString = jsonEncode(data);
  final quantity = data['quantity'] ?? 1;

  final conductorDoc = await FirebaseFirestore.instance
      .collection('conductors')
      .where('uid', isEqualTo: user.uid)
      .get();

  if (conductorDoc.docs.isEmpty) {
    throw Exception('Conductor profile not found');
  }

  final conductorData = conductorDoc.docs.first.data();
  final conductorRoute = conductorData['route'];
  final route = data['route'];

  if (conductorRoute != route) {
    throw Exception(
        'Invalid route. You are a $conductorRoute conductor but trying to scan a $route ticket. Only $conductorRoute tickets can be scanned.');
  }

  final conductorDocId = conductorDoc.docs.first.id;
  final currentPassengerCount = conductorData['passengerCount'] ?? 0;

  final activeTripId = conductorData['activeTrip']?['tripId'];

  final preBookingsQuery = await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .collection('preBookings')
      .get();

  int preBookedPassengers = 0;
  if (preBookingsQuery.docs.isNotEmpty) {
    final Set<String> countedBookingIds = {};
    final scannedBookingId =
        data['bookingId'] ?? data['id'] ?? data['preBookingId'];

    preBookedPassengers = preBookingsQuery.docs.where((doc) {
      final docData = doc.data();
      final docId = doc.id;

      if (countedBookingIds.contains(docId)) {
        print('⏭️ Skipping duplicate: $docId');
        return false;
      }

      if (scannedBookingId != null) {
        final docBookingId =
            docData['bookingId'] ?? docData['id'] ?? docData['preBookingId'];

        if (docId == scannedBookingId ||
            docBookingId == scannedBookingId ||
            docData['bookingId'] == scannedBookingId ||
            docData['id'] == scannedBookingId ||
            docData['preBookingId'] == scannedBookingId ||
            docData['documentId'] == scannedBookingId) {
          print(
              '🔍 Excluding current scanned booking: $scannedBookingId (doc: $docId)');
          return false;
        }
      }

      final isForCurrentTrip = activeTripId == null ||
          docData['tripId'] == activeTripId ||
          docData['tripId'] == null;

      final shouldCount = docData['route'] == route &&
          (docData['status'] == 'paid' ||
              docData['status'] == 'pending_payment') &&
          docData['boardingStatus'] != 'boarded' &&
          isForCurrentTrip;

      if (shouldCount) {
        countedBookingIds.add(docId);
        print(
            '✅ Counting pre-booking: $docId (quantity: ${docData['quantity']})');
      }

      return shouldCount;
    }).fold<int>(0, (sum, doc) {
      final docData = doc.data();
      return sum + ((docData['quantity'] as int?) ?? 1);
    });
  }

  final totalPassengers = currentPassengerCount + preBookedPassengers;
  final newPassengerCount = totalPassengers + quantity;

  if (newPassengerCount > 27) {
    throw Exception(
        'Cannot add $quantity passengers. Bus capacity limit (27) would be exceeded. Current: $currentPassengerCount boarded + $preBookedPassengers pre-booked = $totalPassengers total');
  }

  final type = data['type'] ?? '';
  if (type == 'preBooking') {
    await _processPreBooking(data, user, conductorDoc, quantity, qrDataString);
  } else {
    if (type == 'preTicket') {
      final passengerDirection = data['direction'];
      final passengerPlaceCollection = data['placeCollection'];

      if (passengerDirection != null && passengerPlaceCollection != null) {
        final isDirectionCompatible = await DirectionValidationService
            .validateDirectionCompatibilityByCollection(
          passengerRoute: route,
          passengerPlaceCollection: passengerPlaceCollection,
          conductorUid: user.uid,
        );

        if (!isDirectionCompatible) {
          final activeTrip = conductorData['activeTrip'];
          final conductorDirection = activeTrip?['direction'] ?? 'Unknown';

          throw Exception(
              'Direction mismatch! Your ticket is for "$passengerDirection" but the conductor is currently on "$conductorDirection" trip. Please wait for the correct direction or contact the conductor.');
        }
      }
    }

    await _processPreTicket(data, user, conductorDoc, quantity, qrDataString);
  }
}

Future<int> _getNextTicketNumber(
    String conductorId, String formattedDate) async {
  try {
    final ticketsSnapshot = await FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorId)
        .collection('remittance')
        .doc(formattedDate)
        .collection('tickets')
        .get();

    return ticketsSnapshot.docs.length + 1;
  } catch (e) {
    print('❌ Error getting next ticket number: $e');
    return 1;
  }
}

Future<void> _processPreTicket(Map<String, dynamic> data, User user,
    QuerySnapshot conductorDoc, int quantity, String qrDataString) async {
  final conductorDocId = conductorDoc.docs.first.id;
  final conductorData = conductorDoc.docs.first.data() as Map<String, dynamic>;
  final activeTripId = conductorData['activeTrip']?['tripId'];
  final now = DateTime.now();
  final formattedDate =
      "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

  print('\n🔍 === STARTING PRE-TICKET SCAN PROCESS ===');
  print('🔍 Conductor ID: $conductorDocId');
  print('🔍 Active Trip ID: $activeTripId');
  print('🔍 Quantity: $quantity');
  print('🔍 QR Data: $data');

  final preTicketsQuery = await FirebaseFirestore.instance
      .collectionGroup('preTickets')
      .where('qrData', isEqualTo: qrDataString)
      .where('status', isEqualTo: 'pending')
      .get();

  if (preTicketsQuery.docs.isEmpty) {
    throw Exception('No pending pre-ticket found with this QR code.');
  }

  final pendingPreTicket = preTicketsQuery.docs.first;
  final preTicketData = pendingPreTicket.data();

  final userId = preTicketData['userId'];

  print('🔍 Pre-ticket userId: $userId');
  print('🔍 Pre-ticket data: $preTicketData');

  if (userId == null) {
    print('⚠️ WARNING: Pre-ticket userId is null!');
  }

  if (preTicketData['status'] == 'boarded') {
    throw Exception('This pre-ticket has already been scanned and boarded.');
  }

  await pendingPreTicket.reference.update({
    'status': 'boarded',
    'boardedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'scannedAt': FieldValue.serverTimestamp(),
    'tripId': activeTripId,
  });

  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .collection('preTickets')
      .doc(pendingPreTicket.id)
      .set({
    'qrData': qrDataString,
    'originalDocumentId': pendingPreTicket.id,
    'originalCollection': pendingPreTicket.reference.parent.path,
    'scannedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'qr': true,
    'status': 'boarded',
    'data': data,
    'tripId': activeTripId,
    'from': data['from'],
    'to': data['to'],
    'quantity': quantity,
    'userId': userId,
    'totalFare': data['totalFare'] ?? data['amount'] ?? data['fare'],
    'route': data['route'],
    'direction': data['direction'],
  });

  print('✅ Saved pre-ticket with userId: $userId');

  try {
    final ticketNumber =
        await _getNextTicketNumber(conductorDocId, formattedDate);
    final ticketDocId = 'ticket $ticketNumber';

    final remittanceData = {
      'active': true,
      'discountAmount': '0.00',
      'discountBreakdown': data['discountBreakdown'] ?? [],
      'documentId': pendingPreTicket.id,
      'documentType': 'preTicket',
      'endKm': data['toKm'] ?? 0,
      'farePerPassenger': data['passengerFares'] ?? [data['fare']],
      'from': data['from'],
      'quantity': quantity,
      'scannedBy': user.uid,
      'startKm': data['fromKm'] ?? 0,
      'status': 'boarded',
      'ticketType': 'preTicket',
      'timestamp': FieldValue.serverTimestamp(),
      'to': data['to'],
      'totalFare':
          (data['totalFare'] ?? data['amount'] ?? data['fare'] ?? '0.00')
              .toString(),
      'totalKm': (data['toKm'] ?? 0) - (data['fromKm'] ?? 0),
      'route': data['route'],
      'direction': data['direction'],
      'conductorId': conductorDocId,
      'tripId': activeTripId,
      'createdAt': FieldValue.serverTimestamp(),
      'scannedAt': FieldValue.serverTimestamp(),
      'boardedAt': FieldValue.serverTimestamp(),
      'userId': userId,
    };

    await FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorDocId)
        .collection('remittance')
        .doc(formattedDate)
        .collection('tickets')
        .doc(ticketDocId)
        .set(remittanceData);

    await FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorDocId)
        .collection('remittance')
        .doc(formattedDate)
        .set({
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print(
        '✅ Pre-ticket saved to remittance/tickets collection as $ticketDocId');
  } catch (e) {
    print('❌ Error saving pre-ticket to remittance: $e');
  }

  try {
    final dailyTripDoc = await FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorDocId)
        .collection('dailyTrips')
        .doc(formattedDate)
        .get();

    if (dailyTripDoc.exists) {
      final dailyTripData = dailyTripDoc.data();
      final currentTrip = dailyTripData?['currentTrip'] ?? 1;
      final tripCollection = 'trip$currentTrip';

      await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorDocId)
          .collection('dailyTrips')
          .doc(formattedDate)
          .collection(tripCollection)
          .doc('preTickets')
          .collection('preTickets')
          .doc(pendingPreTicket.id)
          .set({
        'from': data['from'],
        'to': data['to'],
        'quantity': quantity,
        'totalFare': data['totalFare'] ?? data['amount'] ?? data['fare'],
        'status': 'boarded',
        'scannedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
        'tripId': activeTripId,
        'qrData': qrDataString,
        'userId': userId,
        'route': data['route'],
        'direction': data['direction'],
        'ticketType': 'preTicket',
      });

      print('✅ Pre-ticket saved to dailyTrips collection');
    }
  } catch (e) {
    print('❌ Error saving pre-ticket to dailyTrips: $e');
  }

  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .update({'passengerCount': FieldValue.increment(quantity)});

  print('✅ Incremented passengerCount by $quantity');
  print('✅ === PRE-TICKET SCAN COMPLETE ===\n');
}

Future<void> _processPreBooking(Map<String, dynamic> data, User user,
    QuerySnapshot conductorDoc, int quantity, String qrDataString) async {
  final conductorDocId = conductorDoc.docs.first.id;
  final conductorData = conductorDoc.docs.first.data() as Map<String, dynamic>;
  final activeTripId = conductorData['activeTrip']?['tripId'];
  final now = DateTime.now();
  final formattedDate =
      "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

  print('\n🔍 === STARTING PRE-BOOKING SCAN PROCESS ===');
  print('🔍 Conductor ID: $conductorDocId');
  print('🔍 Active Trip ID: $activeTripId');
  print('🔍 QR Data: $data');

  DocumentSnapshot? paidPreBooking;
  Map<String, dynamic>? preBookingData;
  String? bookingId;
  String? userId;

  final dataBookingId = data['bookingId'] ?? data['id'];

  // ✅ STRATEGY 1: Search in conductor's collection (for bookings that are already paid and saved)
  if (dataBookingId != null) {
    print(
        '🔍 Strategy 1: Searching in conductor collection by booking ID: $dataBookingId');

    try {
      final directBooking = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorDocId)
          .collection('preBookings')
          .doc(dataBookingId)
          .get();

      if (directBooking.exists) {
        final bookingData = directBooking.data()!;
        final bookingStatus = bookingData['status'] ?? '';
        print(
            '🔍 Found booking in conductor collection: status=$bookingStatus');

        if (bookingStatus == 'paid' || bookingStatus == 'boarded') {
          paidPreBooking = directBooking;
          preBookingData = bookingData;
          bookingId = dataBookingId;
          userId = bookingData['userId'];
          print('✅ Found valid pre-booking in conductor collection');
        }
      }
    } catch (e) {
      print('⚠️ Error searching conductor collection: $e');
    }
  }

  // ✅ STRATEGY 2: Search in USER's collection (for newly paid bookings)
  if (paidPreBooking == null && dataBookingId != null) {
    print(
        '🔍 Strategy 2: Searching in user collections by booking ID: $dataBookingId');

    // Get userId from QR data
    final qrUserId = data['userId'];

    if (qrUserId != null) {
      try {
        print(
            '🔍 Searching in user collection: users/$qrUserId/preBookings/$dataBookingId');

        final userBooking = await FirebaseFirestore.instance
            .collection('users')
            .doc(qrUserId)
            .collection('preBookings')
            .doc(dataBookingId)
            .get();

        if (userBooking.exists) {
          final bookingData = userBooking.data()!;
          final bookingStatus = bookingData['status'] ?? '';
          print('🔍 Found booking in user collection: status=$bookingStatus');

          if (bookingStatus == 'paid') {
            // ✅ Found a PAID booking in user collection!
            preBookingData = bookingData;
            bookingId = dataBookingId;
            userId = qrUserId;
            print('✅ Found PAID pre-booking in user collection');

            // We'll use this data but note that there's no document snapshot
            // We'll create the conductor collection entry after boarding
          } else if (bookingStatus == 'boarded') {
            throw Exception(
                'This pre-booking has already been scanned and boarded.');
          } else {
            print('⚠️ Booking found but status is: $bookingStatus');
          }
        } else {
          print('⚠️ No booking found in user collection');
        }
      } catch (e) {
        print('⚠️ Error searching user collection: $e');
      }
    } else {
      print('⚠️ No userId in QR data, cannot search user collection');
    }
  }

  // ✅ STRATEGY 3: Search by QR data string (fallback)
  if (paidPreBooking == null && preBookingData == null) {
    print('🔍 Strategy 3: Searching by QR data string');
    try {
      final preBookingsQuery = await FirebaseFirestore.instance
          .collectionGroup('preBookings')
          .where('qrData', isEqualTo: qrDataString)
          .get();

      print('🔍 Found ${preBookingsQuery.docs.length} matching QR codes');

      for (var doc in preBookingsQuery.docs) {
        final docData = doc.data();
        final docStatus = docData['status'] ?? '';
        final docRoute = docData['route'] ?? '';

        print('🔍 Checking doc ${doc.id}: status=$docStatus, route=$docRoute');

        if (docRoute == data['route'] &&
            (docStatus == 'paid' || docStatus == 'boarded')) {
          paidPreBooking = doc;
          preBookingData = docData;
          bookingId = doc.id;
          userId = docData['userId'];
          print('✅ Found valid pre-booking by QR data');
          break;
        }
      }
    } catch (e) {
      print('⚠️ Error searching by QR data: $e');
    }
  }

  // ✅ Check if we found any valid booking
  if (preBookingData == null) {
    print('❌ No pre-booking found after all search strategies');
    throw Exception(
        'No paid pre-booking found with this QR code. Please ensure payment is completed.');
  }

  if (userId == null) {
    userId = preBookingData['userId'] ?? data['userId'];
  }

  print('✅ Processing pre-booking: $bookingId');
  print('✅ User ID: $userId');
  print('✅ Current status: ${preBookingData['status']}');

  final wasAlreadyBoarded = preBookingData['status'] == 'boarded';

  if (wasAlreadyBoarded) {
    throw Exception('This pre-booking has already been scanned and boarded.');
  }

  // ✅ Update user's booking to boarded (always exists in user collection)
  if (userId != null && bookingId != null) {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('preBookings')
          .doc(bookingId)
          .update({
        'status': 'boarded',
        'boardingStatus': 'boarded',
        'boardedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
        'scannedAt': FieldValue.serverTimestamp(),
        'tripId': activeTripId,
      });
      print('✅ Updated user preBooking to "boarded"');
    } catch (e) {
      print('⚠️ Failed to update user preBooking: $e');
    }
  }

  // ✅ Update or create conductor's preBooking collection entry
  try {
    final conductorPreBookingRef = FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorDocId)
        .collection('preBookings')
        .doc(bookingId);

    final conductorPreBookingSnap = await conductorPreBookingRef.get();

    if (conductorPreBookingSnap.exists) {
      // Update existing entry
      await conductorPreBookingRef.update({
        'status': 'boarded',
        'boardingStatus': 'boarded',
        'boardedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
        'scannedAt': FieldValue.serverTimestamp(),
        'qr': true,
        'tripId': activeTripId,
      });
      print('✅ Updated conductor preBookings to "boarded"');
    } else {
      // Create new entry (for bookings that were only in user collection)
      await conductorPreBookingRef.set({
        ...preBookingData,
        'status': 'boarded',
        'boardingStatus': 'boarded',
        'boardedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
        'scannedAt': FieldValue.serverTimestamp(),
        'qr': true,
        'tripId': activeTripId,
        'userId': userId,
        'from': data['from'] ?? preBookingData['from'],
        'to': data['to'] ?? preBookingData['to'],
        'quantity': quantity,
        'route': data['route'] ?? preBookingData['route'],
        'direction': data['direction'] ?? preBookingData['direction'],
        'active': true,
      }, SetOptions(merge: true));
      print('✅ Created conductor preBookings as "boarded"');
    }
  } catch (e) {
    print('⚠️ Error updating conductor preBooking: $e');
  }

  // ✅ Save to remittance (tickets collection)
  try {
    print('🔍 Saving to remittance tickets collection with ID: $bookingId');

    final remittanceTicketRef = FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorDocId)
        .collection('remittance')
        .doc(formattedDate)
        .collection('tickets')
        .doc(bookingId);

    final existingTicket = await remittanceTicketRef.get();

    if (existingTicket.exists) {
      // Update existing ticket
      await remittanceTicketRef.update({
        'status': 'boarded',
        'scannedBy': user.uid,
        'scannedAt': FieldValue.serverTimestamp(),
        'boardedAt': FieldValue.serverTimestamp(),
        'boardingStatus': 'boarded',
        'tripId': activeTripId,
        'active': true,
      });
      print('✅ Updated existing remittance ticket to "boarded"');
    } else {
      // Create new ticket
      final remittanceData = {
        'active': true,
        'discountAmount':
            preBookingData['discountAmount']?.toString() ?? '0.00',
        'discountBreakdown': preBookingData['discountBreakdown'] ?? [],
        'documentId': bookingId,
        'documentType': 'preBooking',
        'endKm': data['toKm'] ?? preBookingData['toKm'] ?? 0,
        'farePerPassenger': preBookingData['passengerFares'] ??
            [preBookingData['amount'] ?? '0.00'],
        'from': data['from'] ?? preBookingData['from'],
        'quantity': quantity,
        'scannedBy': user.uid,
        'startKm': data['fromKm'] ?? preBookingData['fromKm'] ?? 0,
        'status': 'boarded',
        'ticketType': 'preBooking',
        'timestamp': FieldValue.serverTimestamp(),
        'to': data['to'] ?? preBookingData['to'],
        'totalFare':
            (data['amount'] ?? preBookingData['amount'] ?? '0.00').toString(),
        'totalKm': (data['toKm'] ?? preBookingData['toKm'] ?? 0) -
            (data['fromKm'] ?? preBookingData['fromKm'] ?? 0),
        'route': data['route'] ?? preBookingData['route'],
        'direction': data['direction'] ?? preBookingData['direction'],
        'conductorId': conductorDocId,
        'tripId': activeTripId,
        'createdAt': FieldValue.serverTimestamp(),
        'scannedAt': FieldValue.serverTimestamp(),
        'boardedAt': FieldValue.serverTimestamp(),
        'userId': userId,
        'bookingId': bookingId,
        'preBookingId': bookingId,
      };

      await remittanceTicketRef.set(remittanceData);
      print('✅ Created new remittance ticket with ID: $bookingId');
    }

    // Update remittance date document
    await FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorDocId)
        .collection('remittance')
        .doc(formattedDate)
        .set({
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  } catch (e) {
    print('❌ Error saving to remittance: $e');
  }

  // ✅ Save to dailyTrips
  try {
    final dailyTripDoc = await FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorDocId)
        .collection('dailyTrips')
        .doc(formattedDate)
        .get();

    if (dailyTripDoc.exists) {
      final dailyTripData = dailyTripDoc.data();
      final currentTrip = dailyTripData?['currentTrip'] ?? 1;
      final tripCollection = 'trip$currentTrip';

      await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorDocId)
          .collection('dailyTrips')
          .doc(formattedDate)
          .collection(tripCollection)
          .doc('preBookings')
          .collection('preBookings')
          .doc(bookingId)
          .set({
        'from': data['from'] ?? preBookingData['from'],
        'to': data['to'] ?? preBookingData['to'],
        'fromKm': data['fromKm'] ?? preBookingData['fromKm'],
        'toKm': data['toKm'] ?? preBookingData['toKm'],
        'quantity': quantity,
        'totalFare': data['amount'] ?? preBookingData['amount'],
        'status': 'boarded',
        'scannedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
        'tripId': activeTripId,
        'qrData': qrDataString,
        'userId': userId,
        'route': data['route'] ?? preBookingData['route'],
        'direction': data['direction'] ?? preBookingData['direction'],
        'ticketType': 'preBooking',
        'bookingId': bookingId,
        'active': true,
        'boardedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Pre-booking saved to dailyTrips collection');
    }
  } catch (e) {
    print('❌ Error saving to dailyTrips: $e');
  }

  // ✅ Add to scannedQRCodes collection
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .collection('scannedQRCodes')
      .add({
    'type': 'preBooking',
    'bookingId': bookingId,
    'preBookingId': bookingId,
    'id': bookingId,
    'documentId': bookingId,
    'qrData': qrDataString,
    'scannedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'data': data,
    'tripId': activeTripId,
    'from': data['from'] ?? preBookingData['from'],
    'to': data['to'] ?? preBookingData['to'],
    'quantity': quantity,
    'userId': userId,
    'totalFare': data['amount'] ?? preBookingData['amount'],
    'route': data['route'] ?? preBookingData['route'],
    'status': 'boarded',
    'boardingStatus': 'boarded',
  });
  print('✅ Added to scannedQRCodes');

  // ✅ Increment passenger count
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .update({'passengerCount': FieldValue.increment(quantity)});
  print('✅ Incremented passengerCount by $quantity');

  print('✅ === PRE-BOOKING SCAN COMPLETE ===');
  print('✅ Pre-booking $bookingId successfully boarded\n');
}
