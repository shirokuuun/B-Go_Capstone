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
  final Map<String, bool> _printingStates = {};

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

  Future<void> _printManualTicket(Map<String, dynamic> ticket) async {
    final ticketId = ticket['id'] as String;

    setState(() {
      _printingStates[ticketId] = true;
    });

    try {
      // If not connected to printer, show connection dialog
      if (!_printerService.isConnected) {
        await ThermalPrinterService.showPrinterConnectionDialog(
          context,
          (ip, port) async {
            final connected = await _printerService.connectPrinter(ip, port);
            if (!connected) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to connect to printer'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              setState(() {
                _printingStates[ticketId] = false;
              });
              return;
            }

            // Now print after successful connection
            await _performPrint(ticket, ticketId);
          },
        );
      } else {
        // Already connected, just print
        await _performPrint(ticket, ticketId);
      }
    } catch (e) {
      print('Error printing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _printingStates[ticketId] = false;
      });
    }
  }

  Future<void> _performPrint(
      Map<String, dynamic> ticket, String ticketId) async {
    try {
      // Extract ticket data
      final from = ticket['from']?.toString() ?? 'N/A';
      final to = ticket['to']?.toString() ?? 'N/A';
      final fromKm =
          ticket['fromKm']?.toString() ?? ticket['startKm']?.toString() ?? '0';
      final toKm =
          ticket['toKm']?.toString() ?? ticket['endKm']?.toString() ?? '0';

      String baseFare = '0.00';
      final fareData = ticket['farePerPassenger'];
      if (fareData != null) {
        if (fareData is List && fareData.isNotEmpty) {
          baseFare = fareData.first.toString();
        } else if (fareData is num) {
          baseFare = fareData.toStringAsFixed(2);
        } else if (fareData is String) {
          baseFare = fareData;
        }
      }

      final quantity = (ticket['quantity'] as num?)?.toInt() ?? 1;
      final totalFare = ticket['totalFare']?.toString() ?? '0.00';
      final discountAmount = ticket['discountAmount']?.toString() ?? '0.00';

      List<String>? discountBreakdown;
      if (ticket['discountBreakdown'] != null) {
        discountBreakdown = List<String>.from(
            (ticket['discountBreakdown'] as List).map((e) => e.toString()));
      }

      // Print receipt
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Receipt printed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to print receipt'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      setState(() {
        _printingStates[ticketId] = false;
      });
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
      if (result == true) {
        _refreshPassengerCount();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR code scanned and stored successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (result == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to process QR code.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required to scan QR codes.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _refreshPassengerCount() {
    setState(() {});
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
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.only(left: 26),
                  child: Text(
                    "Manually Ticketed Passengers:",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    key: const ValueKey('manual_tickets_future'),
                    future: _getManualTickets(),
                    builder: (context, snapshot) {
                      if (!mounted) {
                        return const SizedBox.shrink();
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      } else if (!snapshot.hasData ||
                          snapshot.data == null ||
                          snapshot.data!.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: const Center(
                            child: Text(
                              'No manually ticketed passengers yet',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      }

                      final manualTickets = snapshot.data!;
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: manualTickets.length,
                        itemBuilder: (context, index) {
                          final ticket = manualTickets[index];
                          final ticketId = ticket['id'] as String;
                          final status = ticket['status'] ?? 'boarded';
                          final isAccomplished = status == 'accomplished';
                          final isPrinting = _printingStates[ticketId] ?? false;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isAccomplished
                                  ? Colors.green[50]
                                  : Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAccomplished
                                    ? Colors.green[300]!
                                    : Colors.blue[300]!,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${ticket['from']} → ${ticket['to']}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Passengers: ${ticket['quantity']}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black54,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Fare: ₱${ticket['totalFare']}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isAccomplished
                                                ? Colors.green[100]
                                                : Colors.blue[100],
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            isAccomplished
                                                ? 'ACCOMPLISHED'
                                                : 'BOARDED',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isAccomplished
                                                  ? Colors.green[700]
                                                  : Colors.blue[700],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Print button
                                            ElevatedButton(
                                              onPressed: isPrinting
                                                  ? null
                                                  : () => _printManualTicket(
                                                      ticket),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF0091AD),
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                minimumSize: const Size(40, 36),
                                              ),
                                              child: isPrinting
                                                  ? const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                    )
                                                  : const Icon(Icons.print,
                                                      size: 18),
                                            ),
                                            if (!isAccomplished) ...[
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () =>
                                                    _markTicketAccomplished(
                                                        ticket),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.green[600],
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Mark Done',
                                                  style:
                                                      TextStyle(fontSize: 11),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getManualTickets() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final conductorDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (conductorDoc.docs.isEmpty) return [];

      final conductorId = conductorDoc.docs.first.id;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      return await RouteService.getManualTickets(conductorId, today);
    } catch (e) {
      print('Error fetching manual tickets: $e');
      return [];
    }
  }

  Future<void> _markTicketAccomplished(Map<String, dynamic> ticket) async {
    if (!mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final conductorDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (conductorDoc.docs.isEmpty) return;

      final conductorId = conductorDoc.docs.first.id;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final ticketId = ticket['id'] as String;
      final quantity = ticket['quantity'] as int;
      final from = ticket['from'] as String;
      final to = ticket['to'] as String;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Passenger Drop-off'),
          content: Text(
              'Mark $quantity passenger(s) from $from to $to as accomplished?\n\nThis will decrease the passenger count by $quantity.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        await PassengerStatusService.markManualTicketAccomplished(
          conductorId: conductorId,
          date: today,
          ticketId: ticketId,
          quantity: quantity,
          from: from,
          to: to,
        );

        if (mounted) {
          setState(() {});
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$quantity passenger(s) from $from to $to marked as accomplished. Passenger count decreased by $quantity.',
              ),
              backgroundColor: Colors.green[600],
              duration: const Duration(seconds: 3),
            ),
          );
        }

        print(
            'Manual ticket accomplished: $ticketId, decremented passenger count by $quantity');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      print('Error marking ticket accomplished: $e');
    }
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
              Navigator.of(context).pop(true);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Scan failed: ${e.toString().replaceAll('Exception: ', '')}'),
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
  final preBookingsQuery = activeTripId != null
      ? await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorDocId)
          .collection('preBookings')
          .where('tripId', isEqualTo: activeTripId)
          .get()
      : await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorDocId)
          .collection('preBookings')
          .get();

  int preBookedPassengers = 0;
  if (preBookingsQuery.docs.isNotEmpty) {
    preBookedPassengers = preBookingsQuery.docs.where((doc) {
      final data = doc.data();
      final isForCurrentTrip = activeTripId == null ||
          data['tripId'] == activeTripId ||
          data['tripId'] == null;
      return data['route'] == route &&
          (data['status'] == 'paid' || data['status'] == 'pending_payment') &&
          data['boardingStatus'] != 'boarded' &&
          isForCurrentTrip;
    }).fold<int>(0, (sum, doc) {
      final data = doc.data();
      return sum + ((data['quantity'] as int?) ?? 1);
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

// ✅ UPDATED _processPreTicket WITH userId FIX
Future<void> _processPreTicket(Map<String, dynamic> data, User user,
    QuerySnapshot conductorDoc, int quantity, String qrDataString) async {
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

  // ✅ CRITICAL FIX: Get userId from the pre-ticket
  final userId = preTicketData['userId'];

  print('🔍 Pre-ticket userId: $userId');
  print('🔍 Pre-ticket data: $preTicketData');

  if (userId == null) {
    print('⚠️ WARNING: Pre-ticket userId is null!');
  }

  if (preTicketData['status'] == 'boarded') {
    throw Exception('This pre-ticket has already been scanned and boarded.');
  }

  final conductorDocId = conductorDoc.docs.first.id;
  final conductorData = conductorDoc.docs.first.data() as Map<String, dynamic>;
  final activeTripId = conductorData['activeTrip']?['tripId'];
  final now = DateTime.now();
  final formattedDate =
      "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

  await pendingPreTicket.reference.update({
    'status': 'boarded',
    'boardedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'scannedAt': FieldValue.serverTimestamp(),
    'tripId': activeTripId,
  });

  // ✅ Store in conductor's preTickets collection WITH userId
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
    'userId': userId, // ✅ CRITICAL: Save the userId here
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
      'userId': userId, // ✅ Also save userId in remittance
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
        'userId': userId, // ✅ Save userId in dailyTrips too
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

  print(
      '✅ Pre-ticket processed successfully. Incremented passengerCount by $quantity');
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

Future<void> _processPreBooking(Map<String, dynamic> data, User user,
    QuerySnapshot conductorDoc, int quantity, String qrDataString) async {
  final conductorDocId = conductorDoc.docs.first.id;
  final conductorData = conductorDoc.docs.first.data() as Map<String, dynamic>;
  final activeTripId = conductorData['activeTrip']?['tripId'];

  print('\n🔍 === STARTING PRE-BOOKING SCAN PROCESS ===');
  print('🔍 Conductor ID: $conductorDocId');
  print('🔍 Active Trip ID: $activeTripId');
  print('🔍 QR Data: $data');

  DocumentSnapshot? paidPreBooking;
  Map<String, dynamic>? preBookingData;
  String? bookingId;
  String? userId;

  // ✅ STRATEGY 1: Search by booking ID
  final dataBookingId = data['bookingId'] ?? data['id'];
  if (dataBookingId != null) {
    print('🔍 Strategy 1: Searching by booking ID: $dataBookingId');

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
        print('🔍 Found booking: status=$bookingStatus');

        // ✅ Accept both 'paid' and 'boarded' status
        if (bookingStatus == 'paid' || bookingStatus == 'boarded') {
          paidPreBooking = directBooking;
          preBookingData = bookingData;
          bookingId = dataBookingId;
          userId = bookingData['userId'];
          print('✅ Found valid pre-booking by ID');
        }
      }
    } catch (e) {
      print('⚠️ Error searching by booking ID: $e');
    }
  }

  // ✅ STRATEGY 2: Search by QR data string
  if (paidPreBooking == null) {
    print('🔍 Strategy 2: Searching by QR data string');
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

  // ✅ STRATEGY 3: Search by route details
  if (paidPreBooking == null && data['from'] != null && data['to'] != null) {
    print('🔍 Strategy 3: Searching by from/to/quantity');
    try {
      final query = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorDocId)
          .collection('preBookings')
          .where('from', isEqualTo: data['from'])
          .where('to', isEqualTo: data['to'])
          .where('quantity', isEqualTo: quantity)
          .get();

      for (var doc in query.docs) {
        final docData = doc.data();
        final docStatus = docData['status'] ?? '';

        if (docStatus == 'paid' || docStatus == 'boarded') {
          paidPreBooking = doc;
          preBookingData = docData;
          bookingId = doc.id;
          userId = docData['userId'];
          print('✅ Found valid pre-booking by route details');
          break;
        }
      }
    } catch (e) {
      print('⚠️ Error searching by route details: $e');
    }
  }

  if (paidPreBooking == null || preBookingData == null) {
    print('❌ No pre-booking found after all search strategies');
    throw Exception(
        'No paid pre-booking found with this QR code. Please ensure payment is completed.');
  }

  // ✅ Get userId if not found yet
  if (userId == null) {
    userId = preBookingData['userId'] ?? data['userId'];
  }

  print('✅ Processing pre-booking: $bookingId');
  print('✅ User ID: $userId');

  // ✅ CRITICAL FIX: Update status from "paid" → "boarded" in original location
  await paidPreBooking.reference.update({
    'status': 'boarded', // ✅ CRITICAL: Change from "paid" to "boarded"
    'boardingStatus': 'boarded',
    'boardedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'scannedAt': FieldValue.serverTimestamp(),
    'tripId': activeTripId,
  });
  print('✅ Updated original pre-booking to "boarded"');

  // ✅ Update in conductor's preBookings collection (if exists)
  try {
    final conductorPreBookingRef = FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorDocId)
        .collection('preBookings')
        .doc(bookingId);

    final conductorPreBookingSnap = await conductorPreBookingRef.get();
    if (conductorPreBookingSnap.exists) {
      await conductorPreBookingRef.update({
        'status': 'boarded', // ✅ CRITICAL: Change to "boarded"
        'boardingStatus': 'boarded',
        'boardedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
        'scannedAt': FieldValue.serverTimestamp(),
        'qr': true,
        'tripId': activeTripId,
      });
      print('✅ Updated conductor preBookings to "boarded"');
    } else {
      // ✅ If doesn't exist, create it as "boarded"
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
      }, SetOptions(merge: true));
      print('✅ Created conductor preBookings as "boarded"');
    }
  } catch (e) {
    print('⚠️ Error updating conductor preBooking: $e');
  }

  // ✅ Update in user's preBookings collection
  if (userId != null) {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('preBookings')
          .doc(bookingId)
          .update({
        'status': 'boarded', // ✅ CRITICAL: Change to "boarded"
        'boardingStatus': 'boarded',
        'boardedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
        'scannedAt': FieldValue.serverTimestamp(),
        'tripId': activeTripId,
      });
      print('✅ Updated user preBookings to "boarded"');
    } catch (e) {
      print('⚠️ Failed to update user preBooking: $e');
    }
  }

  // ✅ Add to scannedQRCodes collection as "boarded"
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .collection('scannedQRCodes')
      .add({
    'type': 'preBooking',
    'bookingId': bookingId,
    'preBookingId': bookingId, // ✅ For query compatibility
    'id': bookingId, // ✅ For query compatibility
    'documentId': bookingId, // ✅ For query compatibility
    'qrData': qrDataString,
    'originalDocumentId': paidPreBooking.id,
    'originalCollection': paidPreBooking.reference.parent.path,
    'scannedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'data': data,
    'tripId': activeTripId,
    'from': data['from'] ?? preBookingData['from'],
    'to': data['to'] ?? preBookingData['to'],
    'quantity': quantity,
    'userId': userId, // ✅ Include userId
    'totalFare':
        data['totalAmount'] ?? preBookingData['totalFare'] ?? data['amount'],
    'route': data['route'] ?? preBookingData['route'],
    'status': 'boarded', // ✅ CRITICAL: Start as "boarded"
    'boardingStatus': 'boarded',
  });
  print('✅ Added to scannedQRCodes as "boarded"');

  // ✅ Increment passenger count
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .update({'passengerCount': FieldValue.increment(quantity)});
  print('✅ Incremented passengerCount by $quantity');

  print('✅ === PRE-BOOKING SCAN COMPLETE ===');
  print('✅ Pre-booking $bookingId is now "boarded" and ready for geofencing\n');
}
