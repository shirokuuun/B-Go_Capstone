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
  int _passengerCount = 0;
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
      if (_currentPosition != null) {
        _checkPassengerDropoffs();
      }
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
          final passengerCount = conductorData['passengerCount'] ?? 0;
          if (mounted) {
            setState(() {
              _passengerCount = passengerCount;
            });
          }
        }
      });
    }
  }

  StreamSubscription<QuerySnapshot>? _bookingsSubscription;

  void _loadRouteDestinations() async {
    try {
      final destinations = await DestinationService.fetchRouteDestinations(widget.route);
      if (mounted) {
        setState(() {
          _routeDestinations = destinations;
        });
        
        // Get route range for display
        final routeRange = DestinationService.getRouteRange(destinations);
        print('🗺️ ConductorMaps: Route ${widget.route} range: ${routeRange['firstKm']}-${routeRange['lastKm']} km');
        print('🗺️ ConductorMaps: Loaded ${destinations.length} destinations');
        
        // Debug: Print all destinations
        for (final dest in destinations) {
          print('🗺️ Destination: ${dest['name']} at (${dest['latitude']}, ${dest['longitude']}) - ${dest['direction']} route');
        }
      }
    } catch (e) {
      print('Error loading route destinations: $e');
    }
  }

  void _loadBookings() {
    print('🗺️ ConductorMaps: Starting to load bookings for route: ${widget.route}');
    
    // Cancel existing subscription if any
    _bookingsSubscription?.cancel();
    
    _bookingsSubscription = FirebaseFirestore.instance
        .collectionGroup('preBookings')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final allPreBookings = snapshot.docs;
        print('🗺️ ConductorMaps: Total pre-bookings found: ${allPreBookings.length}');
        
        final preBookings = allPreBookings
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final matchesRoute = data['route'] == widget.route;
              final isPaid = data['status'] == 'paid';
              final isPending = data['status'] == 'pending_payment';
              print('🗺️ ConductorMaps: Booking ${doc.id} - Route: ${data['route']} (matches: $matchesRoute), Status: ${data['status']} (paid: $isPaid, pending: $isPending)');
              return matchesRoute && (isPaid || isPending); // Show both paid and pending bookings for testing
            })
            .toList();

        print('🗺️ ConductorMaps: Filtered bookings for route ${widget.route}: ${preBookings.length}');

        // Use post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              // Don't override passenger count here - it's managed by conductor data
              // _passengerCount is already set by _loadConductorData()
              
              _activeBookings = preBookings.map((doc) {
                 final data = doc.data() as Map<String, dynamic>;
                 final booking = {
                   'id': doc.id,
                   'from': data['from'],
                   'to': data['to'],
                   'quantity': data['quantity'],
                   'fromLatitude': _convertToDouble(data['fromLatitude']),
                   'fromLongitude': _convertToDouble(data['fromLongitude']),
                   'toLatitude': _convertToDouble(data['toLatitude']),
                   'toLongitude': _convertToDouble(data['toLongitude']),
                   // Add passenger current location
                   'passengerLatitude': _convertToDouble(data['passengerLatitude']),
                   'passengerLongitude': _convertToDouble(data['passengerLongitude']),
                   'passengerLocationTimestamp': data['passengerLocationTimestamp'],
                 };
                
                // Debug logging for passenger location
                final passengerLat = _convertToDouble(data['passengerLatitude']);
                final passengerLng = _convertToDouble(data['passengerLongitude']);
                print('🗺️ ConductorMaps: Booking ${doc.id} - Passenger location: ($passengerLat, $passengerLng)');
                
                return booking;
              }).toList();
              
              print('🗺️ ConductorMaps: Active bookings loaded: ${_activeBookings.length}');
            });
          }
        });
      }
    });
  }

  void _checkPassengerDropoffs() {
    if (_currentPosition == null) return;
    
    for (int i = _activeBookings.length - 1; i >= 0; i--) {
      final booking = _activeBookings[i];
      final toLat = booking['toLatitude'] ?? 0.0;
      final toLng = booking['toLongitude'] ?? 0.0;
      
      if (toLat != 0.0 && toLng != 0.0) {
        final distance = RouteService.calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          toLat,
          toLng,
        );
        
        // If conductor is within 200 meters of drop-off location
        if (distance <= 0.2) {
          _dropOffPassenger(booking);
        }
      }
    }
  }

  void _dropOffPassenger(Map<String, dynamic> booking) async {
    final quantity = (booking['quantity'] ?? 1) as int;
    
    setState(() {
      _passengerCount -= quantity;
      _activeBookings.remove(booking);
    });
    
    // Update passenger count in Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final conductorDoc = await FirebaseFirestore.instance
            .collection('conductors')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();
        
        if (conductorDoc.docs.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('conductors')
              .doc(conductorDoc.docs.first.id)
              .update({
                'passengerCount': FieldValue.increment(-quantity)
              });
        }
      } catch (e) {
        print('Error updating passenger count: $e');
      }
    }
    
    // Show notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$quantity passenger${quantity > 1 ? 's' : ''} dropped off at ${booking['to']}'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final Set<Marker> markers = {};
    
    print('🗺️ ConductorMaps: Building markers for ${_activeBookings.length} bookings and ${_routeDestinations.length} destinations');
    
    // Add conductor's current location marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: MarkerId('conductor'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: InfoWindow(
            title: 'Conductor Location',
            snippet: 'Route: ${widget.route} - Passengers: $_passengerCount',
          ),
                     icon: _getSmallCircularMarker(Colors.blue),
        ),
      );
      print('🗺️ ConductorMaps: Added conductor marker at (${_currentPosition!.latitude}, ${_currentPosition!.longitude})');
    }

    // Add route markers
    final routeMarkers = _createRouteMarkers();
    markers.addAll(routeMarkers);
    print('🗺️ ConductorMaps: Added ${routeMarkers.length} route markers');

    // Add passenger markers
    for (int i = 0; i < _activeBookings.length; i++) {
      final booking = _activeBookings[i];
      
      final fromLat = booking['fromLatitude'] ?? 0.0;
      final fromLng = booking['fromLongitude'] ?? 0.0;
      final toLat = booking['toLatitude'] ?? 0.0;
      final toLng = booking['toLongitude'] ?? 0.0;
      final passengerLat = booking['passengerLatitude'] ?? 0.0;
      final passengerLng = booking['passengerLongitude'] ?? 0.0;
      
      print('🗺️ ConductorMaps: Booking ${booking['id']} - Passenger location: ($passengerLat, $passengerLng)');
      
      // Passenger current location marker (if available)
      if (passengerLat != 0.0 && passengerLng != 0.0) {
        markers.add(
          Marker(
            markerId: MarkerId('passenger_${booking['id']}'),
            position: LatLng(passengerLat, passengerLng),
            infoWindow: InfoWindow(
              title: 'Passenger Location',
              snippet: '${booking['from']} → ${booking['to']} (${booking['quantity']} passengers)',
            ),
                         icon: _getSmallCircularMarker(Colors.yellow),
          ),
        );
        print('🗺️ ConductorMaps: ✅ Added passenger marker for booking ${booking['id']} at ($passengerLat, $passengerLng)');
      } else {
        print('🗺️ ConductorMaps: ❌ No passenger location available for booking ${booking['id']}');
      }
      
      // Pick-up location marker
      if (fromLat != 0.0 && fromLng != 0.0) {
        markers.add(
          Marker(
            markerId: MarkerId('pickup_${booking['id']}'),
            position: LatLng(fromLat, fromLng),
            infoWindow: InfoWindow(
              title: 'Pick-up Location',
              snippet: '${booking['from']} → ${booking['to']} (${booking['quantity']} passengers)',
            ),
                         icon: _getSmallCircularMarker(Colors.green),
          ),
        );
      }
      
      // Drop-off location marker
      if (toLat != 0.0 && toLng != 0.0) {
        markers.add(
          Marker(
            markerId: MarkerId('dropoff_${booking['id']}'),
            position: LatLng(toLat, toLng),
            infoWindow: InfoWindow(
              title: 'Drop-off Location',
              snippet: '${booking['to']} (${booking['quantity']} passengers)',
            ),
                         icon: _getSmallCircularMarker(Colors.red),
          ),
        );
      }
    }
    
    print('🗺️ ConductorMaps: Total markers created: ${markers.length}');
    return markers;
  }

  // Create route markers based on the conductor's assigned route from Firestore
  Set<Marker> _createRouteMarkers() {
    final Set<Marker> markers = {};
    
    // Use the route destinations loaded from Firestore
    for (final destination in _routeDestinations) {
      final name = destination['name'] ?? 'Unknown';
      final km = destination['km'] ?? 0.0;
      final latitude = destination['latitude'] ?? 0.0;
      final longitude = destination['longitude'] ?? 0.0;
      final direction = destination['direction'] ?? 'unknown';
      
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
      }
    }
    
    print('🗺️ ConductorMaps: Created ${markers.length} ${widget.route} route markers from Firestore');
    return markers;
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
                    _isLoading ? 'Getting location...' : 'Location not available',
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
                          '$_passengerCount passengers',
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
