import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:b_go/pages/conductor/conductor_departure.dart';
import 'package:b_go/pages/conductor/sos.dart';
import 'package:b_go/pages/conductor/passenger_status_service.dart';
import 'package:b_go/services/direction_validation_service.dart';
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

  // Map display names to Firestore document names
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
    super.dispose();
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

    // Initialize places future after determining the correct collection
    if (!mounted) return;

    print('🔍 ConductorFrom: Route: "${widget.route}"');
    print('🔍 ConductorFrom: Selected collection: "$selectedPlaceCollection"');

    // Use the Firestore route name instead of the display name
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
          SnackBar(
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
      // No further action needed here; navigation handled in _ToSelectionPageConductor
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
        // Refresh passenger count after successful scan
        _refreshPassengerCount();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR code scanned and stored successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (result == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process QR code.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Camera permission is required to scan QR codes.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _refreshPassengerCount() {
    // Refresh the manual tickets list to update passenger count
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
                              icon: Icon(
                                Icons.sos,
                                color: Colors.red,
                                size: 24.0,
                              ),
                              tooltip: 'SOS',
                            ),
                            IconButton(
                              onPressed: _openQRScanner,
                              icon: Icon(
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
                  // Route directions display (not clickable during active trip)
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
                            const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                routeDirections.firstWhere((r) =>
                                    r['collection'] ==
                                    selectedPlaceCollection)['label']!,
                                style: GoogleFonts.outfit(
                                  fontSize: MediaQuery.of(context).size.width < 360 ? 14 : 16,
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
          SliverPadding(
            padding: const EdgeInsets.only(top: 20.0),
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
                              // Add safety check for mounted state
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
                                          // Reinitialize the future
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
                              
                              // Calculate responsive aspect ratio and font sizes
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
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  childAspectRatio: aspectRatio,
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

                // Manually Ticketed Passengers Section
                const Padding(
                  padding: EdgeInsets.only(left: 10),
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

                FutureBuilder<List<Map<String, dynamic>>>(
                  key: const ValueKey('manual_tickets_future'),
                  future: _getManualTickets(),
                  builder: (context, snapshot) {
                    // Add safety check for mounted state
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
                        final status = ticket['status'] ?? 'boarded';
                        final isAccomplished = status == 'accomplished';

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
                                      if (!isAccomplished) ...[
                                        const SizedBox(height: 8),
                                        ElevatedButton(
                                          onPressed: () =>
                                              _markTicketAccomplished(ticket),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green[600],
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                          ),
                                          child: const Text(
                                            'Mark Accomplished',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get manually ticketed passengers
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

      // Show confirmation dialog
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
        // Use the PassengerStatusService to handle the accomplishment
        // Import: import 'package:b_go/pages/conductor/passenger_status_service.dart';
        await PassengerStatusService.markManualTicketAccomplished(
          conductorId: conductorId,
          date: today,
          ticketId: ticketId,
          quantity: quantity,
          from: from,
          to: to,
        );

        // Refresh the UI
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

// Also add this import at the top of your conductor_from.dart file:
// import 'package:b_go/pages/conductor/passenger_status_service.dart';// Updated method for conductor_from.dart
// Replace your existing _markTicketAccomplished method with this:
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
    final screenWidth = size.width;
    
    // Calculate responsive values
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
                            const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
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

                                  // Check passenger count limit before proceeding
                                  final user =
                                      FirebaseAuth.instance.currentUser;
                                  if (user != null) {
                                    // Check capacity before creating ticket
                                    final conductorDoc = await FirebaseFirestore
                                        .instance
                                        .collection('conductors')
                                        .where('uid', isEqualTo: user.uid)
                                        .limit(1)
                                        .get();

                                    if (conductorDoc.docs.isNotEmpty) {
                                      final conductorData =
                                          conductorDoc.docs.first.data();
                                      final conductorDocId = conductorDoc.docs.first.id;
                                      final currentPassengerCount =
                                          conductorData['passengerCount'] ?? 0;
                                      
                                      // Get pre-booked passengers count (priority passengers)
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
                                        preBookedPassengers = preBookingsQuery.docs
                                            .where((doc) {
                                              final data = doc.data();
                                              final isForCurrentTrip = activeTripId == null || 
                                                  data['tripId'] == activeTripId || 
                                                  data['tripId'] == null;
                                              return data['route'] == route && 
                                                     (data['status'] == 'paid' || data['status'] == 'pending_payment') &&
                                                     data['boardingStatus'] != 'boarded' &&
                                                     isForCurrentTrip;
                                            })
                                            .fold<int>(0, (sum, doc) {
                                              final data = doc.data();
                                              return sum + ((data['quantity'] as int?) ?? 1);
                                            });
                                      }
                                      
                                      final totalPassengers = currentPassengerCount + preBookedPassengers;
                                      final newPassengerCount = totalPassengers + result['quantity'];

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

  // Get conductor document
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

  // Validate route match
  if (conductorRoute != route) {
    throw Exception(
        'Invalid route. You are a $conductorRoute conductor but trying to scan a $route ticket. Only $conductorRoute tickets can be scanned.');
  }

  // Check capacity before processing
  final conductorDocId = conductorDoc.docs.first.id;
  final currentPassengerCount = conductorData['passengerCount'] ?? 0;
  
  // Get pre-booked passengers count (priority passengers)
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
    preBookedPassengers = preBookingsQuery.docs
        .where((doc) {
          final data = doc.data();
          final isForCurrentTrip = activeTripId == null || 
              data['tripId'] == activeTripId || 
              data['tripId'] == null;
          return data['route'] == route && 
                 (data['status'] == 'paid' || data['status'] == 'pending_payment') &&
                 data['boardingStatus'] != 'boarded' &&
                 isForCurrentTrip;
        })
        .fold<int>(0, (sum, doc) {
          final data = doc.data();
          return sum + ((data['quantity'] as int?) ?? 1);
        });
  }
  
  final totalPassengers = currentPassengerCount + preBookedPassengers;
  final newPassengerCount = totalPassengers + quantity;
  
  if (newPassengerCount > 27) {
    throw Exception('Cannot add $quantity passengers. Bus capacity limit (27) would be exceeded. Current: $currentPassengerCount boarded + $preBookedPassengers pre-booked = $totalPassengers total');
  }

  // Check if this is a pre-booking or pre-ticket
  final type = data['type'] ?? '';
  if (type == 'preBooking') {
    await _processPreBooking(data, user, conductorDoc, quantity, qrDataString);
  } else {
    // Validate direction compatibility for pre-tickets
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
          // Get conductor's active trip direction for better error message
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

Future<void> _processPreTicket(Map<String, dynamic> data, User user,
    QuerySnapshot conductorDoc, int quantity, String qrDataString) async {
  // Find the pending pre-ticket
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

  // Check if already boarded
  if (preTicketData['status'] == 'boarded') {
    throw Exception('This pre-ticket has already been scanned and boarded.');
  }

  // Update pre-ticket status to "boarded"
  await pendingPreTicket.reference.update({
    'status': 'boarded',
    'boardedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'scannedAt': FieldValue.serverTimestamp(),
  });

  // Store in conductor's preTickets collection
  final conductorDocId = conductorDoc.docs.first.id;
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
    'qr': true,
    'status': 'boarded',
    'data': data,
  });

  // Increment passenger count
  await FirebaseFirestore.instance
      .collection('conductors')
      .doc(conductorDocId)
      .update({'passengerCount': FieldValue.increment(quantity)});
}

Future<void> _processPreBooking(Map<String, dynamic> data, User user,
    QuerySnapshot conductorDoc, int quantity, String qrDataString) async {
  // Find the paid pre-booking
  final preBookingsQuery = await FirebaseFirestore.instance
      .collectionGroup('preBookings')
      .where('qrData', isEqualTo: qrDataString)
      .where('status', isEqualTo: 'paid')
      .get();

  if (preBookingsQuery.docs.isEmpty) {
    throw Exception(
        'No paid pre-booking found with this QR code. Please ensure payment is completed.');
  }

  final paidPreBooking = preBookingsQuery.docs.first;
  final preBookingData = paidPreBooking.data();
  final bookingId = paidPreBooking.id; // this is the canonical booking id

  // Check if already boarded
  if (preBookingData['status'] == 'boarded' ||
      preBookingData['boardingStatus'] == 'boarded') {
    throw Exception('This pre-booking has already been scanned and boarded.');
  }

  // Update pre-booking status to "boarded"
  await paidPreBooking.reference.update({
    'status': 'boarded',
    'boardedAt': FieldValue.serverTimestamp(),
    'scannedBy': user.uid,
    'scannedAt': FieldValue.serverTimestamp(),
    'boardingStatus': 'boarded',
  });

  // Also force-update the conductor's preBookings document with the SAME booking id
  final conductorDocId = conductorDoc.docs.first.id;
  try {
    final conductorPreBookingRef = FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorDocId)
        .collection('preBookings')
        .doc(bookingId);

    final conductorPreBookingSnap = await conductorPreBookingRef.get();
    if (conductorPreBookingSnap.exists) {
      await conductorPreBookingRef.update({
        'status': 'boarded',
        'boardingStatus': 'boarded',
        'boardedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
        'scannedAt': FieldValue.serverTimestamp(),
        'qr': true,
      });
    } else {
      // As a fallback, create a compact scan log document in a separate subcollection
      await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorDocId)
          .collection('scannedQRCodes')
          .add({
        'bookingId': bookingId,
        'data': data,
        'scannedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
        'type': 'preBooking',
      });
    }
  } catch (_) {}

  // Update remittance ticket status for today (so Trips shows Boarded)
  try {
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final ticketsCol = FirebaseFirestore.instance
        .collection('conductors')
        .doc(conductorDocId)
        .collection('remittance')
        .doc(formattedDate)
        .collection('tickets');

    final ticketQuery = await ticketsCol
        .where('documentType', isEqualTo: 'preBooking')
        .where('documentId', isEqualTo: bookingId)
        .limit(1)
        .get();

    if (ticketQuery.docs.isNotEmpty) {
      await ticketsCol.doc(ticketQuery.docs.first.id).update({
        'status': 'boarded',
        'boardedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
      });
    }
  } catch (e) {
    // non-fatal
    print('⚠️ Failed to update remittance ticket to boarded: $e');
  }

  // IMPORTANT: Do NOT increment passengerCount here.
  // Pre-booked passengers are already counted in the dashboard's total capacity
  // calculation (boarded + preBooked). Moving to boarded should not add again.

  // Ensure passenger's own preBookings document is also updated to boarded
  try {
    final userId = preBookingData['userId'] ?? data['userId'];
    if (userId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('preBookings')
          .doc(bookingId)
          .update({
        'status': 'boarded',
        'boardedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
        'scannedAt': FieldValue.serverTimestamp(),
        'boardingStatus': 'boarded',
      });
    }
  } catch (e) {
    print('⚠️ Failed to update user preBooking to boarded: $e');
  }
}
