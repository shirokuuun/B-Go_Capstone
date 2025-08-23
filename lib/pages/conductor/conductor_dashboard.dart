import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:responsive_framework/responsive_framework.dart';

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
  String _conductorName = '';

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
          final conductorName = data['name'] ?? '';

          setState(() {
            _isTracking = isOnlineInDatabase;
            _conductorName = conductorName;
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
              return data['route'] == widget.route && 
                     data['status'] == 'paid' && 
                     data['boardingStatus'] != 'boarded';
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

  Widget _buildScannedQRDataList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Text('User not authenticated', style: GoogleFonts.outfit(color: Colors.red));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .snapshots(),
      builder: (context, conductorSnapshot) {
        if (conductorSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (conductorSnapshot.hasError || conductorSnapshot.data?.docs.isEmpty == true) {
          return Text(
            'Error loading conductor data',
            style: GoogleFonts.outfit(color: Colors.red),
          );
        }

        final conductorDocId = conductorSnapshot.data!.docs.first.id;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('conductors')
              .doc(conductorDocId)
              .collection('preBookings')
              .where('qr', isEqualTo: true)
              .snapshots(),
          builder: (context, qrSnapshot) {
            if (qrSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (qrSnapshot.hasError) {
              return Text(
                'Error loading scanned QR data: ${qrSnapshot.error}',
                style: GoogleFonts.outfit(color: Colors.red),
              );
            }

            final scannedQRs = qrSnapshot.data?.docs ?? [];

            if (scannedQRs.isEmpty) {
              return Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No scanned QR codes yet',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Scanned pre-bookings will appear here',
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
                  '${scannedQRs.length} scanned QR code${scannedQRs.length == 1 ? '' : 's'}',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 12),
                ...scannedQRs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final qrData = data['data'] as Map<String, dynamic>? ?? {};
                  final scannedAt = data['scannedAt'] as Timestamp?;
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.qr_code_scanner,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${qrData['from'] ?? 'Unknown'} → ${qrData['to'] ?? 'Unknown'}',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${qrData['quantity'] ?? 1} passenger${(qrData['quantity'] ?? 1) == 1 ? '' : 's'} • ${qrData['amount']?.toStringAsFixed(2) ?? '0.00'} PHP',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (scannedAt != null)
                                Text(
                                  'Scanned: ${scannedAt.toDate().toString().substring(0, 19)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'BOARDED',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final isDesktop = ResponsiveBreakpoints.of(context).isDesktop;
    
    // Responsive sizing
    final titleFontSize = isMobile ? 20.0 : isTablet ? 22.0 : 24.0;
    final welcomeFontSize = isMobile ? 24.0 : isTablet ? 28.0 : 32.0;
    final routeFontSize = isMobile ? 18.0 : isTablet ? 20.0 : 22.0;
    final cardTitleFontSize = isMobile ? 20.0 : isTablet ? 22.0 : 24.0;
    final bodyFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final smallFontSize = isMobile ? 12.0 : isTablet ? 14.0 : 16.0;
    final buttonFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final resetButtonFontSize = isMobile ? 14.0 : isTablet ? 16.0 : 18.0;
    final instructionsFontSize = isMobile ? 14.0 : isTablet ? 16.0 : 18.0;
    final iconSize = isMobile ? 24.0 : isTablet ? 28.0 : 32.0;
    final bodyPadding = isMobile ? 16.0 : isTablet ? 20.0 : 24.0;
    final cardPadding = isMobile ? 16.0 : isTablet ? 20.0 : 24.0;
    final spacing = isMobile ? 20.0 : isTablet ? 24.0 : 28.0;
    final smallSpacing = isMobile ? 8.0 : isTablet ? 10.0 : 12.0;
    final mediumSpacing = isMobile ? 12.0 : isTablet ? 16.0 : 20.0;
    
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "Dashboard",
          style: GoogleFonts.outfit(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Color(0xFF0091AD),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(bodyPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${_conductorName.isNotEmpty ? _conductorName : "Conductor"}!',
                      style: GoogleFonts.outfit(
                        fontSize: welcomeFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: smallSpacing),
                    Text(
                      'Route: ${widget.route}',
                      style: GoogleFonts.outfit(
                        fontSize: routeFontSize,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing),

            // Passenger Count Section
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.people, color: Color(0xFF0091AD), size: iconSize),
                        SizedBox(width: smallSpacing),
                        Text(
                          'Passenger Count',
                          style: GoogleFonts.outfit(
                            fontSize: cardTitleFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: mediumSpacing),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('conductors')
                          .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                          .limit(1)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Text(
                            'Error loading passenger count: ${snapshot.error}',
                            style: GoogleFonts.outfit(color: Colors.red, fontSize: bodyFontSize),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Text(
                            'No conductor data found',
                            style: GoogleFonts.outfit(color: Colors.grey, fontSize: bodyFontSize),
                          );
                        }

                        final conductorData = docs.first.data() as Map<String, dynamic>;
                        final boardedPassengers = conductorData['passengerCount'] ?? 0;
                        
                        // Get pre-booked passengers count
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collectionGroup('preBookings')
                              .snapshots(),
                          builder: (context, preBookingSnapshot) {
                            int preBookedPassengers = 0;
                            
                            if (preBookingSnapshot.hasData) {
                              final allPreBookings = preBookingSnapshot.data!.docs;
                                                             preBookedPassengers = allPreBookings
                                   .where((doc) {
                                     final data = doc.data() as Map<String, dynamic>;
                                     return data['route'] == widget.route && 
                                            (data['status'] == 'paid' || data['status'] == 'pending_payment') &&
                                            data['boardingStatus'] != 'boarded';
                                   })
                                   .fold<int>(0, (sum, doc) {
                                     final data = doc.data() as Map<String, dynamic>;
                                     return sum + ((data['quantity'] as int?) ?? 1);
                                   });
                            }
                            
                            final totalPassengers = boardedPassengers + preBookedPassengers;
                            final maxCapacity = 27;
                            final percentage = (totalPassengers / maxCapacity) * 100;

                            return Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Current Passengers:',
                                      style: GoogleFonts.outfit(
                                        fontSize: bodyFontSize,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '$totalPassengers/$maxCapacity',
                                      style: GoogleFonts.outfit(
                                        fontSize: bodyFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: totalPassengers >= maxCapacity ? Colors.red : Color(0xFF0091AD),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: smallSpacing),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Boarded: $boardedPassengers',
                                      style: GoogleFonts.outfit(
                                        fontSize: smallFontSize,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      'Pre-booked: $preBookedPassengers',
                                      style: GoogleFonts.outfit(
                                        fontSize: smallFontSize,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: smallSpacing),
                                LinearProgressIndicator(
                                  value: percentage / 100,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    totalPassengers >= maxCapacity ? Colors.red : Color(0xFF0091AD),
                                  ),
                                ),
                                SizedBox(height: smallSpacing),
                                Text(
                                  '${percentage.toStringAsFixed(1)}% capacity used',
                                  style: GoogleFonts.outfit(
                                    fontSize: smallFontSize,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (totalPassengers >= maxCapacity) ...[
                                  SizedBox(height: smallSpacing),
                                  Container(
                                    padding: EdgeInsets.all(smallSpacing),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red[200]!),
                                    ),
                                    child: Text(
                                      'Bus is at full capacity!',
                                      style: GoogleFonts.outfit(
                                        fontSize: smallFontSize,
                                        color: Colors.red[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                                SizedBox(height: mediumSpacing),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: boardedPassengers > 0 ? () async {
                                          // Reset passenger count
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
                                                      'passengerCount': 0
                                                    });
                                                
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Passenger count reset to 0'),
                                                    backgroundColor: Colors.green,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error resetting passenger count: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        } : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          'Reset Count',
                                          style: GoogleFonts.outfit(
                                            fontSize: resetButtonFontSize,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing),

            // Location Tracking Section
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: _isTracking ? Colors.green : Colors.grey,
                          size: iconSize,
                        ),
                        SizedBox(width: smallSpacing),
                        Text(
                          'Location Tracking',
                          style: GoogleFonts.outfit(
                            fontSize: cardTitleFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: mediumSpacing),
                    Text(
                      _statusMessage,
                      style: GoogleFonts.outfit(
                        fontSize: bodyFontSize,
                        color: _isTracking ? Colors.green : Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: mediumSpacing),
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
                            SizedBox(width: smallSpacing),
                            Text(
                              _isTracking ? 'Stop Tracking' : 'Start Tracking',
                              style: GoogleFonts.outfit(
                                fontSize: buttonFontSize,
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
            SizedBox(height: spacing),

            // Pre-booked Passengers Card
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.people, color: Color(0xFF0091AD), size: iconSize),
                        SizedBox(width: smallSpacing),
                        Text(
                          'Pre-booked Passengers',
                          style: GoogleFonts.outfit(
                            fontSize: cardTitleFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: mediumSpacing),
                    _buildPreBookedPassengersList(),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing),

            // Scanned QR Data Card
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.qr_code_scanner, color: Color(0xFF0091AD), size: iconSize),
                        SizedBox(width: smallSpacing),
                        Text(
                          'Scanned QR Codes',
                          style: GoogleFonts.outfit(
                            fontSize: cardTitleFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: mediumSpacing),
                    _buildScannedQRDataList(),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing),

            // Instructions Card
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF0091AD), size: iconSize),
                        SizedBox(width: smallSpacing),
                        Text(
                          'Instructions',
                          style: GoogleFonts.outfit(
                            fontSize: cardTitleFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: mediumSpacing),
                    Text(
                      '• Start location tracking when you begin your route\n'
                      '• Stop tracking when you end your shift\n'
                      '• Passengers will see your bus location in real-time\n'
                      '• Your location updates every 10 meters or 30 seconds\n'
                      '• Check pre-booked passengers below for guaranteed seats\n'
                      '• Use the Maps tab to see passenger locations',
                      style: GoogleFonts.outfit(
                        fontSize: instructionsFontSize,
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
