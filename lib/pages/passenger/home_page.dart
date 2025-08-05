import 'dart:math';
import 'package:b_go/pages/passenger/services/passenger_service.dart';
import 'package:b_go/pages/passenger/services/bus_location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:b_go/pages/user_role/user_selection.dart';

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

  @override
  void initState() {
    super.initState();
    _loadAvailableRoutes();
    _startBusTracking();
    _createCustomBusIcons();
  }

  Future<void> _createCustomBusIcons() async {
    // Create custom bus icons with different colors for each route
    // Use the same colors as defined in _getColorForRoute method
    _busIcons = {
      'batangas': await _createCustomBusIcon(Colors.red),
      'mataas na kahoy': await _createCustomBusIcon(Colors.purple),
      'rosario': await _createCustomBusIcon(Colors.blue), // Changed from pink to blue
      'tiaong': await _createCustomBusIcon(Colors.green),
      'san juan': await _createCustomBusIcon(Colors.yellow),
      'default': await _createCustomBusIcon(Colors.cyan),
    };
  }

  Future<BitmapDescriptor> _createCustomBusIcon(Color color) async {
    // Create a custom bus icon with the specified color
    // For now, we'll use a colored marker, but you can replace this with actual bus icon
    return BitmapDescriptor.defaultMarkerWithHue(_colorToHue(color));
  }

  double _colorToHue(Color color) {
    // Convert Color to HSV hue value for BitmapDescriptor
    final hsl = HSLColor.fromColor(color);
    return hsl.hue;
  }

  Future<void> _loadAvailableRoutes() async {
    try {
      final routes = await _busLocationService.getAvailableRoutes();
      setState(() {
        // Clean up routes by trimming spaces and removing duplicates
        _availableRoutes = routes
            .map((route) => route.trim())
            .where((route) => route.isNotEmpty)
            .toSet()
            .toList()
            ..sort(); // Sort alphabetically
      });
    } catch (e) {
      print('Error loading routes: $e');
    }
  }

  void _startBusTracking() {
    // Listen to all online buses
    _busLocationService.getOnlineBuses().listen((buses) {
      setState(() {
        _buses = buses;
        _updateMarkers();
      });
    });
  }

  void _updateMarkers() {
    _markers.clear();
    
    for (final bus in _buses) {
      // Skip if route filter is applied and bus doesn't match
      if (_selectedRoute != null && !_matchesRoute(bus.route, _selectedRoute!)) {
        continue;
      }

      final marker = Marker(
        markerId: MarkerId(bus.conductorId),
        position: bus.location,
        onTap: () => _showBusInfoPopup(bus),
        icon: _getBusIcon(bus.route),
        rotation: bus.heading,
        flat: true, // Makes the marker flat on the map
        anchor: Offset(0.5, 0.5), // Centers the marker
        zIndex: 1000, // Ensures bus markers appear above other markers
      );
      
      _markers.add(marker);
    }
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
                  // Passenger count (placeholder for now)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green, width: 1),
                    ),
                    child: Text(
                      '0/27 Passengers', // Placeholder - you'll update this
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
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

  BitmapDescriptor _getBusIcon(String route) {
    final routeKey = route.trim().toLowerCase();
    
    // Return default marker if icons are not ready yet
    if (_busIcons.isEmpty) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
    
    final icon = _busIcons[routeKey] ?? _busIcons['default'] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    return icon;
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

  void _showRouteFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filter by Route', style: GoogleFonts.outfit()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Show All Routes', style: GoogleFonts.outfit()),
              leading: Radio<String?>(
                value: null,
                groupValue: _selectedRoute,
                onChanged: (value) {
                  setState(() {
                    _selectedRoute = value;
                    _updateMarkers();
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            ..._availableRoutes.map((route) => ListTile(
              title: Text(route, style: GoogleFonts.outfit()),
              leading: Radio<String?>(
                value: route,
                groupValue: _selectedRoute,
                onChanged: (value) {
                  setState(() {
                    _selectedRoute = value;
                    _updateMarkers();
                  });
                  Navigator.pop(context);
                },
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _centerOnBuses() {
    if (_buses.isNotEmpty) {
      final bounds = _calculateBounds();
      mapController.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50.0),
      );
    }
  }

  LatLngBounds _calculateBounds() {
    if (_buses.isEmpty) {
      return LatLngBounds(
        southwest: LatLng(_center.latitude - 0.01, _center.longitude - 0.01),
        northeast: LatLng(_center.latitude + 0.01, _center.longitude + 0.01),
      );
    }

    double minLat = _buses.first.location.latitude;
    double maxLat = _buses.first.location.latitude;
    double minLng = _buses.first.location.longitude;
    double maxLng = _buses.first.location.longitude;

    for (final bus in _buses) {
      minLat = min(minLat, bus.location.latitude);
      maxLat = max(maxLat, bus.location.latitude);
      minLng = min(minLng, bus.location.longitude);
      maxLng = max(maxLng, bus.location.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0091AD),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onPressed: _showRouteFilterDialog,
            tooltip: 'Filter by Route',
          ),
          IconButton(
            icon: Icon(Icons.center_focus_strong, color: Colors.white),
            onPressed: _centerOnBuses,
            tooltip: 'Center on Buses',
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
                  fontSize: 30,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text(
                'Home',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/home');
              },
            ),
            ListTile(
              leading: Icon(Icons.directions_bus),
              title: Text(
                'Role Selection',
                style: GoogleFonts.outfit(
                  fontSize: 18,
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
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/trip_sched');
              },
            ),
            ListTile(
              leading: Icon(Icons.map),
              title: Text(
                'Batrasco Routes',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                // TODO: Navigate to Batrasco Routes page
                Navigator.pop(context);
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
            top: 16,
            left: 16,
            child: Container(
              constraints: BoxConstraints(
                minWidth: 100,
                maxWidth: 200,
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  Icon(Icons.directions_bus, color: Color(0xFF0091AD), size: 24),
                  SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_markers.length}',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0091AD),
                          ),
                        ),
                        Text(
                          'buses online',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
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
          // Route filter indicator with enhanced styling
          if (_selectedRoute != null)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                constraints: BoxConstraints(
                  minWidth: 100,
                  maxWidth: 250,
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Color(0xFF0091AD),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.filter_list, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _selectedRoute!,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRoute = null;
                          _updateMarkers();
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Legend for bus colors - show all routes
          if (_busIcons.isNotEmpty)
            Positioned(
              bottom: 100,
              left: 16,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 200,
                  maxHeight: 200,
                ),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Route Colors',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: _getUniqueRoutes().map((route) => Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _getColorForRoute(route),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    route.toUpperCase(),
                                    style: GoogleFonts.outfit(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                  ],
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

  List<String> _getUniqueRoutes() {
    Set<String> uniqueRoutes = {};
    
    // Add routes from available routes
    uniqueRoutes.addAll(_availableRoutes);
    
    // Add routes from online buses
    for (final bus in _buses) {
      if (bus.isOnline && bus.route.trim().isNotEmpty) {
        uniqueRoutes.add(bus.route.trim());
      }
    }
    
    // Convert to list and sort
    return uniqueRoutes.toList()..sort();
  }

  Color _getColorForRoute(String route) {
    switch (route.trim().toLowerCase()) {
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
      default:
        return Colors.cyan;
    }
  }
}
