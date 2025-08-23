import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:b_go/pages/conductor/destination_service.dart';
import 'dart:async';
import 'dart:ui' as ui;

class ConductorMaps extends StatefulWidget {
  final String route;
  final String role;

  const ConductorMaps({super.key, required this.route, required this.role});

  @override
  State<ConductorMaps> createState() => _ConductorMapsState();
}

class _ConductorMapsState extends State<ConductorMaps> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  int passengerCount = 0;
  List<Map<String, dynamic>> _activeBookings = [];
  List<Map<String, dynamic>> _routeDestinations = [];
  Timer? _locationTimer;
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _conductorSubscription;

  // Helper method to convert any numeric value to double
  double? _convertToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed;
    }
    return null;
  }

  // Create custom circular marker icon (small blue circle)
  BitmapDescriptor _getCircularMarkerIcon() {
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  // Create custom small circular marker for different types
  BitmapDescriptor _getSmallCircularMarker(Color color) {
    return BitmapDescriptor.defaultMarkerWithHue(_colorToHue(color));
  }

  // Create custom human icon for passengers
  BitmapDescriptor _getHumanIcon() {
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
  }

  // Convert Color to BitmapDescriptor hue
  double _colorToHue(Color color) {
    if (color == Colors.blue) return BitmapDescriptor.hueAzure;
    if (color == Colors.yellow) return BitmapDescriptor.hueYellow;
    if (color == Colors.green) return BitmapDescriptor.hueGreen;
    if (color == Colors.red) return BitmapDescriptor.hueRed;
    return BitmapDescriptor.hueAzure; // default
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadRouteDestinations();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _bookingsSubscription?.cancel();
    _conductorSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoading = false;
        });
        _startLocationTracking();
        _loadBookings();
        _loadConductorData();
      }
    } catch (e) {
      print('Error getting current location: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startLocationTracking() {
    _locationTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      // Removed automatic passenger drop-off check
      // Passengers will only be removed when scanned by the conductor
    });
  }

  void _loadConductorData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _conductorSubscription = FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final conductorData = snapshot.docs.first.data();
          // Don't override passenger count here - it will be calculated from active bookings
          print('🗺️ ConductorMaps: Conductor data loaded');
        }
      });
    }
  }

  StreamSubscription<QuerySnapshot>? _bookingsSubscription;

  void _loadRouteDestinations() async {
    try {
      print('🗺️ ConductorMaps: Loading destinations for route: ${widget.route}');
      
      // Get the route ID from conductor data since the route parameter is the route name
      String routeId = '';
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // First, get the conductor data to find the route name
          final conductorQuery = await FirebaseFirestore.instance
              .collection('conductors')
              .where('uid', isEqualTo: user.uid)
              .limit(1)
              .get();
          
          if (conductorQuery.docs.isNotEmpty) {
            final conductorData = conductorQuery.docs.first.data();
            final routeName = conductorData['route'] as String?;
            
            if (routeName != null && routeName.isNotEmpty) {
              print('🗺️ ConductorMaps: Route name from conductor: $routeName');
              
              // Use the route name directly as the document ID since they now match
              routeId = routeName;
              print('🗺️ ConductorMaps: Using route name as document ID: $routeId');
            }
          }
        }
      } catch (e) {
        print('🗺️ ConductorMaps: Could not get route ID from conductor data: $e');
      }
      
      // If we still don't have a route ID, use the original route parameter
      if (routeId.isEmpty) {
        routeId = widget.route;
        print('🗺️ ConductorMaps: Using original route parameter as route ID: $routeId');
      }
      
      print('🗺️ ConductorMaps: Final route ID being used: $routeId');
      
      final destinations =
          await DestinationService.fetchRouteDestinations(routeId);
      
      print('🗺️ ConductorMaps: Raw destinations data: $destinations');
      
      if (mounted) {
        setState(() {
          _routeDestinations = destinations;
        });

        // Get route range for display
        final routeRange = DestinationService.getRouteRange(destinations);
        print(
            '🗺️ ConductorMaps: Route $routeId range: ${routeRange['firstKm']}-${routeRange['lastKm']} km');
        print('🗺️ ConductorMaps: Loaded ${destinations.length} destinations');

        // Debug: Print all destinations with more detail
        for (final dest in destinations) {
          print(
              '🗺️ Destination: ${dest['name']} at (${dest['latitude']}, ${dest['longitude']}) - ${dest['direction']} route - km: ${dest['km']}');
        }
        
        // If no destinations loaded, try to debug the issue
        if (destinations.isEmpty) {
          print('🗺️ ConductorMaps: ⚠️ No destinations loaded! This might indicate a data structure issue.');
          print('🗺️ ConductorMaps: Route ID being searched: $routeId');
          
          // Try manual fallback fetch with the route ID
          await _manualFetchDestinations(routeId);
        }
      }
    } catch (e) {
      print('Error loading route destinations: $e');
      // Try manual fallback fetch on error
      await _manualFetchDestinations(widget.route);
    }
  }

  // Manual fallback method to fetch destinations directly from Firestore
  Future<void> _manualFetchDestinations(String routeName) async {
    try {
      print('🗺️ ConductorMaps: Attempting manual fallback fetch for route: $routeName');
      
      // Try to fetch directly from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('Destinations')
          .doc(routeName)
          .get();
      
      if (snapshot.exists) {
        print('🗺️ ConductorMaps: Found route document: ${snapshot.data()}');
        
        // Try to get Place collection
        final placeSnapshot = await FirebaseFirestore.instance
            .collection('Destinations')
            .doc(routeName)
            .collection('Place')
            .get();
            
        print('🗺️ ConductorMaps: Place collection has ${placeSnapshot.docs.length} documents');
        
        // Try to get Place 2 collection
        final place2Snapshot = await FirebaseFirestore.instance
            .collection('Destinations')
            .doc(routeName)
            .collection('Place 2')
            .get();
            
        print('🗺️ ConductorMaps: Place 2 collection has ${place2Snapshot.docs.length} documents');
        
        // If we found documents, process them manually
        if (placeSnapshot.docs.isNotEmpty || place2Snapshot.docs.isNotEmpty) {
          List<Map<String, dynamic>> manualDestinations = [];
          
          // Process Place collection
          for (var doc in placeSnapshot.docs) {
            final data = doc.data();
            print('🗺️ ConductorMaps: Place doc ${doc.id}: $data');
            
            final latitude = _convertToDouble(data['latitude']);
            final longitude = _convertToDouble(data['longitude']);
            
            if (latitude != null && longitude != null) {
              manualDestinations.add({
                'name': data['Name']?.toString() ?? doc.id,
                'km': _convertToDouble(data['km']) ?? 0.0,
                'latitude': latitude,
                'longitude': longitude,
                'direction': 'forward',
              });
            }
          }
          
          // Process Place 2 collection
          for (var doc in place2Snapshot.docs) {
            final data = doc.data();
            print('🗺️ ConductorMaps: Place 2 doc ${doc.id}: $data');
            
            final latitude = _convertToDouble(data['latitude']);
            final longitude = _convertToDouble(data['longitude']);
            
            if (latitude != null && longitude != null) {
              manualDestinations.add({
                'name': data['Name']?.toString() ?? doc.id,
                'km': _convertToDouble(data['km']) ?? 0.0,
                'latitude': latitude,
                'longitude': longitude,
                'direction': 'reverse',
              });
            }
          }
          
          if (manualDestinations.isNotEmpty && mounted) {
            setState(() {
              _routeDestinations = manualDestinations;
            });
            print('🗺️ ConductorMaps: ✅ Manual fetch successful! Loaded ${manualDestinations.length} destinations');
          }
        } else {
          print('🗺️ ConductorMaps: ⚠️ Both Place and Place 2 collections are empty');
          
          // Try some other common collection names that might exist
          final possibleCollections = ['Destinations', 'Stops', 'Locations', 'Points'];
          
          for (final collectionName in possibleCollections) {
            try {
              print('🗺️ ConductorMaps: Trying collection: $collectionName');
              final otherSnapshot = await FirebaseFirestore.instance
                  .collection('Destinations')
                  .doc(routeName)
                  .collection(collectionName)
                  .get();
              
              print('🗺️ ConductorMaps: Collection $collectionName has ${otherSnapshot.docs.length} documents');
              
              if (otherSnapshot.docs.isNotEmpty) {
                // Process this collection
                List<Map<String, dynamic>> otherDestinations = [];
                
                for (var doc in otherSnapshot.docs) {
                  final data = doc.data();
                  print('🗺️ ConductorMaps: $collectionName doc ${doc.id}: $data');
                  
                  final latitude = _convertToDouble(data['latitude']);
                  final longitude = _convertToDouble(data['longitude']);
                  
                  if (latitude != null && longitude != null) {
                    otherDestinations.add({
                      'name': data['Name']?.toString() ?? doc.id,
                      'km': _convertToDouble(data['km']) ?? 0.0,
                      'latitude': latitude,
                      'longitude': longitude,
                      'direction': collectionName,
                    });
                  }
                }
                
                if (otherDestinations.isNotEmpty && mounted) {
                  setState(() {
                    _routeDestinations = otherDestinations;
                  });
                  print('🗺️ ConductorMaps: ✅ Found destinations in collection $collectionName! Loaded ${otherDestinations.length} destinations');
                  break;
                }
              }
            } catch (e) {
              print('🗺️ ConductorMaps: Could not access collection $collectionName: $e');
            }
          }
        }
      } else {
        print('🗺️ ConductorMaps: ❌ Route document $routeName does not exist in Destinations collection');
      }
    } catch (e) {
      print('🗺️ ConductorMaps: Manual fetch failed: $e');
    }
  }

  void _loadBookings() {
    print(
        '🗺️ ConductorMaps: Starting to load bookings for route: ${widget.route}');

    // Cancel existing subscription if any
    _bookingsSubscription?.cancel();

    _bookingsSubscription = FirebaseFirestore.instance
        .collectionGroup('preBookings')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final allPreBookings = snapshot.docs;
        print(
            '🗺️ ConductorMaps: Total pre-bookings found: ${allPreBookings.length}');

        final preBookings = allPreBookings.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final matchesRoute = data['route'] == widget.route;
          final isPaid = data['status'] == 'paid';
          final isPending = data['status'] == 'pending_payment';
          final isNotBoarded = data['boardingStatus'] != 'boarded';
          print(
              '🗺️ ConductorMaps: Booking ${doc.id} - Route: ${data['route']} (matches: $matchesRoute), Status: ${data['status']} (paid: $isPaid, pending: $isPending, not boarded: $isNotBoarded)');
          return matchesRoute &&
              (isPaid || isPending) &&
              isNotBoarded; // Only show paid/pending bookings that are not boarded
        }).toList();

        print(
            '🗺️ ConductorMaps: Filtered bookings for route ${widget.route}: ${preBookings.length}');

        // Use post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              // Calculate passenger count from active bookings
              int totalPassengers = 0;
              _activeBookings = preBookings.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final quantity = (data['quantity'] ?? 1) as int;
                totalPassengers += quantity; // Add to total count

                final booking = {
                  'id': doc.id,
                  'from': data['from'],
                  'to': data['to'],
                  'quantity': quantity,
                  'fromLatitude': _convertToDouble(data['fromLatitude']),
                  'fromLongitude': _convertToDouble(data['fromLongitude']),
                  'toLatitude': _convertToDouble(data['toLatitude']),
                  'toLongitude': _convertToDouble(data['toLongitude']),
                  // Add passenger current location
                  'passengerLatitude':
                      _convertToDouble(data['passengerLatitude']),
                  'passengerLongitude':
                      _convertToDouble(data['passengerLongitude']),
                  'passengerLocationTimestamp':
                      data['passengerLocationTimestamp'],
                };

                // Debug logging for passenger location
                final passengerLat =
                    _convertToDouble(data['passengerLatitude']);
                final passengerLng =
                    _convertToDouble(data['passengerLongitude']);
                print(
                    '🗺️ ConductorMaps: Booking ${doc.id} - Passenger location: ($passengerLat, $passengerLng)');

                return booking;
              }).toList();

              // Get boarded passengers from conductor data
              _loadConductorPassengerCount().then((boardedPassengers) {
                if (mounted) {
                  setState(() {
                    passengerCount = totalPassengers + boardedPassengers;
                    print(
                        '🗺️ ConductorMaps: Active bookings loaded: ${_activeBookings.length}, Pre-booked passengers: $totalPassengers, Boarded passengers: $boardedPassengers, Total passengers: $passengerCount');
                  });
                }
              });
            });
          }
        });
      }
    });
  }

  Future<int> _loadConductorPassengerCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    
    try {
      final query = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        final conductorData = query.docs.first.data();
        return conductorData['passengerCount'] ?? 0;
      }
    } catch (e) {
      print('Error loading conductor passenger count: $e');
    }
    return 0;
  }

  // Note: Passengers are automatically removed from the map when their QR code is scanned
  // and their status is updated to 'boarded' in Firebase. No manual removal needed.

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = {};

    print(
        '🗺️ ConductorMaps: Building markers for ${_activeBookings.length} bookings and ${_routeDestinations.length} destinations');

    // Add conductor's current location marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: MarkerId('conductor'),
          position:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: InfoWindow(
            title: 'Conductor Location',
            snippet: 'Route: ${widget.route} - Passengers: $passengerCount',
          ),
          icon: _getSmallCircularMarker(Colors.blue),
        ),
      );
      print(
          '🗺️ ConductorMaps: Added conductor marker at (${_currentPosition!.latitude}, ${_currentPosition!.longitude})');
    }

    // Add route markers
    final routeMarkers = _createRouteMarkers();
    markers.addAll(routeMarkers);
    print('🗺️ ConductorMaps: Added ${routeMarkers.length} route markers');

    // Add passenger markers (only if they have coordinates)
    for (int i = 0; i < _activeBookings.length; i++) {
      final booking = _activeBookings[i];

      final passengerLat = booking['passengerLatitude'] ?? 0.0;
      final passengerLng = booking['passengerLongitude'] ?? 0.0;

      print(
          '🗺️ ConductorMaps: Booking ${booking['id']} - Passenger location: ($passengerLat, $passengerLng)');

      // Only show passenger marker if they have valid coordinates
      if (passengerLat != 0.0 && passengerLng != 0.0) {
        markers.add(
          Marker(
            markerId: MarkerId('passenger_${booking['id']}'),
            position: LatLng(passengerLat, passengerLng),
            infoWindow: InfoWindow(
              title: 'Pre-booked Passenger',
              snippet:
                  '${booking['from']} → ${booking['to']} (${booking['quantity']} passengers) - Scan QR to board',
            ),
            icon: _getHumanIcon(),
          ),
        );
        print(
            '🗺️ ConductorMaps: ✅ Added passenger marker for booking ${booking['id']} at ($passengerLat, $passengerLng)');
      } else {
        print(
            '🗺️ ConductorMaps: ❌ No passenger location available for booking ${booking['id']}');
      }
    }

    print('🗺️ ConductorMaps: Total markers created: ${markers.length}');
    return markers;
  }

  // Create route markers based on the conductor's assigned route from Firestore
  Set<Marker> _createRouteMarkers() {
    final Set<Marker> markers = {};
    
    print('🗺️ ConductorMaps: Creating route markers from ${_routeDestinations.length} destinations');

    // Use the route destinations loaded from Firestore
    for (final destination in _routeDestinations) {
      final name = destination['name'] ?? 'Unknown';
      final km = destination['km'] ?? 0.0;
      final latitude = destination['latitude'] ?? 0.0;
      final longitude = destination['longitude'] ?? 0.0;
      final direction = destination['direction'] ?? 'unknown';

      print('🗺️ ConductorMaps: Processing destination: $name - lat: $latitude, lng: $longitude, km: $km, direction: $direction');

      if (latitude != 0.0 && longitude != 0.0) {
        final markerId = 'route_${name}_$direction';

        markers.add(
          Marker(
            markerId: MarkerId(markerId),
            position: LatLng(latitude, longitude),
            infoWindow: InfoWindow(
              title: name,
              snippet: '${km} km - ${widget.route} Route (${direction})',
            ),
            icon: _getCircularMarkerIcon(),
          ),
        );
        print('🗺️ ConductorMaps: ✅ Added route marker for $name at ($latitude, $longitude)');
      } else {
        print('🗺️ ConductorMaps: ❌ Skipping $name - invalid coordinates: ($latitude, $longitude)');
      }
    }

    print(
        '🗺️ ConductorMaps: Created ${markers.length} ${widget.route} route markers from Firestore');
    return markers;
  }

  void _showDebugDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Debug Route ID'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Route: ${widget.route}'),
              SizedBox(height: 16),
              Text('Route ID (Document ID): ${widget.route}'),
              SizedBox(height: 16),
              Text('Destinations Loaded: ${_routeDestinations.length}'),
              if (_routeDestinations.isNotEmpty) ...[
                SizedBox(height: 8),
                Text('Sample destinations:'),
              ],
              if (_routeDestinations.isNotEmpty)
                ..._routeDestinations.take(3).map((dest) => 
                  Text('• ${dest['name']} at (${dest['latitude']}, ${dest['longitude']})')
                ).toList(),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Refresh'),
              onPressed: () {
                Navigator.of(context).pop();
                _loadRouteDestinations();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "Maps",
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Color(0xFF0091AD),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          // Debug button to test route ID
          IconButton(
            icon: Icon(Icons.bug_report),
            onPressed: () => _showDebugDialog(),
            tooltip: 'Debug Route ID',
          ),
        ],
      ),
      body: _isLoading || _currentPosition == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    _isLoading
                        ? 'Getting location...'
                        : 'Location not available',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _getCurrentLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0091AD),
                      foregroundColor: Colors.white,
                    ),
                    child: Text('Get Location'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                GoogleMap(
                  key: const ValueKey('conductor_map'),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                  },
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    zoom: 15.0,
                  ),
                  markers: _buildMarkers(),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: false,
                ),

                // Passenger count and route info overlay
                Positioned(
                  top: 16,
                  left: 16,
                  right: 120,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$passengerCount passengers',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0091AD),
                          ),
                        ),
                        Text(
                          '${_activeBookings.length} bookings',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_routeDestinations.isNotEmpty) ...[
                          SizedBox(height: 4),
                          Text(
                            'Route: ${widget.route}',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            'Range: ${DestinationService.getRouteRange(_routeDestinations)['firstKm']}-${DestinationService.getRouteRange(_routeDestinations)['lastKm']} km',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
