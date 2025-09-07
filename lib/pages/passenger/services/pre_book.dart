import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Added for Timer
import 'package:b_go/pages/passenger/profile/Settings/reservation_confirm.dart';
import 'package:geolocator/geolocator.dart'; // Added for location tracking
import 'package:b_go/pages/passenger/services/passenger_location_service.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Added for QR code generation
import 'dart:convert'; // Added for JSON encoding
import 'package:responsive_framework/responsive_framework.dart';
import 'package:b_go/pages/passenger/services/geofencing_service.dart';

class PreBook extends StatefulWidget {
  const PreBook({super.key});

  @override
  State<PreBook> createState() => _PreBookState();
}

class _PreBookState extends State<PreBook> {
  final List<String> routeChoices = [
    'Batangas',
    'Rosario',
    'Mataas na Kahoy',
    'Mataas Na Kahoy Palengke',
    'Tiaong',
    'San Juan',
  ];

  // Map display names to Firestore document names
  final Map<String, String> _routeFirestoreNames = {
    'Batangas': 'Batangas',
    'Rosario': 'Rosario',
    'Mataas na Kahoy': 'Mataas na Kahoy',
    'Mataas Na Kahoy Palengke': 'Mataas Na Kahoy Palengke',
    'Tiaong': 'Tiaong',
    'San Juan': 'San Juan',
  };

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

  String selectedRoute = 'Batangas';
  int directionIndex = 0; // 0: Place, 1: Place 2
  late Future<List<Map<String, dynamic>>> placesFuture;
  String? verifiedIDType;
  Position? _currentLocation; // Added for passenger location tracking
  final PassengerLocationService _locationService = PassengerLocationService();
  String selectedPlaceCollection = 'Place'; // Added for direction selection

  @override
  void initState() {
    super.initState();
    placesFuture = RouteService.fetchPlaces(
      _routeFirestoreNames[selectedRoute] ?? selectedRoute,
      placeCollection: 'Place'
    );
    _fetchVerifiedIDType();
    // Delay location request slightly to ensure UI is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation(); // Get passenger's current location
    });
    // Start geofencing service for passenger monitoring
    GeofencingService().startMonitoring();
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

  // Added method to get passenger's current location
  Future<void> _getCurrentLocation() async {
    print('🚀 PreBook: Starting location capture...');
    try {
      print('🚀 PreBook: Calling PassengerLocationService.getCurrentLocation()...');
      
      // Try to get location with timeout
      final position = await _locationService.getCurrentLocation(context: context);
      
      if (position != null) {
        setState(() {
          _currentLocation = position;
        });
        print('✅ PreBook: Passenger location captured successfully: ${position.latitude}, ${position.longitude}');
        
        // Show success message to user
        if (mounted) {
          _showCustomSnackBar('✅ Location captured: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}', 'success');
        }
      } else {
        print('❌ PreBook: Failed to get passenger location - position is null');
        // Show error to user
        if (mounted) {
          _showCustomSnackBar('❌ Failed to get your location. Please check your GPS settings and try again.', 'error');
        }
      }
    } catch (e) {
      print('❌ PreBook: Error getting passenger location: $e');
      if (mounted) {
        _showCustomSnackBar('❌ Error getting location: $e', 'error');
      }
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
        placesFuture = RouteService.fetchPlaces(
          firestoreRouteName,
          placeCollection: selectedPlaceCollection
        );
      });
    }
  }

  void _toggleDirection() {
    setState(() {
      directionIndex = directionIndex == 0 ? 1 : 0;
      selectedPlaceCollection = directionIndex == 0 ? 'Place' : 'Place 2';
      // Use the Firestore route name instead of the display name
      String firestoreRouteName = _routeFirestoreNames[selectedRoute] ?? selectedRoute;
      placesFuture = RouteService.fetchPlaces(
        firestoreRouteName,
        placeCollection: selectedPlaceCollection
      );
    });
  }

  void _showToSelectionPage(Map<String, dynamic> fromPlace, List<Map<String, dynamic>> allPlaces) async {
    // Check if location is captured before proceeding
    if (_currentLocation == null) {
      _showCustomSnackBar('⚠️ Location access required! Please enable location and try again.', 'warning');
      return;
    }

    // Double-check location is valid
    if (_currentLocation!.latitude == 0.0 && _currentLocation!.longitude == 0.0) {
      _showCustomSnackBar('⚠️ Invalid location detected! Please try capturing location again.', 'warning');
      return;
    }

    // Additional validation: check if coordinates are reasonable (not in the middle of the ocean)
    if (_currentLocation!.latitude < -90 || _currentLocation!.latitude > 90 || 
        _currentLocation!.longitude < -180 || _currentLocation!.longitude > 180) {
      _showCustomSnackBar('⚠️ Invalid coordinates detected! Please try capturing location again.', 'warning');
      return;
    }

    print('✅ PreBook: Location verified before proceeding: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}');

    int fromIndex = allPlaces.indexOf(fromPlace);
    List<Map<String, dynamic>> toPlaces = allPlaces.sublist(fromIndex + 1);
    if (toPlaces.isEmpty) {
      _showCustomSnackBar('No valid drop-off locations after selected pick-up.', 'warning');
      return;
    }
    final toPlace = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => _ToSelectionPage(
          toPlaces: toPlaces,
          directionLabel: routeLabels[selectedRoute]![directionIndex],
        ),
      ),
    );
    if (toPlace != null) {
      _showQuantityModal(fromPlace, toPlace);
    }
  }

  void _showQuantityModal(Map<String, dynamic> fromPlace, Map<String, dynamic> toPlace) async {
    int? quantity = await showDialog<int>(
      context: context,
      builder: (context) => _QuantitySelectionModal(),
    );
    if (quantity != null && quantity > 0) {
      _showFareTypeModal(fromPlace, toPlace, quantity);
    }
  }

  void _showFareTypeModal(Map<String, dynamic> fromPlace, Map<String, dynamic> toPlace, int quantity) async {
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

  void _showConfirmationModal(Map<String, dynamic> fromPlace, Map<String, dynamic> toPlace, int quantity, List<String> fareTypes) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmationModal(),
    );
    if (confirmed == true) {
      _showReceiptModal(fromPlace, toPlace, quantity, fareTypes);
    }
  }

  void _showReceiptModal(Map<String, dynamic> fromPlace, Map<String, dynamic> toPlace, int quantity, List<String> fareTypes) async {
    await showDialog(
      context: context,
      builder: (context) => _ReceiptModal(
        route: selectedRoute,
        directionLabel: routeLabels[selectedRoute]![directionIndex],
        fromPlace: fromPlace,
        toPlace: toPlace,
        quantity: quantity,
        fareTypes: fareTypes,
        currentLocation: _currentLocation, // Pass the location directly
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
    final titleFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final routeFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final dropdownFontSize = isMobile ? 12.0 : isTablet ? 14.0 : 16.0;
    final locationTitleFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final locationStatusFontSize = isMobile ? 11.0 : isTablet ? 13.0 : 15.0;
    final locationCoordFontSize = isMobile ? 9.0 : isTablet ? 11.0 : 13.0;
    final buttonFontSize = isMobile ? 14.0 : isTablet ? 16.0 : 18.0;
    
    // Responsive heights based on screen size
    final expandedHeight = isMobile ? (screenHeight * 0.18) : isTablet ? (screenHeight * 0.20) : (screenHeight * 0.22);
    final topPadding = isMobile ? (screenHeight * 0.06) : isTablet ? (screenHeight * 0.07) : (screenHeight * 0.08);
    
    // Responsive padding that scales with screen size
    final horizontalPadding = isMobile ? (screenWidth * 0.04) : isTablet ? (screenWidth * 0.05) : (screenWidth * 0.06);
    final verticalPadding = isMobile ? (screenHeight * 0.01) : isTablet ? (screenHeight * 0.012) : (screenHeight * 0.015);
    final containerPadding = isMobile ? (screenWidth * 0.04) : isTablet ? (screenWidth * 0.05) : (screenWidth * 0.06);
    final cardPadding = isMobile ? (screenWidth * 0.04) : isTablet ? (screenWidth * 0.05) : (screenWidth * 0.06);
    final locationPadding = isMobile ? (screenWidth * 0.03) : isTablet ? (screenWidth * 0.035) : (screenWidth * 0.04);
    
    // Responsive button sizing
    final buttonHeight = isMobile ? (screenHeight * 0.01) : isTablet ? (screenHeight * 0.012) : (screenHeight * 0.015);
    final iconSize = isMobile ? 18.0 : isTablet ? 22.0 : 26.0;
    final smallIconSize = isMobile ? 14.0 : isTablet ? 18.0 : 22.0;
    
    // Responsive grid configuration
    final gridCrossAxisCount = isMobile ? 2 : isTablet ? 3 : 4;
    final gridSpacing = isMobile ? (screenWidth * 0.02) : isTablet ? (screenWidth * 0.025) : (screenWidth * 0.03);
    final gridAspectRatio = isMobile ? 2.5 : isTablet ? 3.0 : 3.5;
    
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
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Pre-Booking',
                            style: GoogleFonts.outfit(fontSize: titleFontSize, color: Colors.white),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(right: 10.0),
                          child: DropdownButton<String>(
                            value: selectedRoute,
                            dropdownColor: const Color(0xFF007A8F),
                            style: GoogleFonts.outfit(fontSize: dropdownFontSize, color: Colors.white),
                            iconEnabledColor: Colors.white,
                            underline: Container(),
                            items: routeChoices
                                .map((route) => DropdownMenuItem(
                                      value: route,
                                      child: Text(routeLabels[route]![0], style: TextStyle(color: Colors.white)),
                                    ))
                                .toList(),
                            onChanged: _onRouteChanged,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                    child: GestureDetector(
                      onTap: _toggleDirection,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: containerPadding, vertical: verticalPadding),
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
                                style: GoogleFonts.outfit(fontSize: routeFontSize, color: Colors.white, fontWeight: FontWeight.w600),
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
            padding: EdgeInsets.only(top: isMobile ? (screenHeight * 0.02) : (screenHeight * 0.025)),
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
                padding: EdgeInsets.symmetric(horizontal: cardPadding, vertical: cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: isMobile ? 10 : 12),
                      child: Text(
                        "Select Location:",
                        style: GoogleFonts.outfit(fontSize: locationTitleFontSize, color: Colors.black87),
                      ),
                    ),
                    // Location status indicator with responsive sizing
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 12, 
                        vertical: isMobile ? (screenHeight * 0.01) : (screenHeight * 0.012)
                      ),
                      child: Container(
                        padding: EdgeInsets.all(locationPadding),
                        decoration: BoxDecoration(
                          color: _currentLocation != null ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _currentLocation != null ? Colors.green : Colors.orange,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _currentLocation != null ? Icons.location_on : Icons.location_off,
                                  color: _currentLocation != null ? Colors.green : Colors.orange,
                                  size: iconSize,
                                ),
                                SizedBox(width: isMobile ? 8 : 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _currentLocation != null 
                                          ? 'Location captured successfully!'
                                          : 'Location access needed for conductor to find you',
                                        style: GoogleFonts.outfit(
                                          fontSize: locationStatusFontSize,
                                          fontWeight: FontWeight.w600,
                                          color: _currentLocation != null ? Colors.green.shade700 : Colors.orange.shade700,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (_currentLocation != null) ...[
                                        SizedBox(height: isMobile ? 2 : 4),
                                        Text(
                                          'Lat: ${_currentLocation!.latitude.toStringAsFixed(6)}',
                                          style: GoogleFonts.outfit(
                                            fontSize: locationCoordFontSize,
                                            color: Colors.green.shade600,
                                          ),
                                        ),
                                        Text(
                                          'Lng: ${_currentLocation!.longitude.toStringAsFixed(6)}',
                                          style: GoogleFonts.outfit(
                                            fontSize: locationCoordFontSize,
                                            color: Colors.green.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (_currentLocation == null)
                                  IconButton(
                                    icon: Icon(Icons.refresh, size: smallIconSize),
                                    onPressed: () {
                                      _getCurrentLocation();
                                      _showCustomSnackBar('Requesting location access...', 'info');
                                    },
                                    color: Colors.orange,
                                  ),
                              ],
                            ),
                            if (_currentLocation == null) ...[
                              SizedBox(height: isMobile ? (screenHeight * 0.01) : (screenHeight * 0.012)),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _getCurrentLocation();
                                    _showCustomSnackBar('Requesting location access...', 'info');
                                  },
                                  icon: Icon(Icons.location_on, size: smallIconSize),
                                  label: Text('Enable Location Access', style: TextStyle(fontSize: buttonFontSize)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: buttonHeight),
                                  ),
                                ),
                              ),
                            ],
                            // Debug button to show current location
                            if (_currentLocation != null) ...[
                              SizedBox(height: isMobile ? (screenHeight * 0.01) : (screenHeight * 0.012)),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _showCustomSnackBar('Location: ${_currentLocation!.latitude.toStringAsFixed(6)}, ${_currentLocation!.longitude.toStringAsFixed(6)}', 'info');
                                  },
                                  icon: Icon(Icons.info, size: smallIconSize),
                                  label: Text('Show Location Details', style: TextStyle(fontSize: buttonFontSize)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: buttonHeight),
                                  ),
                                ),
                              ),
                            ],
                            // Debug button to test location capture
                            SizedBox(height: isMobile ? (screenHeight * 0.01) : (screenHeight * 0.012)),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await _getCurrentLocation();
                                  if (_currentLocation != null) {
                                    _showCustomSnackBar('Location captured: ${_currentLocation!.latitude.toStringAsFixed(6)}, ${_currentLocation!.longitude.toStringAsFixed(6)}', 'success');
                                  }
                                },
                                icon: Icon(Icons.refresh, size: smallIconSize),
                                label: Text('Test Location Capture', style: TextStyle(fontSize: buttonFontSize)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: buttonHeight),
                                ),
                              ),
                            ),
                          ],
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
                                backgroundColor: const Color(0xFF0091AD),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: EdgeInsets.symmetric(
                                  vertical: isMobile ? (screenHeight * 0.01) : (screenHeight * 0.012), 
                                  horizontal: isMobile ? (screenWidth * 0.015) : (screenWidth * 0.02)
                                ),
                              ),
                              onPressed: () => _showToSelectionPage(item, myList),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item['name'] ?? '',
                                    style: GoogleFonts.outfit(
                                      fontSize: isMobile ? 12 : 14, 
                                      color: Colors.white
                                    ),
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
                                        color: Colors.white70
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
            ),
          ),
        ],
      ),
    );
  }
}

class _ToSelectionPage extends StatelessWidget {
  final List<Map<String, dynamic>> toPlaces;
  final String directionLabel;
  const _ToSelectionPage({Key? key, required this.toPlaces, required this.directionLabel}) : super(key: key);

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
    final titleFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final routeFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final locationTitleFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    
    // Responsive heights based on screen size
    final expandedHeight = isMobile ? (screenHeight * 0.18) : isTablet ? (screenHeight * 0.20) : (screenHeight * 0.22);
    final topPadding = isMobile ? (screenHeight * 0.06) : isTablet ? (screenHeight * 0.07) : (screenHeight * 0.08);
    
    // Responsive padding that scales with screen size
    final horizontalPadding = isMobile ? (screenWidth * 0.04) : isTablet ? (screenWidth * 0.05) : (screenWidth * 0.06);
    final verticalPadding = isMobile ? (screenHeight * 0.01) : isTablet ? (screenHeight * 0.012) : (screenHeight * 0.015);
    final containerPadding = isMobile ? (screenWidth * 0.04) : isTablet ? (screenWidth * 0.05) : (screenWidth * 0.06);
    final cardPadding = isMobile ? (screenWidth * 0.04) : isTablet ? (screenWidth * 0.05) : (screenWidth * 0.06);
    
    // Responsive grid configuration
    final gridCrossAxisCount = isMobile ? 2 : isTablet ? 3 : 4;
    final gridSpacing = isMobile ? (screenWidth * 0.02) : isTablet ? (screenWidth * 0.025) : (screenWidth * 0.03);
    final gridAspectRatio = isMobile ? 2.5 : isTablet ? 3.0 : 3.5;
    
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
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: containerPadding, vertical: verticalPadding),
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
                  bottom: size.height * 0.08
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
                padding: EdgeInsets.symmetric(horizontal: cardPadding, vertical: cardPadding),
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
                            backgroundColor: const Color(0xFF0091AD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: isMobile ? (screenHeight * 0.01) : (screenHeight * 0.012), 
                              horizontal: isMobile ? (screenWidth * 0.015) : (screenWidth * 0.02)
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(place),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                place['name'] ?? '',
                                style: GoogleFonts.outfit(
                                  fontSize: isMobile ? 12 : 14, 
                                  color: Colors.white
                                ),
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
                                    color: Colors.white70
                                  ),
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

// Quantity, FareType, Confirmation, and Receipt modals are similar to PreTicket, but receipt saves to preBookings
class _QuantitySelectionModal extends StatefulWidget {
  @override
  State<_QuantitySelectionModal> createState() => _QuantitySelectionModalState();
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
          child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.red, fontSize: 14)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(quantity),
          child: Text('Confirm', style: GoogleFonts.outfit(color: Colors.black, fontSize: 14)),
        ),
      ],
    );
  }
}

class _FareTypeSelectionModal extends StatefulWidget {
  final int quantity;
  final String? verifiedIDType;
  const _FareTypeSelectionModal({required this.quantity, this.verifiedIDType});
  @override
  State<_FareTypeSelectionModal> createState() => _FareTypeSelectionModalState();
}

class _FareTypeSelectionModalState extends State<_FareTypeSelectionModal> {
  final List<String> fareTypes = ['Regular', 'Student', 'PWD', 'Senior'];
  late List<String> selectedTypes;

  @override
  void initState() {
    super.initState();
    selectedTypes = List.generate(widget.quantity, (index) => 'Regular');
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
        height: MediaQuery.of(context).size.height * 0.5,
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
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.green[700]),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 12),
              ],
              for (int i = 0; i < widget.quantity; i++)
                Row(
                  children: [
                    Text('Passenger ${i + 1}:', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500)),
                    SizedBox(width: 10),
                    DropdownButton<String>(
                      value: selectedTypes[i],
                      items: fareTypes
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type, style: GoogleFonts.outfit(fontSize: 14)),
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
          child: Text('Cancel', style: GoogleFonts.outfit(fontSize: 14)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(selectedTypes),
          child: Text('Confirm', style: GoogleFonts.outfit(fontSize: 14)),
        ),
      ],
    );
  }
}

class _ConfirmationModal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Are you sure with the Pre-Booking?', style: GoogleFonts.outfit(fontSize: 20)),
      content: Text('Do you wish to proceed?', style: GoogleFonts.outfit(fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: GoogleFonts.outfit(fontSize: 14)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Yes', style: GoogleFonts.outfit(fontSize: 14)),
        ),
      ],
    );
  }
}

class _ReceiptModal extends StatelessWidget {
  final String route;
  final String directionLabel;
  final Map<String, dynamic> fromPlace;
  final Map<String, dynamic> toPlace;
  final int quantity;
  final List<String> fareTypes;
  final Position? currentLocation; // Added for location passing
  _ReceiptModal({required this.route, required this.directionLabel, required this.fromPlace, required this.toPlace, required this.quantity, required this.fareTypes, this.currentLocation});

  // Calculate full trip fare for pre-booking (from start to end of route)
  double computeFullTripFare(String route) {
    // Get the maximum distance for each route (end point)
    Map<String, double> routeEndDistances = {
      'Batangas': 28.0, // SM Lipa to Batangas City (0-14km)
      'Rosario': 14.0,  // SM Lipa to Rosario (0-14km)
      'Mataas na Kahoy': 8.0, // SM Lipa to Mataas na Kahoy (0-14km)
      'Mataas na Kahoy Lipa Palengke': 8.0, // SM Lipa to Lipa Palengke (0-14km)
      'Tiaong': 30.0,   // SM Lipa to Tiaong (0-14km)
      'San Juan': 37.0, // SM Lipa to San Juan (0-14km)
    };
    
    final totalKm = routeEndDistances[route] ?? 14.0;
    double fare = 15.0; // Minimum fare for up to 4km
    if (totalKm > 4) {
      fare += (totalKm - 4) * 2.20;
    }
    return fare;
  }

  Future<void> savePreBooking(BuildContext context, double baseFare, double totalAmount, List<String> discountBreakdown, List<double> passengerFares) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    
    // Use the passed location instead of trying to access parent state
    Position? passengerLocation = currentLocation;
    
    // If location is not available, try to get it again using the location service directly
    if (passengerLocation == null) {
      print('⚠️ PreBook: No location found in modal, trying to get location again...');
      try {
        // Create a new instance of the location service
        final locationService = PassengerLocationService();
        passengerLocation = await locationService.getCurrentLocation(context: context);
        if (passengerLocation != null) {
          print('✅ PreBook: Successfully captured location on retry: ${passengerLocation.latitude}, ${passengerLocation.longitude}');
        } else {
          print('❌ PreBook: Failed to get location on retry');
        }
      } catch (e) {
        print('❌ PreBook: Error getting location on retry: $e');
      }
    }
    
    print('💾 PreBook: Saving booking with passenger location: ${passengerLocation?.latitude}, ${passengerLocation?.longitude}');
    
    // Create QR data for the booking
    final qrData = {
      'type': 'preBooking',
      'route': route,
      'direction': directionLabel,
      'from': fromPlace['name'],
      'to': toPlace['name'],
      'fromKm': (fromPlace['km'] as num).toInt(),
      'toKm': (toPlace['km'] as num).toInt(),
      'fromLatitude': fromPlace['latitude'] ?? 0.0,
      'fromLongitude': fromPlace['longitude'] ?? 0.0,
      'toLatitude': toPlace['latitude'] ?? 0.0,
      'toLongitude': toPlace['longitude'] ?? 0.0,
      'passengerLatitude': passengerLocation?.latitude ?? 0.0,
      'passengerLongitude': passengerLocation?.longitude ?? 0.0,
      'fare': baseFare,
      'quantity': quantity,
      'amount': totalAmount,
      'fareTypes': fareTypes,
      'discountBreakdown': discountBreakdown,
      'passengerFares': passengerFares,
      'userId': user.uid,
      'timestamp': now.millisecondsSinceEpoch,
      'boardingStatus': 'pending', // Add boarding status
    };
    
    final data = {
      'route': route,
      'direction': directionLabel,
      'from': fromPlace['name'],
      'to': toPlace['name'],
      'fromKm': (fromPlace['km'] as num).toInt(),
      'toKm': (toPlace['km'] as num).toInt(),
      'fromLatitude': fromPlace['latitude'] ?? 0.0,
      'fromLongitude': fromPlace['longitude'] ?? 0.0,
      'toLatitude': toPlace['latitude'] ?? 0.0,
      'toLongitude': toPlace['longitude'] ?? 0.0,
      // Add passenger's current location
      'passengerLatitude': passengerLocation?.latitude ?? 0.0,
      'passengerLongitude': passengerLocation?.longitude ?? 0.0,
      'passengerLocationTimestamp': passengerLocation != null ? FieldValue.serverTimestamp() : null,
      'fare': baseFare,
      'quantity': quantity,
      'amount': totalAmount,
      'fareTypes': fareTypes,
      'discountBreakdown': discountBreakdown,
      'passengerFares': passengerFares,
      'status': 'pending_payment', // Status for testing
      'boardingStatus': 'pending', // Add boarding status
      'paymentDeadline': now.add(Duration(minutes: 10)), // 10 minutes from now
      'createdAt': now,
      'userId': user.uid,
      // Add QR data for conductor scanning
      'qrData': jsonEncode(qrData),
    };
    
    print('💾 PreBook: Complete booking data: $data');
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .add(data);
      print('✅ PreBook: Booking saved successfully to Firebase');
    } catch (e) {
      print('❌ PreBook: Error saving booking to Firebase: $e');
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final formattedTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final startKm = fromPlace['km'] is num ? fromPlace['km'] : num.tryParse(fromPlace['km'].toString()) ?? 0;
    final endKm = toPlace['km'] is num ? toPlace['km'] : num.tryParse(toPlace['km'].toString()) ?? 0;
    final baseFare = computeFullTripFare(route);
    List<String> discountBreakdown = [];
    List<double> passengerFares = [];
    double totalAmount = 0.0;
    for (int i = 0; i < fareTypes.length; i++) {
      final type = fareTypes[i];
      double passengerFare;
      bool isDiscounted = false;
      if (type.toLowerCase() == 'pwd' || type.toLowerCase() == 'senior' || type.toLowerCase() == 'student') {
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
    
    // Create QR data for display
    final qrData = {
      'type': 'preBooking',
      'route': route,
      'direction': directionLabel,
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
      'timestamp': now.millisecondsSinceEpoch,
    };
    
    return AlertDialog(
      title: Text('Receipt', style: GoogleFonts.outfit(fontSize: 20, color: Colors.black)),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Route: $route', style: GoogleFonts.outfit(fontSize: 14)),
            Text('Direction: $directionLabel', style: GoogleFonts.outfit(fontSize: 14)),
            Text('Date: $formattedDate', style: GoogleFonts.outfit(fontSize: 14)),
            Text('Time: $formattedTime', style: GoogleFonts.outfit(fontSize: 14)),
            Text('From: ${fromPlace['name']}', style: GoogleFonts.outfit(fontSize: 14)),
            Text('To: ${toPlace['name']}', style: GoogleFonts.outfit(fontSize: 14)),
            Text('From KM: ${(fromPlace['km'] as num).toInt()}', style: GoogleFonts.outfit(fontSize: 14)),
            Text('To KM: ${(toPlace['km'] as num).toInt()}', style: GoogleFonts.outfit(fontSize: 14)),
            Text('Selected Distance: ${(endKm - startKm).toStringAsFixed(1)} km', style: GoogleFonts.outfit(fontSize: 14)),
            Text('Full Trip Fare (Regular): ${baseFare.toStringAsFixed(2)} PHP', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
            Text('Quantity: $quantity', style: GoogleFonts.outfit(fontSize: 14)),
            Text('Total Amount: ${totalAmount.toStringAsFixed(2)} PHP', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(height: 16),
            Text('Discounts:', style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 14)),
            ...discountBreakdown.map((e) => Text(e, style: GoogleFonts.outfit(fontSize: 14))),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Text(
                'Note: You pay the full trip fare for guaranteed seats',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.blue[700]),
              ),
            ),
          ],
        ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            // Final check: ensure location is captured before saving
            if (currentLocation == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ Location not captured! Please go back and enable location access.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
              return;
            }
            
            await savePreBooking(context, baseFare, totalAmount, discountBreakdown, passengerFares);
            Navigator.of(context).pop();
            // Navigate to summary page
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PreBookSummaryPage(
                  route: route,
                  directionLabel: directionLabel,
                  fromPlace: fromPlace,
                  toPlace: toPlace,
                  quantity: quantity,
                  fareTypes: fareTypes,
                  baseFare: baseFare,
                  totalAmount: totalAmount,
                  discountBreakdown: discountBreakdown,
                  passengerFares: passengerFares,
                ),
              ),
            );
          },
          child: Text('Confirm & Save', style: GoogleFonts.outfit(fontSize: 14, color: Colors.white)),
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
          child: Text('Close', style: GoogleFonts.outfit(fontSize: 14, color: Colors.black)),
        ),
      ],
    );
  }
}

// New Summary Page for Pre-Booking
class PreBookSummaryPage extends StatefulWidget {
  final String route;
  final String directionLabel;
  final Map<String, dynamic> fromPlace;
  final Map<String, dynamic> toPlace;
  final int quantity;
  final List<String> fareTypes;
  final double baseFare;
  final double totalAmount;
  final List<String> discountBreakdown;
  final List<double> passengerFares;

  const PreBookSummaryPage({
    Key? key,
    required this.route,
    required this.directionLabel,
    required this.fromPlace,
    required this.toPlace,
    required this.quantity,
    required this.fareTypes,
    required this.baseFare,
    required this.totalAmount,
    required this.discountBreakdown,
    required this.passengerFares,
  }) : super(key: key);

  @override
  State<PreBookSummaryPage> createState() => _PreBookSummaryPageState();
}

class _PreBookSummaryPageState extends State<PreBookSummaryPage> {
  late Timer _timer;
  late DateTime _deadline;
  int _remainingSeconds = 600; // 10 minutes in seconds

  @override
  void initState() {
    super.initState();
    _deadline = DateTime.now().add(Duration(minutes: 10));
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds = _deadline.difference(DateTime.now()).inSeconds;
        if (_remainingSeconds <= 0) {
          _timer.cancel();
          _showTimeoutDialog();
        }
      });
    });
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Payment Timeout', style: GoogleFonts.outfit(fontSize: 20)),
        content: Text(
          'Your payment time has expired. The pre-booking has been cancelled.',
          style: GoogleFonts.outfit(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to pre-booking page
            },
            child: Text('OK', style: GoogleFonts.outfit(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> cancelPreBooking(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Delete the pre-booking from Firestore
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('preBookings')
        .where('route', isEqualTo: widget.route)
        .where('from', isEqualTo: widget.fromPlace['name'])
        .where('to', isEqualTo: widget.toPlace['name'])
        .where('quantity', isEqualTo: widget.quantity)
        .get();
    
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pre-booking cancelled!'), backgroundColor: Colors.orange),
    );
    Navigator.of(context).pop();
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final now = DateTime.now();
    final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final formattedTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final startKm = widget.fromPlace['km'] is num ? widget.fromPlace['km'] : num.tryParse(widget.fromPlace['km'].toString()) ?? 0;
    final endKm = widget.toPlace['km'] is num ? widget.toPlace['km'] : num.tryParse(widget.toPlace['km'].toString()) ?? 0;
    final distance = endKm - startKm;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0091AD),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Payment Page',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: size.height * 0.04),
            // Timer Section
            Container(
              padding: EdgeInsets.all(20),
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _remainingSeconds <= 60 ? Colors.red[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _remainingSeconds <= 60 ? Colors.red[200]! : Colors.orange[200]!,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.timer,
                    color: _remainingSeconds <= 60 ? Colors.red : Colors.orange,
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Payment Deadline',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _remainingSeconds <= 60 ? Colors.red[700] : Colors.orange[700],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _remainingSeconds <= 60 ? Colors.red[700] : Colors.orange[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _remainingSeconds <= 60 
                        ? 'HURRY! Payment expires soon!'
                        : 'Complete payment within the time limit',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: _remainingSeconds <= 60 ? Colors.red[700] : Colors.orange[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            // Payment Instructions
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payment, color: Colors.blue[700], size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Payment Instructions',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    '1. Click the "Pay Now" button below',
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.blue[700]),
                  ),
                  Text(
                    '2. You will be redirected to our admin website',
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.blue[700]),
                  ),
                  Text(
                    '3. Complete payment using PayMongo',
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.blue[700]),
                  ),
                  Text(
                    '4. Return to this app after payment',
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.blue[700]),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.green[700], size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Status: Pending Payment (Testing Mode)',
                            style: GoogleFonts.outfit(fontSize: 12, color: Colors.green[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            // Booking Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Booking Details:',
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600, fontSize: 18)),
                      SizedBox(height: 16),
                      _buildDetailRow('Route:', widget.route),
                      _buildDetailRow('Direction:', widget.directionLabel),
                      _buildDetailRow('Date:', formattedDate),
                      _buildDetailRow('Time:', formattedTime),
                      _buildDetailRow('From:', widget.fromPlace['name']),
                      _buildDetailRow('To:', widget.toPlace['name']),
                      _buildDetailRow('From KM:', '${(widget.fromPlace['km'] as num).toInt()}'),
                      _buildDetailRow('To KM:', '${(widget.toPlace['km'] as num).toInt()}'),
                      _buildDetailRow('Selected Distance:', '${distance.toStringAsFixed(1)} km'),
                      _buildDetailRow('Full Trip Fare (Regular):', '${widget.baseFare.toStringAsFixed(2)} PHP'),
                      _buildDetailRow('Quantity:', '${widget.quantity}'),
                      _buildDetailRow('Total Amount:', '${widget.totalAmount.toStringAsFixed(2)} PHP'),
                      SizedBox(height: 16),
                      Text('Passenger Details:',
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      SizedBox(height: 8),
                      ...widget.discountBreakdown.map((e) => Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(e, style: GoogleFonts.outfit(fontSize: 14)),
                      )),
                    ],
                  ),
                ),
              ),
            ),
            // Action Buttons
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                children: [
                  // Pay Now Button
                  Container(
                    width: size.width * 0.8,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightGreen[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      onPressed: () {
                        // TODO: Replace with actual admin website URL
                        _launchAdminWebsite();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Pay Now',
                              style: GoogleFonts.outfit(
                                  color: Colors.white, fontSize: 17)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  // Cancel Button
                  Container(
                    width: size.width * 0.8,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      onPressed: () => cancelPreBooking(context),
                      child: Text('Cancel Pre-Booking',
                          style: GoogleFonts.outfit(
                              color: Colors.white, fontSize: 17)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchAdminWebsite() {
    // TODO: Replace with actual admin website URL
    final adminUrl = 'https://your-admin-website.com/payment';
    
    // For now, show a dialog with the URL
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Admin Website', style: GoogleFonts.outfit(fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You will be redirected to our admin website to complete payment.',
              style: GoogleFonts.outfit(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'URL: $adminUrl',
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.blue),
            ),
            SizedBox(height: 12),
            Text(
              'Note: This is a placeholder URL. Replace with your actual admin website.',
              style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: GoogleFonts.outfit(fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Simulate payment success and update status
              await _simulatePaymentSuccess();
            },
            child: Text('Simulate Payment Success', style: GoogleFonts.outfit(fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _simulatePaymentSuccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      // Get all pre-bookings and find the most recent pending one
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .get();
      
      // Filter and sort in memory to avoid index requirements
      final pendingBookings = snapshot.docs
          .where((doc) => doc.data()['status'] == 'pending_payment')
          .toList()
          ..sort((a, b) => (b.data()['createdAt'] as Timestamp)
              .compareTo(a.data()['createdAt'] as Timestamp));
      
      if (pendingBookings.isNotEmpty) {
        final doc = pendingBookings.first;
        await doc.reference.update({
          'status': 'paid',
          'boardingStatus': 'pending', // Set boarding status to pending when paid
          'paidAt': DateTime.now(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment successful! Your reservation is confirmed.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to reservation confirmation page
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ReservationConfirm(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No pending payment found.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error updating payment status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating payment status. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}