import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:b_go/pages/passenger/services/geofencing_service.dart';

class PreTicket extends StatefulWidget {
  final String? selectedRoute;
  const PreTicket({super.key, this.selectedRoute});

  @override
  State<PreTicket> createState() => _PreTicketState();
}

class _PreTicketState extends State<PreTicket> {
  final List<String> routeChoices = [
    'Batangas',
    'Rosario',
    'Mataas na Kahoy',
    'Mataas Na Kahoy Palengke',
    'Tiaong',
    'San Juan',
  ];

  // Map route to display names
  final Map<String, List<String>> routeLabels = {
    'Batangas': [
      'SM Lipa to Batangas City',
      'Batangas City to SM Lipa',
    ],
    'Rosario': [
      'SM Lipa to Rosario',
      'Rosario to SM Lipa',
    ],
    'Mataas na Kahoy': [
      'SM Lipa to Mataas na Kahoy',
      'Mataas na Kahoy to SM Lipa',
    ],
    'Mataas Na Kahoy Palengke': [
      'Lipa Palengke to Mataas na Kahoy',
      'Mataas na Kahoy to Lipa Palengke',
    ],
    'Tiaong': [
      'SM Lipa to Tiaong',
      'Tiaong to SM Lipa',
    ],
    'San Juan': [
      'SM Lipa to San Juan',
      'San Juan to SM Lipa',
    ],
  };

  late String selectedRoute;
  String selectedPlaceCollection = 'Place';
  int directionIndex = 0;
  late Future<List<Map<String, dynamic>>> placesFuture;
  String? verifiedIDType;

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
    selectedRoute = widget.selectedRoute ?? 'Rosario';
    placesFuture = RouteService.fetchPlaces(
        _routeFirestoreNames[selectedRoute] ?? selectedRoute,
        placeCollection: 'Place');
    _fetchVerifiedIDType();
    GeofencingService().startMonitoring();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Custom snackbar widget
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

  Future<void> _fetchVerifiedIDType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('VerifyID')
          .doc('id')
          .get();

      if (doc.exists) {
        final data = doc.data();
        final status = data?['status'];
        final idType = data?['idType'];

        if (status == 'verified' && idType != null) {
          setState(() {
            verifiedIDType = idType;
          });
        }
      }
    } catch (e) {
      print('Error fetching verified ID type: $e');
    }
  }

  // Method to mark ticket as boarded (called when conductor scans QR)
  static Future<void> markTicketAsBoarded(
      String ticketId, String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('preTickets')
          .doc(ticketId)
          .update({
        'status': 'boarded',
        'boardedAt': DateTime.now(),
      });
      print('✅ Pre-ticket marked as boarded: $ticketId');
    } catch (e) {
      print('Error marking ticket as boarded: $e');
    }
  }

  static Future<void> markTicketAsAccomplished(
      String ticketId, String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('preTickets')
          .doc(ticketId)
          .update({
        'status': 'accomplished',
        'accomplishedAt': DateTime.now(),
      });
      print('✅ Pre-ticket marked as accomplished: $ticketId');
    } catch (e) {
      print('Error marking pre-ticket as accomplished: $e');
    }
  }

  // Method to check if a ticket can be marked as accomplished
  static Future<bool> canMarkTicketAccomplished(
      String ticketId, String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('preTickets')
          .doc(ticketId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final status = data?['status'];
        return status == 'boarded';
      }
      return false;
    } catch (e) {
      print('Error checking ticket status: $e');
      return false;
    }
  }

  void _onRouteChanged(String? newRoute) {
    if (newRoute != null && newRoute != selectedRoute) {
      setState(() {
        selectedRoute = newRoute;
        directionIndex = 0;
        selectedPlaceCollection = 'Place';
        // Use the Firestore route name instead of the display name
        String firestoreRouteName = _routeFirestoreNames[newRoute] ?? newRoute;
        placesFuture = RouteService.fetchPlaces(firestoreRouteName,
            placeCollection: selectedPlaceCollection);
      });
    }
  }

  void _toggleDirection() {
    setState(() {
      directionIndex = directionIndex == 0 ? 1 : 0;
      selectedPlaceCollection = directionIndex == 0 ? 'Place' : 'Place 2';
      // Use the Firestore route name instead of the display name
      String firestoreRouteName =
          _routeFirestoreNames[selectedRoute] ?? selectedRoute;
      placesFuture = RouteService.fetchPlaces(firestoreRouteName,
          placeCollection: selectedPlaceCollection);
    });
  }

  void _showToSelectionPage(Map<String, dynamic> fromPlace,
      List<Map<String, dynamic>> allPlaces) async {
    // Only allow To places after the selected From
    int fromIndex = allPlaces.indexOf(fromPlace);
    List<Map<String, dynamic>> toPlaces = allPlaces.sublist(fromIndex + 1);
    if (toPlaces.isEmpty) {
      _showCustomSnackBar(
          'No valid drop-off locations after selected pick-up.', 'warning');
      return;
    }
    final toPlace = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => ToSelectionPage(
          toPlaces: toPlaces,
          directionLabel: routeLabels[selectedRoute]![directionIndex],
        ),
      ),
    );
    if (toPlace != null) {
      _showQuantityModal(fromPlace, toPlace);
    }
  }

  void _showQuantityModal(
      Map<String, dynamic> fromPlace, Map<String, dynamic> toPlace) async {
    int? quantity = await showDialog<int>(
      context: context,
      builder: (context) => _QuantitySelectionModal(),
    );
    if (quantity != null && quantity > 0) {
      _showFareTypeModal(fromPlace, toPlace, quantity);
    }
  }

  void _showFareTypeModal(Map<String, dynamic> fromPlace,
      Map<String, dynamic> toPlace, int quantity) async {
    List<String>? fareTypes = await showDialog<List<String>>(
      context: context,
      builder: (context) => _FareTypeSelectionModal(
        quantity: quantity,
        verifiedIDType: verifiedIDType,
      ),
    );
    if (fareTypes != null) {
      _showConfirmationModal(fromPlace, toPlace, quantity, fareTypes);
    }
  }

  void _showConfirmationModal(
      Map<String, dynamic> fromPlace,
      Map<String, dynamic> toPlace,
      int quantity,
      List<String> fareTypes) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmationModal(),
    );
    if (confirmed == true) {
      _showReceiptModal(fromPlace, toPlace, quantity, fareTypes);
    }
  }

  void _showReceiptModal(
      Map<String, dynamic> fromPlace,
      Map<String, dynamic> toPlace,
      int quantity,
      List<String> fareTypes) async {
    await showDialog(
      context: context,
      builder: (context) => _ReceiptModal(
        route: selectedRoute,
        fromPlace: fromPlace,
        toPlace: toPlace,
        quantity: quantity,
        fareTypes: fareTypes,
        directionIndex: directionIndex,
        selectedPlaceCollection: selectedPlaceCollection,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final isDesktop = ResponsiveBreakpoints.of(context).isDesktop;

    // Get screen dimensions for better responsive calculations
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive sizing with better screen size adaptation
    final titleFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final routeFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final dropdownFontSize = isMobile
        ? 12.0
        : isTablet
            ? 14.0
            : 16.0;
    final locationTitleFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;

    // Responsive heights based on screen size
    final expandedHeight = isMobile
        ? (screenHeight * 0.18)
        : isTablet
            ? (screenHeight * 0.20)
            : (screenHeight * 0.22);
    final topPadding = isMobile
        ? (screenHeight * 0.06)
        : isTablet
            ? (screenHeight * 0.07)
            : (screenHeight * 0.08);

    // Responsive padding that scales with screen size
    final horizontalPadding = isMobile
        ? (screenWidth * 0.04)
        : isTablet
            ? (screenWidth * 0.05)
            : (screenWidth * 0.06);
    final verticalPadding = isMobile
        ? (screenHeight * 0.01)
        : isTablet
            ? (screenHeight * 0.012)
            : (screenHeight * 0.015);
    final containerPadding = isMobile
        ? (screenWidth * 0.04)
        : isTablet
            ? (screenWidth * 0.05)
            : (screenWidth * 0.06);
    final cardPadding = isMobile
        ? (screenWidth * 0.04)
        : isTablet
            ? (screenWidth * 0.05)
            : (screenWidth * 0.06);

    // Responsive grid configuration
    final gridCrossAxisCount = isMobile
        ? 2
        : isTablet
            ? 3
            : 4;
    final gridSpacing = isMobile
        ? (screenWidth * 0.02)
        : isTablet
            ? (screenWidth * 0.025)
            : (screenWidth * 0.03);
    final gridAspectRatio = isMobile
        ? 2.5
        : isTablet
            ? 3.0
            : 3.5;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF007A8F),
            expandedHeight: expandedHeight,
            flexibleSpace: FlexibleSpaceBar(
              background: Column(
                children: [
                  // App bar content
                  Padding(
                    padding: EdgeInsets.only(top: topPadding),
                    child: Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back,
                                color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Pre-Ticketing',
                            style: GoogleFonts.outfit(
                              fontSize: titleFontSize,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Route directions display (clickable)
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding),
                    child: GestureDetector(
                      onTap: _toggleDirection,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: containerPadding,
                            vertical: verticalPadding),
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
                            SizedBox(width: isMobile ? 12 : 16),
                            Expanded(
                              child: Text(
                                routeLabels[selectedRoute]![directionIndex],
                                style: GoogleFonts.outfit(
                                  fontSize: routeFontSize,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
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
            padding: EdgeInsets.only(
                top: isMobile ? (screenHeight * 0.02) : (screenHeight * 0.025)),
          ),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: EdgeInsets.only(top: screenHeight * 0.02),
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
                padding: EdgeInsets.symmetric(
                    horizontal: cardPadding, vertical: cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: isMobile ? 10 : 12),
                      child: Text(
                        "Select Pick-up:",
                        style: GoogleFonts.outfit(
                          fontSize: locationTitleFontSize,
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
                              child: Text('Error: ${snapshot.error}'));
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
                            crossAxisCount: gridCrossAxisCount,
                            mainAxisSpacing: gridSpacing,
                            crossAxisSpacing: gridSpacing,
                            childAspectRatio: gridAspectRatio,
                          ),
                          itemCount: myList.length,
                          itemBuilder: (context, index) {
                            final item = myList[index];
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007A8F),
                                elevation: 0,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(
                                    vertical: isMobile
                                        ? (screenHeight * 0.01)
                                        : (screenHeight * 0.012),
                                    horizontal: isMobile
                                        ? (screenWidth * 0.015)
                                        : (screenWidth * 0.02)),
                              ),
                              onPressed: () =>
                                  _showToSelectionPage(item, myList),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item['name'] ?? '',
                                    style: GoogleFonts.outfit(
                                        fontSize: isMobile ? 12 : 14,
                                        color: Colors.white),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (item['km'] != null) ...[
                                    SizedBox(height: isMobile ? 2 : 4),
                                    Text(
                                      '${(item['km'] as num).toInt()} km',
                                      style: TextStyle(
                                          fontSize: isMobile ? 10 : 12,
                                          color: Colors.white70),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    // Debug button to test route service
                    SizedBox(
                        height: isMobile
                            ? (screenHeight * 0.01)
                            : (screenHeight * 0.012)),
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

// Quantity Selection Modal
class _QuantitySelectionModal extends StatefulWidget {
  @override
  State<_QuantitySelectionModal> createState() =>
      _QuantitySelectionModalState();
}

class _QuantitySelectionModalState extends State<_QuantitySelectionModal> {
  int quantity = 1;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select Quantity', style: GoogleFonts.outfit(fontSize: 20)),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.remove),
            onPressed: quantity > 1 ? () => setState(() => quantity--) : null,
          ),
          Text('$quantity', style: GoogleFonts.outfit(fontSize: 20)),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => setState(() => quantity++),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600])),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF0091AD),
          ),
          onPressed: () => Navigator.of(context).pop(quantity),
          child: Text('Confirm',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white)),
        ),
      ],
    );
  }
}

// Fare Type Selection Modal
class _FareTypeSelectionModal extends StatefulWidget {
  final int quantity;
  final String? verifiedIDType;
  const _FareTypeSelectionModal({required this.quantity, this.verifiedIDType});
  @override
  State<_FareTypeSelectionModal> createState() =>
      _FareTypeSelectionModalState();
}

class _FareTypeSelectionModalState extends State<_FareTypeSelectionModal> {
  final List<String> fareTypes = ['Regular', 'Student', 'PWD', 'Senior'];
  late List<String> selectedTypes;

  @override
  void initState() {
    super.initState();
    selectedTypes = List.generate(widget.quantity, (index) => 'Regular');

    // Automatically set the first passenger's fare type based on verified ID
    if (widget.verifiedIDType != null && widget.quantity > 0) {
      String autoFareType = _mapIDTypeToFareType(widget.verifiedIDType!);
      selectedTypes[0] = autoFareType;
    }
  }

  String _mapIDTypeToFareType(String idType) {
    switch (idType.toLowerCase()) {
      case 'student':
        return 'Student';
      case 'senior citizen':
        return 'Senior';
      case 'pwd':
        return 'PWD';
      default:
        return 'Regular';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign Fare Type:', style: GoogleFonts.outfit(fontSize: 20)),
      content: SizedBox(
        height: MediaQuery.of(context).size.height *
            0.5, // or a fixed value like 350
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.verifiedIDType != null) ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Text(
                    'First passenger automatically set to ${_mapIDTypeToFareType(widget.verifiedIDType!)} based on your verified ID',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: Colors.green[700]),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 12),
              ],
              for (int i = 0; i < widget.quantity; i++)
                Row(
                  children: [
                    Text('Passenger ${i + 1}:',
                        style: GoogleFonts.outfit(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    SizedBox(width: 10),
                    DropdownButton<String>(
                      value: selectedTypes[i],
                      items: fareTypes
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type,
                                    style: GoogleFonts.outfit(fontSize: 14)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedTypes[i] = val!;
                        });
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600])),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF0091AD),
          ),
          onPressed: () => Navigator.of(context).pop(selectedTypes),
          child: Text('Confirm',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white)),
        ),
      ],
    );
  }
}

// Confirmation Modal
class _ConfirmationModal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Are you sure with the Pre-Ticketing?',
          style: GoogleFonts.outfit(fontSize: 20)),
      content: Text('Do you wish to proceed?',
          style: GoogleFonts.outfit(fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600])),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF0091AD),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Yes',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white)),
        ),
      ],
    );
  }
}

// Receipt Modal
class _ReceiptModal extends StatelessWidget {
  final String route;
  final Map<String, dynamic> fromPlace;
  final Map<String, dynamic> toPlace;
  final int quantity;
  final List<String> fareTypes;
  final int directionIndex;
  final String selectedPlaceCollection;

  // Map route to display names
  final Map<String, List<String>> routeLabels = {
    'Batangas': [
      'SM Lipa to Batangas City',
      'Batangas City to SM Lipa',
    ],
    'Rosario': [
      'SM Lipa to Rosario',
      'Rosario to SM Lipa',
    ],
    'Mataas na Kahoy': [
      'SM Lipa to Mataas na Kahoy',
      'Mataas na Kahoy to SM Lipa',
    ],
    'Mataas Na Kahoy Palengke': [
      'Lipa Palengke to Mataas na Kahoy',
      'Mataas na Kahoy to Lipa Palengke',
    ],
    'Tiaong': [
      'SM Lipa to Tiaong',
      'Tiaong to SM Lipa',
    ],
    'San Juan': [
      'SM Lipa to San Juan',
      'San Juan to SM Lipa',
    ],
  };

  _ReceiptModal(
      {required this.route,
      required this.fromPlace,
      required this.toPlace,
      required this.quantity,
      required this.fareTypes,
      required this.directionIndex,
      required this.selectedPlaceCollection});

  double computeFare(num startKm, num endKm) {
    final totalKm = endKm - startKm;
    double fare = 15.0; // Minimum fare for up to 4km
    if (totalKm > 4) {
      fare += (totalKm - 4) * 2.20;
    }
    return fare;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final formattedTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final startKm = fromPlace['km'] is num
        ? fromPlace['km']
        : num.tryParse(fromPlace['km'].toString()) ?? 0;
    final endKm = toPlace['km'] is num
        ? toPlace['km']
        : num.tryParse(toPlace['km'].toString()) ?? 0;
    final baseFare = computeFare(startKm, endKm);

    // Prepare discount breakdown and per-passenger fares
    List<String> discountBreakdown = [];
    List<double> passengerFares = [];
    double totalAmount = 0.0;
    for (int i = 0; i < fareTypes.length; i++) {
      final type = fareTypes[i];
      double passengerFare;
      bool isDiscounted = false;
      if (type.toLowerCase() == 'pwd' ||
          type.toLowerCase() == 'senior' ||
          type.toLowerCase() == 'student') {
        passengerFare = baseFare * 0.8;
        isDiscounted = true;
      } else {
        passengerFare = baseFare;
      }
      totalAmount += passengerFare;
      passengerFares.add(passengerFare);
      discountBreakdown.add(
        'Passenger ${i + 1}: $type${isDiscounted ? ' (20% off)' : ' (No discount)'} — ${passengerFare.toStringAsFixed(2)} PHP',
      );
    }

    final qrData = {
      'type': 'preTicket', // Add type field for scanning compatibility
      'ticketType': 'preTicket',
      'route': route,
      'direction':
          routeLabels[route]![directionIndex], // Add direction for validation
      'placeCollection':
          selectedPlaceCollection, // Add place collection for validation
      'date': formattedDate,
      'time': formattedTime,
      'from': fromPlace['name'],
      'to': toPlace['name'],
      'fromKm': (fromPlace['km'] as num).toInt(),
      'toKm': (toPlace['km'] as num).toInt(),
      'fare': baseFare,
      'quantity': quantity,
      'amount': totalAmount,
      'fareTypes': fareTypes,
      'discountBreakdown': discountBreakdown,
      'passengerFares': passengerFares,
    };
    return AlertDialog(
      title: Text('Receipt',
          style: GoogleFonts.outfit(fontSize: 20, color: Colors.black)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Route: $route', style: GoogleFonts.outfit(fontSize: 14)),
            Text('Date: $formattedDate',
                style: GoogleFonts.outfit(fontSize: 14)),
            Text('Time: $formattedTime',
                style: GoogleFonts.outfit(fontSize: 14)),
            Text('From: ${fromPlace['name']}',
                style: GoogleFonts.outfit(fontSize: 14)),
            Text('To: ${toPlace['name']}',
                style: GoogleFonts.outfit(fontSize: 14)),
            Text('From KM: ${(fromPlace['km'] as num).toInt()}',
                style: GoogleFonts.outfit(fontSize: 14)),
            Text('To KM: ${(toPlace['km'] as num).toInt()}',
                style: GoogleFonts.outfit(fontSize: 14)),
            Text('Base Fare (Regular): ${baseFare.toStringAsFixed(2)} PHP',
                style: GoogleFonts.outfit(fontSize: 14)),
            Text('Total Fare: ${totalAmount.toStringAsFixed(2)} PHP',
                style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            Text('Quantity: $quantity',
                style: GoogleFonts.outfit(fontSize: 14)),
            SizedBox(height: 16),
            Text('Discounts:',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w500, fontSize: 14)),
            ...discountBreakdown
                .map((e) => Text(e, style: GoogleFonts.outfit(fontSize: 14))),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => QRCodeFullScreenPage(
                  from: fromPlace['name'] ?? '',
                  to: toPlace['name'] ?? '',
                  km: '${(fromPlace['km'] as num).toInt()} - ${(toPlace['km'] as num).toInt()}',
                  fare: totalAmount.toStringAsFixed(2),
                  quantity: quantity,
                  qrData: jsonEncode(qrData),
                  discountBreakdown: discountBreakdown,
                  showConfirmButton: true,
                  route: route,
                ),
              ),
            );
          },
          child: Text('Show generated QR code',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF0091AD),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600])),
        ),
      ],
    );
  }
}

class ToSelectionPage extends StatelessWidget {
  final List<Map<String, dynamic>> toPlaces;
  final String directionLabel;
  const ToSelectionPage(
      {Key? key, required this.toPlaces, required this.directionLabel})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final isDesktop = ResponsiveBreakpoints.of(context).isDesktop;

    // Get screen dimensions for better responsive calculations
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive sizing with better screen size adaptation
    final titleFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final routeFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final locationTitleFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;

    // Responsive heights based on screen size
    final expandedHeight = isMobile
        ? (screenHeight * 0.18)
        : isTablet
            ? (screenHeight * 0.20)
            : (screenHeight * 0.22);
    final topPadding = isMobile
        ? (screenHeight * 0.06)
        : isTablet
            ? (screenHeight * 0.07)
            : (screenHeight * 0.08);

    // Responsive padding that scales with screen size
    final horizontalPadding = isMobile
        ? (screenWidth * 0.04)
        : isTablet
            ? (screenWidth * 0.05)
            : (screenWidth * 0.06);
    final verticalPadding = isMobile
        ? (screenHeight * 0.01)
        : isTablet
            ? (screenHeight * 0.012)
            : (screenHeight * 0.015);
    final containerPadding = isMobile
        ? (screenWidth * 0.04)
        : isTablet
            ? (screenWidth * 0.05)
            : (screenWidth * 0.06);
    final cardPadding = isMobile
        ? (screenWidth * 0.04)
        : isTablet
            ? (screenWidth * 0.05)
            : (screenWidth * 0.06);

    // Responsive grid configuration
    final gridCrossAxisCount = isMobile
        ? 2
        : isTablet
            ? 3
            : 4;
    final gridSpacing = isMobile
        ? (screenWidth * 0.02)
        : isTablet
            ? (screenWidth * 0.025)
            : (screenWidth * 0.03);
    final gridAspectRatio = isMobile
        ? 2.5
        : isTablet
            ? 3.0
            : 3.5;

    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF007A8F),
            expandedHeight: expandedHeight,
            flexibleSpace: FlexibleSpaceBar(
              background: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: topPadding),
                    child: Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(left: 8.0),
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
                              fontSize: titleFontSize,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // No dropdown here
                      ],
                    ),
                  ),
                  // Non-clickable direction label
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: containerPadding,
                          vertical: verticalPadding),
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
                          SizedBox(width: isMobile ? 12 : 16),
                          Expanded(
                            child: Text(
                              directionLabel,
                              style: GoogleFonts.outfit(
                                fontSize: routeFontSize,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
                padding: EdgeInsets.symmetric(
                    horizontal: cardPadding, vertical: cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: isMobile ? 10 : 12),
                      child: Text(
                        "Select Your Drop-off:",
                        style: GoogleFonts.outfit(
                          fontSize: locationTitleFontSize,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridCrossAxisCount,
                        mainAxisSpacing: gridSpacing,
                        crossAxisSpacing: gridSpacing,
                        childAspectRatio: gridAspectRatio,
                      ),
                      itemCount: toPlaces.length,
                      itemBuilder: (context, index) {
                        final place = toPlaces[index];
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF007A8F),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(
                                vertical: isMobile
                                    ? (screenHeight * 0.01)
                                    : (screenHeight * 0.012),
                                horizontal: isMobile
                                    ? (screenWidth * 0.015)
                                    : (screenWidth * 0.02)),
                          ),
                          onPressed: () => Navigator.of(context).pop(place),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                place['name'] ?? '',
                                style: GoogleFonts.outfit(
                                    fontSize: isMobile ? 12 : 14,
                                    color: Colors.white),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (place['km'] != null) ...[
                                SizedBox(height: isMobile ? 2 : 4),
                                Text(
                                  '${(place['km'] as num).toInt()} km',
                                  style: TextStyle(
                                      fontSize: isMobile ? 10 : 12,
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
        ],
      ),
    );
  }
}

// Update QRCodeFullScreenPage to accept and show discountBreakdown
class QRCodeFullScreenPage extends StatelessWidget {
  final String from;
  final String to;
  final String km;
  final String fare;
  final int quantity;
  final String qrData;
  final List<String>? discountBreakdown;
  final bool showConfirmButton;
  final String route;

  const QRCodeFullScreenPage({
    Key? key,
    required this.from,
    required this.to,
    required this.km,
    required this.fare,
    required this.quantity,
    required this.qrData,
    this.discountBreakdown,
    this.showConfirmButton = true,
    required this.route,
  }) : super(key: key);

  // Custom snackbar widget
  void _showCustomSnackBar(BuildContext context, String message, String type) {
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

  Future<bool> canCreatePreTicket() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final now = DateTime.now().toUtc().add(const Duration(hours: 8)); // PH time
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('preTickets')
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThan: endOfDay)
        .get();
    return snapshot.docs.length < 3;
  }

  Future<void> savePreTicket(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final now = DateTime.now();

    print('🔍 savePreTicket - Starting save process');
    print('🔍 savePreTicket - User ID: ${user.uid}');
    print('🔍 savePreTicket - QR Data: $qrData');

    // Decode QR data to extract all necessary fields
    final qrDataMap = jsonDecode(qrData);

    // Calculate total fare from discount breakdown
    double totalFare = 0.0;
    if (discountBreakdown != null) {
      for (String breakdown in discountBreakdown!) {
        final regex = RegExp(r'— ([\d.]+) PHP');
        final match = regex.firstMatch(breakdown);
        if (match != null) {
          totalFare += double.parse(match.group(1)!);
        }
      }
    }

    // Convert passenger fares to proper format
    List<double> passengerFaresList = [];
    if (qrDataMap['passengerFares'] != null) {
      for (var fare in qrDataMap['passengerFares']) {
        if (fare is num) {
          passengerFaresList.add(fare.toDouble());
        } else if (fare is String) {
          passengerFaresList.add(double.tryParse(fare) ?? 0.0);
        }
      }
    }

    final data = {
      // Basic trip info
      'from': from.toString(),
      'to': to.toString(),
      'km': km.toString(),
      'fromKm': (qrDataMap['fromKm'] is num)
          ? qrDataMap['fromKm']
          : (int.tryParse(qrDataMap['fromKm'].toString()) ?? 0),
      'toKm': (qrDataMap['toKm'] is num)
          ? qrDataMap['toKm']
          : (int.tryParse(qrDataMap['toKm'].toString()) ?? 0),

      // Fare information
      'fare': (qrDataMap['fare'] is num)
          ? qrDataMap['fare']
          : (double.tryParse(qrDataMap['fare'].toString()) ?? 0.0),
      'totalFare': totalFare.toStringAsFixed(2),
      'amount': totalFare.toStringAsFixed(2),
      'discountAmount': '0.00',

      // Passenger details
      'quantity': quantity,
      'fareTypes': List<String>.from(qrDataMap['fareTypes'] ?? []),
      'passengerFares': passengerFaresList,
      'discountBreakdown': List<String>.from(discountBreakdown ?? []),

      // QR and ticket info
      'qrData': qrData,
      'status': 'pending',
      'ticketType': 'preTicket',
      'type': 'preTicket',

      // Route information
      'route': route.toString(),
      'direction': qrDataMap['direction']?.toString() ?? '',
      'placeCollection': qrDataMap['placeCollection']?.toString() ?? '',

      // User and timestamps
      'userId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),

      // Date and time
      'date': qrDataMap['date']?.toString() ?? '',
      'time': qrDataMap['time']?.toString() ?? '',
    };

    print('🔍 savePreTicket - Data to save: $data');
    print('🔍 savePreTicket - Data types:');
    print('  fromKm: ${data['fromKm'].runtimeType}');
    print('  toKm: ${data['toKm'].runtimeType}');
    print('  fare: ${data['fare'].runtimeType}');
    print('  passengerFares: ${data['passengerFares'].runtimeType}');

    try {
      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preTickets')
          .add(data);
      print('✅ savePreTicket - Successfully saved with ID: ${docRef.id}');
    } catch (e) {
      print('❌ savePreTicket - Error saving: $e');
      print('❌ savePreTicket - Error details: ${e.toString()}');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    // Responsive sizing
    final titleFontSize = isMobile
        ? 20.0
        : isTablet
            ? 24.0
            : 28.0;
    final sectionFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final bodyFontSize = isMobile
        ? 14.0
        : isTablet
            ? 16.0
            : 18.0;
    final horizontalPadding = isMobile
        ? 16.0
        : isTablet
            ? 20.0
            : 24.0;
    final verticalPadding = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0091AD),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Pre-Ticket Confirmation',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: titleFontSize,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),

              // Instructions Section
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.blue.shade700, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Next Steps',
                          style: GoogleFonts.outfit(
                            fontSize: sectionFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      '1. Confirm your pre-ticket below\n'
                      '2. Go to Settings → Pre-Ticket QRs\n'
                      '3. Show your QR code to the conductor when boarding\n'
                      '4. The conductor will scan your QR code\n'
                      '5. Enjoy your trip!',
                      style: GoogleFonts.outfit(
                        fontSize: bodyFontSize,
                        color: Colors.blue.shade800,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Trip Details Section
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long,
                            color: Color(0xFF0091AD), size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Trip Details',
                          style: GoogleFonts.outfit(
                            fontSize: sectionFontSize,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0091AD),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildDetailRow('Route', route, bodyFontSize),
                    _buildDetailRow('From', from, bodyFontSize),
                    _buildDetailRow('To', to, bodyFontSize),
                    _buildDetailRow('Distance', '$km km', bodyFontSize),
                    _buildDetailRow('Total Fare', '₱$fare', bodyFontSize),
                    _buildDetailRow('Passengers', '$quantity', bodyFontSize),
                  ],
                ),
              ),

              if (discountBreakdown != null &&
                  discountBreakdown!.isNotEmpty) ...[
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(color: Colors.green.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.discount,
                              color: Colors.green.shade700, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Fare Breakdown',
                            style: GoogleFonts.outfit(
                              fontSize: sectionFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      ...discountBreakdown!.map((breakdown) => Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              breakdown,
                              style: GoogleFonts.outfit(
                                fontSize: bodyFontSize - 2,
                                color: Colors.green.shade800,
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 24),

              // Status Information
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pending_actions,
                        color: Colors.orange.shade700, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your pre-ticket will be available in Settings → Pre-Ticket QRs after confirmation.',
                        style: GoogleFonts.outfit(
                          fontSize: bodyFontSize,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: verticalPadding),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: Size(
                        double.infinity,
                        isMobile
                            ? 45
                            : isTablet
                                ? 50
                                : 55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: isMobile
                          ? 16
                          : isTablet
                              ? 18
                              : 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (showConfirmButton) ...[
                SizedBox(width: 16),
                Expanded(
                  child: FutureBuilder<bool>(
                    future: canCreatePreTicket(),
                    builder: (context, snapshot) {
                      final canCreate = snapshot.data ?? false;
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightGreen[400],
                          minimumSize: Size(
                              double.infinity,
                              isMobile
                                  ? 45
                                  : isTablet
                                      ? 50
                                      : 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: canCreate
                            ? () async {
                                await savePreTicket(context);
                                _showCustomSnackBar(
                                    context,
                                    'Pre-ticket saved successfully!',
                                    'success');

                                // Navigate to home page after a short delay
                                await Future.delayed(
                                    Duration(milliseconds: 500));
                                if (context.mounted) {
                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                    '/home',
                                    (route) => false,
                                  );
                                }
                              }
                            : null,
                        child: Text(
                          'Confirm',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: isMobile
                                ? 16
                                : isTablet
                                    ? 18
                                    : 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, double fontSize) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.outfit(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: fontSize,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
