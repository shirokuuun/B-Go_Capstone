import 'dart:math';
import 'dart:convert';
import 'package:b_go/pages/passenger/services/passenger_service.dart';
import 'package:b_go/pages/passenger/services/bus_location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:b_go/pages/user_role/user_selection.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:b_go/config/api_keys.dart';

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
  final LatLng _center = const LatLng(13.9407, 121.1529); // Example: Rosario, Batangas
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

  // Track previous bus positions for efficient updates
  Map<String, LatLng> _previousBusPositions = {};

  // User location for ETA calculation
  LatLng? _userLocation;

  // Google Maps API key for Directions API - loaded from environment variables
  static String get _googleMapsApiKey => ApiKeys.googleMapsApiDirectionsKey;

  // Cache for route calculations to avoid repeated API calls
  Map<String, Map<String, dynamic>> _routeCache = {};

  // Store ETA calculations for each bus
  Map<String, String> _busETAs = {};

  // Filter container animation
  bool _isFilterVisible = false;

  @override
  void initState() {
    super.initState();
    // Debug: Check if API key is loaded correctly
    print('🔑 Google Maps API Key loaded: ${_googleMapsApiKey.substring(0, 10)}...');
    print('🔑 API Key length: ${_googleMapsApiKey.length}');
    print('🔑 Full API Key: $_googleMapsApiKey');
    print('🔑 Is placeholder: ${_googleMapsApiKey == 'YOUR_MAPS_API_DIRECTIONS_KEY_HERE'}');
    
    _loadAvailableRoutes();
    _startBusTracking();
    _getUserLocation();
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
          // Calculate ETA for all visible buses
          _calculateETAsForAllBuses();
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
      print('  Speed: ${bus.speed} m/s');
      print('  Heading: ${bus.heading}°');
      print('  Timestamp: ${bus.timestamp}');
      print('  Name: ${bus.conductorName}');
    }
    print('=== END DEBUG ===');
  }

  // Calculate ETAs for all buses in parallel
  void _calculateETAsForAllBuses() async {
    if (_userLocation == null) return;

    final visibleBuses = _buses.where((bus) {
      return _selectedRoute == null || _matchesRoute(bus.route, _selectedRoute!);
    }).toList();

    for (final bus in visibleBuses) {
      _calculateRoadBasedETA(bus);
    }
  }

  // Updated _updateMarkers method with better debugging and position tracking
  void _updateMarkers() {
    if (!mounted) return;

    print('=== UPDATING MARKERS ===');
    print('Total buses: ${_buses.length}');
    print('Icons loaded: $_iconsLoaded');
    print('Selected route filter: $_selectedRoute');

    if (_buses.isEmpty) {
      print('No buses available to show on map');
      _markers.clear();
      return;
    }

    // Create a new set of markers
    Set<Marker> newMarkers = {};
    Map<String, LatLng> currentPositions = {};

    for (final bus in _buses) {
      print('Processing bus: ${bus.conductorId}');
      print('  Route: "${bus.route}"');
      print('  Location: ${bus.location}');
      print('  Speed: ${bus.speed} m/s');
      print('  Heading: ${bus.heading}°');

      // Track current position
      currentPositions[bus.conductorId] = bus.location;

      // Check if position has changed significantly (more than 10 meters)
      final previousPosition = _previousBusPositions[bus.conductorId];
      final hasPositionChanged = previousPosition == null ||
          _calculateDistance(
                previousPosition.latitude,
                previousPosition.longitude,
                bus.location.latitude,
                bus.location.longitude,
              ) >
              0.01; // ~10 meters

      if (hasPositionChanged) {
        print('  📍 Position changed for ${bus.conductorId}');
        if (previousPosition != null) {
          print('    Previous: ${previousPosition.latitude}, ${previousPosition.longitude}');
          print('    Current: ${bus.location.latitude}, ${bus.location.longitude}');
        }
      }

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

        newMarkers.add(marker);
        print('  ✓ Added marker successfully');
      } catch (e) {
        print('  ✗ Error creating marker: $e');
      }
    }

    // Update markers only if there are changes
    if (newMarkers.length != _markers.length ||
        !newMarkers.every((marker) => _markers.contains(marker))) {
      _markers = newMarkers;
      print('🔄 Markers updated - New count: ${_markers.length}');
    } else {
      print('📌 No marker changes needed');
    }

    // Update previous positions
    _previousBusPositions = currentPositions;
    print('=== END MARKER UPDATE ===');
  }

  // Calculate distance between two points in kilometers
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Get user's current location
  Future<void> _getUserLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services are disabled');
        _userLocation = const LatLng(13.9407, 121.1529); // Fallback to center
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permissions are denied');
          _userLocation = const LatLng(13.9407, 121.1529); // Fallback to center
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permissions are permanently denied');
        _userLocation = const LatLng(13.9407, 121.1529); // Fallback to center
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      _userLocation = LatLng(position.latitude, position.longitude);
      print('📍 User location obtained: $_userLocation');

      // Update markers with new user location
      if (mounted) {
        setState(() {
          _updateMarkers();
          _calculateETAsForAllBuses(); // Recalculate ETAs with new user location
        });
      }
    } catch (e) {
      print('❌ Error getting user location: $e');
      _userLocation = const LatLng(13.9407, 121.1529); // Fallback to center
    }
  }

  // Calculate ETA for a bus to reach user's location using actual roads
  String _calculateETA(BusLocation bus) {
    if (_userLocation == null) {
      return 'Location unavailable';
    }

    // Return cached ETA if available
    if (_busETAs.containsKey(bus.conductorId)) {
      return _busETAs[bus.conductorId]!;
    }

    return 'Calculating...';
  }

  // Get road-based ETA using Google Maps Directions API
  Future<Map<String, dynamic>?> _getRoadBasedETA(LatLng busLocation, LatLng userLocation) async {
    if (_googleMapsApiKey == 'YOUR_MAPS_API_KEY_HERE' || _googleMapsApiKey.isEmpty) {
      print('⚠️ Google Maps API key not configured. Using fallback calculation.');
      return _getFallbackETA(busLocation, userLocation);
    }

    try {
      final origin = '${busLocation.latitude},${busLocation.longitude}';
      final destination = '${userLocation.latitude},${userLocation.longitude}';

      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/directions/json'
          '?origin=$origin'
          '&destination=$destination'
          '&mode=driving'
          '&traffic_model=best_guess'
          '&departure_time=now'
          '&key=$_googleMapsApiKey');

      print('🛣️ Requesting route from $origin to $destination');
      print('🔗 API URL: ${url.toString().replaceAll(_googleMapsApiKey, 'API_KEY_HIDDEN')}');
      print('🔑 Using API Key: ${_googleMapsApiKey.substring(0, 10)}...');

      final response = await http.get(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          final duration = leg['duration']['value']; // Duration in seconds
          final distance = leg['distance']['value']; // Distance in meters

          final result = {
            'duration': duration,
            'distance': distance,
            'route': route,
          };

          // Cache the result
          final cacheKey =
              '${busLocation.latitude},${busLocation.longitude}_${userLocation.latitude},${userLocation.longitude}';
          _routeCache[cacheKey] = result;

          print('✅ Route calculated: ${(duration / 60).round()} min, ${(distance / 1000).toStringAsFixed(1)} km');
          return result;
        } else {
          print('❌ No routes found: ${data['status']}');
          if (data['error_message'] != null) {
            print('🚨 API Error: ${data['error_message']}');
          }
          if (data['status'] == 'REQUEST_DENIED') {
            print('🔑 Check your API key and make sure Directions API is enabled');
            print('🔑 Current API key starts with: ${_googleMapsApiKey.substring(0, 10)}...');
            print('🔑 Full API key: $_googleMapsApiKey');
            print('🔑 API key length: ${_googleMapsApiKey.length}');
          }
          print('📄 Full API Response: ${response.body}');
          return _getFallbackETA(busLocation, userLocation);
        }
      } else {
        print('❌ API request failed: ${response.statusCode}');
        print('📄 Response: ${response.body}');
        return _getFallbackETA(busLocation, userLocation);
      }
    } catch (e) {
      print('❌ Error getting road-based ETA: $e');
      return _getFallbackETA(busLocation, userLocation);
    }
  }

  // Fallback ETA calculation when API is not available
  Map<String, dynamic> _getFallbackETA(LatLng busLocation, LatLng userLocation) {
    final distance = _calculateDistance(
      busLocation.latitude,
      busLocation.longitude,
      userLocation.latitude,
      userLocation.longitude,
    );

    // Use a more realistic speed factor for road travel
    // Straight line distance * 1.3 to account for road curves
    final roadDistance = distance * 1.3;

    // Assume average bus speed of 25 km/h in city traffic
    const double averageBusSpeed = 25.0; // km/h
    final etaMinutes = (roadDistance / averageBusSpeed) * 60;

    return {
      'duration': etaMinutes * 60, // Convert to seconds
      'distance': roadDistance * 1000, // Convert to meters
      'route': null,
    };
  }

  // Format ETA in a user-friendly way
  String _formatETA(double etaMinutes) {
    if (etaMinutes < 1) {
      return 'Less than 1 min';
    } else if (etaMinutes < 60) {
      return '${etaMinutes.round()} min';
    } else {
      final hours = (etaMinutes / 60).floor();
      final minutes = (etaMinutes % 60).round();
      return '${hours}h ${minutes}m';
    }
  }

  // Get distance in a more user-friendly format using road distance
  String _getDistanceText(BusLocation bus) {
    if (_userLocation == null) {
      return 'Distance unavailable';
    }

    // Check cache first
    final cacheKey =
        '${bus.location.latitude},${bus.location.longitude}_${_userLocation!.latitude},${_userLocation!.longitude}';
    if (_routeCache.containsKey(cacheKey)) {
      final cachedData = _routeCache[cacheKey]!;
      final distanceKm = cachedData['distance'] / 1000; // Convert meters to km
      if (distanceKm < 1) {
        return '${(distanceKm * 1000).round()}m away';
      } else {
        return '${distanceKm.toStringAsFixed(1)}km away';
      }
    }

    // Fallback to straight-line distance with road factor
    final straightDistance = _calculateDistance(
      bus.location.latitude,
      bus.location.longitude,
      _userLocation!.latitude,
      _userLocation!.longitude,
    );

    // Apply road factor (1.3x for typical city roads)
    final roadDistance = straightDistance * 1.3;

    if (roadDistance < 1) {
      return '${(roadDistance * 1000).round()}m away';
    } else {
      return '${roadDistance.toStringAsFixed(1)}km away';
    }
  }

  // Refresh user location manually
  Future<void> _refreshUserLocation() async {
    print('🔄 Refreshing user location...');
    await _getUserLocation();
    // Show a snackbar to inform user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_userLocation != null
              ? 'Location updated successfully'
              : 'Unable to get location'),
          backgroundColor: _userLocation != null ? Colors.green : Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Calculate road-based ETA and update the UI
  Future<void> _calculateRoadBasedETA(BusLocation bus) async {
    if (_userLocation == null) return;

    try {
      final routeData = await _getRoadBasedETA(bus.location, _userLocation!);
      if (routeData != null && mounted) {
        final etaString = _formatETA(routeData['duration'] / 60);
        
        // Store the ETA for this bus
        setState(() {
          _busETAs[bus.conductorId] = etaString;
        });

        print('✅ Road-based ETA calculated for ${bus.conductorId}: $etaString');
      }
    } catch (e) {
      print('❌ Error calculating road-based ETA: $e');
    }
  }

  void _showBusInfoPopup(BusLocation bus) {
    // Trigger road-based ETA calculation if not already calculated
    if (!_busETAs.containsKey(bus.conductorId)) {
      _calculateRoadBasedETA(bus);
    }

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
                        SizedBox(height: 8),
                        // ETA and Distance info
                        Wrap(
                          spacing: 16,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 16,
                                  color: Colors.green[600],
                                ),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _calculateETA(bus),
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.blue[600],
                                ),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _getDistanceText(bus),
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                        final data = snapshot.data!.docs.first.data() as Map<String, dynamic>?;
                        passengerCount = data?['passengerCount'] ?? 0;
                      }

                      final isFull = passengerCount >= 27;

                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isFull ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: isFull ? Colors.red : Colors.green, width: 1),
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
    return _busIcons['default'] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
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
    final titleFontSize = isMobile ? 20.0 : isTablet ? 22.0 : 24.0;
    final drawerHeaderFontSize = isMobile ? 30.0 : isTablet ? 34.0 : 38.0;
    final drawerItemFontSize = isMobile ? 18.0 : isTablet ? 20.0 : 22.0;
    final busCountFontSize = isMobile ? 18.0 : isTablet ? 20.0 : 22.0;
    final busCountSubFontSize = isMobile ? 12.0 : isTablet ? 14.0 : 16.0;

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
            icon: Icon(Icons.my_location, color: Colors.white),
            onPressed: _refreshUserLocation,
            tooltip: 'Refresh My Location',
          ),
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
                horizontal: isMobile ? 16 : 20,
                vertical: isMobile ? 12 : 16),
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
                  Icon(Icons.directions_bus, color: Color(0xFF0091AD), size: isMobile ? 24 : 28),
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