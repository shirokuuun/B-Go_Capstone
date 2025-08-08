import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class ConductorMaps extends StatefulWidget {
  final String route;
  final String role;

  const ConductorMaps({super.key, required this.route, required this.role});

  @override
  State<ConductorMaps> createState() => _ConductorMapsState();
}

class _ConductorMapsState extends State<ConductorMaps> {
  // Map related variables
  GoogleMapController? _mapController;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
      _updateMapCamera();
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  void _updateMapCamera() {
    if (_mapController != null && _currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      );
    }
  }

  Set<Marker> _buildMarkers(List<QueryDocumentSnapshot> preBookings) {
    final Set<Marker> markers = {};
    
    // Add conductor's current location marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          markerId: MarkerId('conductor'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: InfoWindow(
            title: 'Conductor Location',
            snippet: 'Route: ${widget.route}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    // Add passenger markers (simulated locations for demo)
    for (int i = 0; i < preBookings.length; i++) {
      final data = preBookings[i].data() as Map<String, dynamic>;
      
      // For demo purposes, create simulated locations around the conductor
      // In a real app, you'd get actual passenger locations
      double latOffset = (i + 1) * 0.001; // Small offset for demo
      double lngOffset = (i + 1) * 0.001;
      
      if (_currentPosition != null) {
        markers.add(
          Marker(
            markerId: MarkerId('passenger_${preBookings[i].id}'),
            position: LatLng(
              _currentPosition!.latitude + latOffset,
              _currentPosition!.longitude + lngOffset,
            ),
            infoWindow: InfoWindow(
              title: 'Pre-booked Passenger',
              snippet: '${data['from']} → ${data['to']} (${data['quantity']} passengers)',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        );
      }
    }
    
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
      body: Column(
        children: [
          // Map Container
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collectionGroup('preBookings')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading pre-bookings: ${snapshot.error}',
                      style: GoogleFonts.outfit(color: Colors.red),
                    ),
                  );
                }

                final allPreBookings = snapshot.data?.docs ?? [];
                
                // Filter in memory to avoid index requirements
                final preBookings = allPreBookings
                    .where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['route'] == widget.route && data['status'] == 'paid';
                    })
                    .toList();

                // Build markers
                final markers = _buildMarkers(preBookings);

                                 return Stack(
                   children: [
                     // Map
                     _currentPosition == null
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
                                  'Getting location...',
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
                        : GoogleMap(
                            onMapCreated: (GoogleMapController controller) {
                              _mapController = controller;
                              _updateMapCamera();
                            },
                            initialCameraPosition: CameraPosition(
                              target: LatLng(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              ),
                              zoom: 15.0,
                            ),
                            markers: markers,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            zoomControlsEnabled: true,
                            mapToolbarEnabled: false,
                          ),
                    
                                         // Passenger count overlay
                     Positioned(
                       top: 16,
                       left: 16,
                       right: 120, // Prevent overlap with legend
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
                         child: Text(
                           '${preBookings.length} pre-booked passenger${preBookings.length == 1 ? '' : 's'}',
                           style: GoogleFonts.outfit(
                             fontSize: 12,
                             fontWeight: FontWeight.w600,
                             color: Color(0xFF0091AD),
                           ),
                           overflow: TextOverflow.ellipsis,
                         ),
                       ),
                     ),
                     
                     // Legend overlay
                     Positioned(
                       top: 16,
                       right: 16,
                       child: Container(
                         padding: EdgeInsets.all(12),
                         decoration: BoxDecoration(
                           color: Colors.white,
                           borderRadius: BorderRadius.circular(8),
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
                               'Legend',
                               style: GoogleFonts.outfit(
                                 fontSize: 14,
                                 fontWeight: FontWeight.bold,
                               ),
                             ),
                             SizedBox(height: 8),
                             Row(
                               children: [
                                 Icon(Icons.location_on, color: Color(0xFF0091AD), size: 20),
                                 SizedBox(width: 8),
                                 Text(
                                   'Your Location',
                                   style: GoogleFonts.outfit(fontSize: 12),
                                 ),
                               ],
                             ),
                             SizedBox(height: 4),
                             Row(
                               children: [
                                 Icon(Icons.location_on, color: Colors.green, size: 20),
                                 SizedBox(width: 8),
                                 Text(
                                   'Pre-booked Passengers',
                                   style: GoogleFonts.outfit(fontSize: 12),
                                 ),
                               ],
                             ),
                           ],
                         ),
                       ),
                     ),
                   ],
                 );
               },
             ),
           ),
         ],
       ),
     );
   }
 }
