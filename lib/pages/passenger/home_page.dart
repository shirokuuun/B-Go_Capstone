import 'package:b_go/pages/passenger/services/passenger_service.dart';
import 'package:b_go/pages/passenger/services/bus_location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:b_go/pages/user_role/user_selection.dart';
import 'package:responsive_framework/responsive_framework.dart';

class HomePage extends StatefulWidget {
  final String role;
  const HomePage({super.key, required this.role});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;
  late GoogleMapController mapController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final LatLng _center =
      const LatLng(13.9407, 121.1529); // Example: Rosario, Batangas
  int _selectedIndex = 0;

  // Bus location tracking
  final BusLocationService _busLocationService = BusLocationService();
  List<BusLocation> _buses = [];
  Set<Marker> _markers = {};
  String? _selectedRoute;
  List<String> _availableRoutes = [];

  // Custom bus icons
  Map<String, BitmapDescriptor> _busIcons = {};
  bool _iconsLoaded = false;

  // Filter container animation
  bool _isFilterVisible = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableRoutes();
    _startBusTracking();
    // Delay icon loading to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _createCustomBusIcons();
    });
  }

  Future<void> _createCustomBusIcons() async {
    try {
      print('Starting to load custom bus icons...');
      
      // Use proper ImageConfiguration with appropriate size for map markers
      final ImageConfiguration config = ImageConfiguration(
        size: Size(24, 24), // Smaller size that scales better with map zoom
        devicePixelRatio: 2.0,
      );
      
      // Load custom bus icons with proper error handling
      _busIcons = {
        'batangas': await BitmapDescriptor.fromAssetImage(
          config,
          'assets/bus_red.png',
        ),
        'mataas na kahoy': await BitmapDescriptor.fromAssetImage(
          config,
          'assets/bus_purple.png',
        ),
        'mataas na kahoy palengke': await BitmapDescriptor.fromAssetImage(
          config,
          'assets/bus_orange.png',
        ),
        'rosario': await BitmapDescriptor.fromAssetImage(
          config,
          'assets/bus_blue.png',
        ),
        'tiaong': await BitmapDescriptor.fromAssetImage(
          config,
          'assets/bus_green.png',
        ),
        'san juan': await BitmapDescriptor.fromAssetImage(
          config,
          'assets/bus_yellow.png',
        ),
        'default': await BitmapDescriptor.fromAssetImage(
          config,
          'assets/bus.png',
        ),
      };
      
      print('Successfully loaded ${_busIcons.length} bus icons');
      print('Icon keys: ${_busIcons.keys.toList()}');
      
      if (mounted) {
        setState(() {
          _iconsLoaded = true;
          _updateMarkers();
        });
      }
    } catch (e) {
      print('Error creating custom bus icons: $e');
      // Fallback: create simple colored markers
      _createFallbackMarkers();
    }
  }

   // Add this fallback method with smaller markers
   void _createFallbackMarkers() {
     print('Creating fallback markers with default colors...');
     _busIcons = {
       'batangas': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
       'mataas na kahoy': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
       'mataas na kahoy palengke': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
       'rosario': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
       'tiaong': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
       'san juan': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
       'default': BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
     };
     
     if (mounted) {
       setState(() {
         _iconsLoaded = true;
         _updateMarkers();
       });
     }
   }


  Future<void> _loadAvailableRoutes() async {
    try {
      final routes = await _busLocationService.getAvailableRoutes();
      if (mounted) {
        setState(() {
          // Clean up routes by trimming spaces and removing duplicates
          _availableRoutes = routes
              .map((route) => route.trim())
              .where((route) => route.isNotEmpty)
              .toSet()
              .toList()
            ..sort(); // Sort alphabetically
        });
      }
    } catch (e) {
      print('Error loading routes: $e');
    }
  }

  void _startBusTracking() {
    // Listen to all online buses
    _busLocationService.getOnlineBuses().listen((buses) {
      if (mounted) {
        setState(() {
          _buses = buses;
          _debugBusData(); // Add debug output
          _updateMarkers();
        });
      }
    });
  }

  void _debugBusData() {
    print('=== BUS DATA DEBUG ===');
    print('Number of buses: ${_buses.length}');
    for (int i = 0; i < _buses.length; i++) {
      final bus = _buses[i];
      print('Bus $i:');
      print('  ID: ${bus.conductorId}');
      print('  Route: "${bus.route}"');
      print('  Location: ${bus.location}');
      print('  Name: ${bus.conductorName}');
    }
    print('=== END DEBUG ===');
  }

  // Updated _updateMarkers method with better debugging
  void _updateMarkers() {
    if (!mounted) return;
    
    _markers.clear();
    
    print('=== UPDATING MARKERS ===');
    print('Total buses: ${_buses.length}');
    print('Icons loaded: $_iconsLoaded');
    print('Selected route filter: $_selectedRoute');
    print('Available bus icons: ${_busIcons.keys.toList()}');

    if (_buses.isEmpty) {
      print('No buses available to show on map');
      return;
    }

    for (final bus in _buses) {
      print('Processing bus: ${bus.conductorId}');
      print('  Route: "${bus.route}"');
      print('  Location: ${bus.location}');
      print('  Conductor: ${bus.conductorName}');
      
      // Skip if route filter is applied and bus doesn't match
      if (_selectedRoute != null && !_matchesRoute(bus.route, _selectedRoute!)) {
        print('  Skipped: Route filter mismatch');
        continue;
      }

      try {
         final marker = Marker(
           markerId: MarkerId(bus.conductorId),
           position: bus.location,
           onTap: () => _showBusInfoPopup(bus),
           icon: _getBusIcon(bus.route),
           rotation: bus.heading, // Use heading directly
           flat: true, // Keep markers flat on the map
           anchor: const Offset(0.5, 0.5), // Center the marker
           zIndex: 1000, // Keep above other markers
           infoWindow: InfoWindow(
             title: bus.route.trim(),
             snippet: bus.conductorName,
           ),
         );

        _markers.add(marker);
        print('  ✓ Added marker successfully');
      } catch (e) {
        print('  ✗ Error creating marker: $e');
      }
    }
    
    print('Final marker count: ${_markers.length}');
    print('=== END MARKER UPDATE ===');
  }

  void _showBusInfoPopup(BusLocation bus) {
    // Format speed for display
    final speedKmh = (bus.speed * 3.6).round(); // Convert m/s to km/h

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: EdgeInsets.only(bottom: 80), // Space above bottom navigation
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with bus icon and route info
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getColorForRoute(bus.route).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.directions_bus,
                      color: _getColorForRoute(bus.route),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${speedKmh} km/h',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          bus.route.trim(),
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          bus.conductorName,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Passenger count from Firestore
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('conductors')
                        .where('uid', isEqualTo: bus.conductorId)
                        .limit(1)
                        .snapshots(),
                    builder: (context, snapshot) {
                      int passengerCount = 0;
                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        final data = snapshot.data!.docs.first.data()
                            as Map<String, dynamic>?;
                        passengerCount = data?['passengerCount'] ?? 0;
                      }

                      final isFull = passengerCount >= 27;

                      return Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isFull
                              ? Colors.red.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isFull ? Colors.red : Colors.green,
                              width: 1),
                        ),
                        child: Text(
                          '$passengerCount/27 Passengers',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isFull ? Colors.red : Colors.green,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(height: 16),
              // Close button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Exit',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to match routes properly (handles trailing spaces)
  bool _matchesRoute(String busRoute, String selectedRoute) {
    final normalizedBusRoute = busRoute.trim().toLowerCase();
    final normalizedSelectedRoute = selectedRoute.trim().toLowerCase();
    return normalizedBusRoute == normalizedSelectedRoute;
  }

  // Updated _getBusIcon with better fallback logic
  BitmapDescriptor _getBusIcon(String route) {
    final routeKey = route.trim().toLowerCase();
    
    print('Getting bus icon for route: "$route" (normalized: "$routeKey")');

    // If icons are not loaded yet, use default colored markers immediately
    if (!_iconsLoaded || _busIcons.isEmpty) {
      print('Icons not ready, using fallback color marker');
      switch (routeKey) {
        case 'batangas':
          return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
        case 'rosario':
          return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
        case 'tiaong':
          return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        case 'san juan':
          return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
        case 'mataas na kahoy':
          return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet);
        case 'mataas na kahoy palengke':
          return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
        default:
          return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      }
    }

    // Try exact match first
    if (_busIcons.containsKey(routeKey)) {
      print('Found exact match for route: $routeKey');
      return _busIcons[routeKey]!;
    }

    // Try partial matches
    for (String key in _busIcons.keys) {
      if (key != 'default' && (routeKey.contains(key) || key.contains(routeKey))) {
        print('Found partial match: $key for route: $routeKey');
        return _busIcons[key]!;
      }
    }

    // Fallback to default
    print('Using default bus icon for route: $routeKey');
    return _busIcons['default'] ?? 
           BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _onItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/home');
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PassengerService()),
        );
        break;
      case 2:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  void _toggleFilterContainer() {
    setState(() {
      _isFilterVisible = !_isFilterVisible;
    });
  }

  void _selectRoute(String? route) {
    setState(() {
      _selectedRoute = route;
      _updateMarkers();
      _isFilterVisible = false; // Close filter after selection
    });
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
            ? 22.0
            : 24.0;
    final drawerHeaderFontSize = isMobile
        ? 30.0
        : isTablet
            ? 34.0
            : 38.0;
    final drawerItemFontSize = isMobile
        ? 18.0
        : isTablet
            ? 20.0
            : 22.0;
    final busCountFontSize = isMobile
        ? 18.0
        : isTablet
            ? 20.0
            : 22.0;
    final busCountSubFontSize = isMobile
        ? 12.0
        : isTablet
            ? 14.0
            : 16.0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: Text(
          "B-Go Map",
          style: GoogleFonts.outfit(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0091AD),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onPressed: _toggleFilterContainer,
            tooltip: 'Filter by Route',
          ),
        ],
      ),
      key: _scaffoldKey,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF0091AD),
              ),
              child: Text(
                'Menu',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: drawerHeaderFontSize,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text(
                'Home',
                style: GoogleFonts.outfit(
                  fontSize: drawerItemFontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/home');
              },
            ),
            ListTile(
              leading: Icon(Icons.swap_horiz),
              title: Text(
                'Role Selection',
                style: GoogleFonts.outfit(
                  fontSize: drawerItemFontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserSelection()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.schedule),
              title: Text(
                'Trip Schedules',
                style: GoogleFonts.outfit(
                  fontSize: drawerItemFontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/trip_sched');
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _center,
              zoom: 14.0,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: true,
          ),
          // Bus count indicator with enhanced styling
          Positioned(
            top: isMobile ? 16 : 20,
            left: isMobile ? 16 : 20,
            child: Container(
              constraints: BoxConstraints(
                minWidth: isMobile ? 100 : 120,
                maxWidth: isMobile ? 200 : 250,
              ),
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 20, vertical: isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
                border: Border.all(color: Color(0xFF0091AD), width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_bus,
                      color: Color(0xFF0091AD), size: isMobile ? 24 : 28),
                  SizedBox(width: isMobile ? 8 : 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_markers.length}',
                          style: GoogleFonts.outfit(
                            fontSize: busCountFontSize,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0091AD),
                          ),
                        ),
                        Text(
                          'buses online${_iconsLoaded ? ' ✓' : ' (loading...)'}',
                          style: GoogleFonts.outfit(
                            fontSize: busCountSubFontSize,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Backdrop overlay
          if (_isFilterVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _toggleFilterContainer,
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ),
          // Sliding Filter Container
          AnimatedPositioned(
            duration: Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            bottom: _isFilterVisible ? 0 : -MediaQuery.of(context).size.height * 0.6,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.6,
              child: GestureDetector(
                onPanUpdate: (details) {
                  // Allow swiping down to close
                  if (details.delta.dy > 0) {
                    _toggleFilterContainer();
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 15,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        margin: EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.filter_list,
                              color: Color(0xFF0091AD),
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Filter by Route',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Spacer(),
                            GestureDetector(
                              onTap: _toggleFilterContainer,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(Icons.close, color: Colors.grey[600], size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Filter options
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              // Show All Routes option
                              Container(
                                width: double.infinity,
                                margin: EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: _selectedRoute == null 
                                      ? Color(0xFF0091AD).withOpacity(0.1)
                                      : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedRoute == null 
                                        ? Color(0xFF0091AD)
                                        : Colors.grey[300]!,
                                    width: 2,
                                  ),
                                ),
                                child: ListTile(
                                  title: Text(
                                    'Show All Routes',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedRoute == null 
                                          ? Color(0xFF0091AD)
                                          : Colors.black87,
                                    ),
                                  ),
                                  leading: Radio<String?>(
                                    value: null,
                                    groupValue: _selectedRoute,
                                    onChanged: _selectRoute,
                                    activeColor: Color(0xFF0091AD),
                                  ),
                                  onTap: () => _selectRoute(null),
                                ),
                              ),
                              // Individual route options
                              ..._availableRoutes.map((route) => Container(
                                    width: double.infinity,
                                    margin: EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: _selectedRoute == route 
                                          ? Color(0xFF0091AD).withOpacity(0.1)
                                          : Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _selectedRoute == route 
                                            ? Color(0xFF0091AD)
                                            : Colors.grey[300]!,
                                        width: 2,
                                      ),
                                    ),
                                    child: ListTile(
                                      title: Text(
                                        route,
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: _selectedRoute == route 
                                              ? Color(0xFF0091AD)
                                              : Colors.black87,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      leading: Radio<String?>(
                                        value: route,
                                        groupValue: _selectedRoute,
                                        onChanged: _selectRoute,
                                        activeColor: Color(0xFF0091AD),
                                      ),
                                      onTap: () => _selectRoute(route),
                                    ),
                                  )),
                              SizedBox(height: 20), // Extra space at bottom
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus),
            label: 'Passenger Service',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Color(0xFF0091AD),
        onTap: _onItemTapped,
      ),
    );
  }

  Color _getColorForRoute(String route) {
    switch (route.toLowerCase()) {
      case 'batangas':
        return Colors.red;
      case 'rosario':
        return Colors.blue;
      case 'tiaong':
        return Colors.green;
      case 'san juan':
        return Colors.yellow;
      case 'mataas na kahoy':
        return Colors.purple;
      case 'mataas na kahoy palengke':
        return Colors.orange;
      default:
        return Colors.cyan;
    }
  }
}