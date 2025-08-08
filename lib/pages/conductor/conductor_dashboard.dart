import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConductorDashboard extends StatefulWidget {
  final String route;
  final String role;

  const ConductorDashboard({super.key, required this.route, required this.role});

  @override
  State<ConductorDashboard> createState() => _ConductorDashboardState();
}

class _ConductorDashboardState extends State<ConductorDashboard> {
  final LocationService _locationService = LocationService();
  bool _isTracking = false;
  String _statusMessage = 'Location tracking is off';

  @override
  void initState() {
    super.initState();
    _checkTrackingState();
  }

  Future<void> _checkTrackingState() async {
    try {
      // Check the actual database state instead of local state
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final query = await FirebaseFirestore.instance
            .collection('conductors')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          final isOnlineInDatabase = data['isOnline'] ?? false;
          
          setState(() {
            _isTracking = isOnlineInDatabase;
          });
        }
      }
      _updateStatusMessage();
    } catch (e) {
      print('Error checking tracking state: $e');
      setState(() {
        _isTracking = false;
      });
      _updateStatusMessage();
    }
  }

  void _updateStatusMessage() {
    setState(() {
      _statusMessage = _isTracking 
          ? 'Location tracking is active - Passengers can see your bus on the map'
          : 'Location tracking is off - Passengers cannot see your bus';
    });
  }

  Future<void> _toggleLocationTracking() async {
    try {
      if (_isTracking) {
        await _locationService.stopLocationTracking();
        setState(() {
          _isTracking = false;
        });
        _showSnackBar('Location tracking stopped', Colors.orange);
      } else {
        // Show loading indicator
        _showSnackBar('Starting location tracking...', Colors.blue);
        
        await _locationService.startLocationTracking();
        setState(() {
          _isTracking = true;
        });
        _showSnackBar('Location tracking started successfully!', Colors.green);
      }
      _updateStatusMessage();
    } catch (e) {
      // If there's an error, check the actual database state
      await _checkTrackingState();
      
      String errorMessage = 'Error starting location tracking';
      if (e.toString().contains('Location services are disabled')) {
        errorMessage = 'Please enable GPS/Location services in your device settings';
      } else if (e.toString().contains('Location permission denied')) {
        errorMessage = 'Please enable location access in app settings';
      } else if (e.toString().contains('permanently denied')) {
        errorMessage = 'Location access is permanently denied. Please enable it in device settings';
      } else if (e.toString().contains('MissingPluginException')) {
        errorMessage = 'Location service not available. Please restart the app';
      }
      
      _showSnackBar(errorMessage, Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildPreBookedPassengersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('preBookings')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text(
            'Error loading pre-bookings: ${snapshot.error}',
            style: GoogleFonts.outfit(color: Colors.red),
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

        if (preBookings.isEmpty) {
          return Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 48,
                  color: Colors.grey[400],
                ),
                SizedBox(height: 8),
                Text(
                  'No pre-booked passengers yet',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  'Passengers with paid pre-bookings will appear here',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Text(
              '${preBookings.length} pre-booked passenger${preBookings.length == 1 ? '' : 's'}',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12),
            ...preBookings.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person,
                        color: Colors.green[700],
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${data['from']} → ${data['to']}',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${data['quantity']} passenger${data['quantity'] == 1 ? '' : 's'} • ${data['amount']?.toStringAsFixed(2) ?? '0.00'} PHP',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'PAID',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
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
          "Dashboard",
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Color(0xFF0091AD),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
             body: SingleChildScrollView(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
            // Welcome Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${widget.role}!',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Route: ${widget.route}',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Location Tracking Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: _isTracking ? Colors.green : Colors.grey,
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Location Tracking',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      _statusMessage,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: _isTracking ? Colors.green : Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _toggleLocationTracking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isTracking ? Colors.red : Color(0xFF0091AD),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                            SizedBox(width: 8),
                            Text(
                              _isTracking ? 'Stop Tracking' : 'Start Tracking',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
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
            SizedBox(height: 20),

            // Pre-booked Passengers Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.people, color: Color(0xFF0091AD)),
                        SizedBox(width: 8),
                        Text(
                          'Pre-booked Passengers',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildPreBookedPassengersList(),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Instructions Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF0091AD)),
                        SizedBox(width: 8),
                        Text(
                          'Instructions',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                                         Text(
                       '• Start location tracking when you begin your route\n'
                       '• Stop tracking when you end your shift\n'
                       '• Passengers will see your bus location in real-time\n'
                       '• Your location updates every 10 meters or 30 seconds\n'
                       '• Check pre-booked passengers below for guaranteed seats\n'
                       '• Use the Maps tab to see passenger locations',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
