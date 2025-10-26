import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'dart:math' as math;

class ConductorDashboard extends StatefulWidget {
  final String route;
  final String role;

  const ConductorDashboard(
      {super.key, required this.route, required this.role});

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
        _showCustomSnackBar('Location tracking stopped', 'warning');
      } else {
        // Show loading indicator
        _showCustomSnackBar('Starting location tracking...', 'info');

        await _locationService.startLocationTracking();

        setState(() {
          _isTracking = true;
        });
        _showCustomSnackBar(
            'Location tracking started successfully!', 'success');
      }
      _updateStatusMessage();
    } catch (e) {
      // If there's an error, check the actual database state
      await _checkTrackingState();

      String errorMessage = 'Error starting location tracking';
      if (e.toString().contains('Location services are disabled')) {
        errorMessage =
            'Please enable GPS/Location services in your device settings';
      } else if (e.toString().contains('Location permission denied')) {
        errorMessage = 'Please enable location access in app settings';
      } else if (e.toString().contains('permanently denied')) {
        errorMessage =
            'Location access is permanently denied. Please enable it in device settings';
      } else if (e.toString().contains('MissingPluginException')) {
        errorMessage = 'Location service not available. Please restart the app';
      }

      _showCustomSnackBar(errorMessage, 'error');
    }
  }

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
      case 'info':
        backgroundColor = Colors.blue;
        icon = Icons.info;
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
        duration: Duration(seconds: 2),
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

  void _showManualPassengerAdjustmentDialog(
      BuildContext context, int currentPassengerCount) {
    final TextEditingController quantityController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Manual Passenger Count Adjustment',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current passenger count: $currentPassengerCount',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0091AD),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'How many passengers should be subtracted?',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Enter number of passengers',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.people),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Reason for adjustment (optional):',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g., Geofencing failed, manual drop-off, etc.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.note),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange[700], size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This action will be logged for audit purposes',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final quantity = int.tryParse(quantityController.text);
                if (quantity == null || quantity <= 0) {
                  _showCustomSnackBar(
                    'Please enter a valid number',
                    'error',
                  );
                  return;
                }

                if (quantity > currentPassengerCount) {
                  _showCustomSnackBar(
                    'Cannot subtract more passengers than current count',
                    'error',
                  );
                  return;
                }

                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) return;

                  final query = await FirebaseFirestore.instance
                      .collection('conductors')
                      .where('uid', isEqualTo: user.uid)
                      .limit(1)
                      .get();

                  if (query.docs.isEmpty) return;

                  final conductorDocId = query.docs.first.id;
                  final now = DateTime.now();
                  final formattedDate =
                      "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

                  // Update passenger count
                  await FirebaseFirestore.instance
                      .collection('conductors')
                      .doc(conductorDocId)
                      .collection('dailyTrips')
                      .doc(formattedDate)
                      .update({
                    'passengerCount': FieldValue.increment(-quantity),
                  });

                  // Log the manual adjustment
                  await FirebaseFirestore.instance
                      .collection('conductors')
                      .doc(conductorDocId)
                      .collection('dailyTrips')
                      .doc(formattedDate)
                      .collection('adjustmentLogs')
                      .add({
                    'timestamp': FieldValue.serverTimestamp(),
                    'quantity': quantity,
                    'reason': reasonController.text.trim().isEmpty
                        ? 'No reason provided'
                        : reasonController.text.trim(),
                    'conductorName': _conductorName,
                    'previousCount': currentPassengerCount,
                    'newCount': currentPassengerCount - quantity,
                  });

                  if (mounted) {
                    Navigator.of(context).pop();
                    _showCustomSnackBar(
                      'Passenger count adjusted successfully',
                      'success',
                    );
                  }
                } catch (e) {
                  print('Error adjusting passenger count: $e');
                  _showCustomSnackBar(
                    'Failed to adjust passenger count',
                    'error',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0091AD),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Confirm',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _adjustPassengerCount(int quantity, String reason) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showCustomSnackBar('User not authenticated', 'error');
        return;
      }

      // Get conductor document
      final conductorDoc = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (conductorDoc.docs.isEmpty) {
        _showCustomSnackBar('Conductor data not found', 'error');
        return;
      }

      final conductorId = conductorDoc.docs.first.id;
      final currentCount =
          conductorDoc.docs.first.data()['passengerCount'] ?? 0;
      final newCount = math.max<int>(0, currentCount - quantity);

      // Update passenger count (critical operation)
      await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .update({
        'passengerCount': newCount,
        'lastManualAdjustment': {
          'timestamp': FieldValue.serverTimestamp(),
          'quantity': quantity,
          'reason': reason.isNotEmpty ? reason : 'Manual adjustment',
          'previousCount': currentCount,
          'newCount': newCount,
        },
      });

      // Log the adjustment in a separate collection for audit purposes (non-critical)
      try {
        await FirebaseFirestore.instance
            .collection('conductors')
            .doc(conductorId)
            .collection('passengerAdjustments')
            .add({
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'manual_subtraction',
          'quantity': quantity,
          'reason': reason.isNotEmpty ? reason : 'Manual adjustment',
          'previousCount': currentCount,
          'newCount': newCount,
          'route': widget.route,
          'conductorId': conductorId,
        });
        print('✅ Audit log successfully created');
      } catch (auditError) {
        // Log audit error but don't fail the main operation
        print('⚠️ Failed to create audit log (non-critical): $auditError');
        // You could optionally show a warning to the user here
      }

      _showCustomSnackBar(
          'Successfully adjusted passenger count: $currentCount → $newCount (-$quantity)',
          'success');

      // Refresh the UI
      setState(() {});
    } catch (e) {
      _showCustomSnackBar('Error adjusting passenger count: $e', 'error');
      print('Error adjusting passenger count: $e');
    }
  }

  Widget _buildPreBookedPassengersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .limit(1)
          .snapshots(),
      builder: (context, conductorSnapshot) {
        if (conductorSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (conductorSnapshot.hasError) {
          return Text(
            'Error loading conductor data: ${conductorSnapshot.error}',
            style: GoogleFonts.outfit(color: Colors.red),
          );
        }

        final conductorDocs = conductorSnapshot.data?.docs ?? [];
        if (conductorDocs.isEmpty) {
          return Text(
            'No conductor data found',
            style: GoogleFonts.outfit(color: Colors.grey),
          );
        }

        final conductorData =
            conductorDocs.first.data() as Map<String, dynamic>;
        final conductorDocId = conductorDocs.first.id;
        final activeTripId = conductorData['activeTrip']?['tripId'];

        // ✅ FIX: Only show pre-bookings if there's an active trip
        if (activeTripId == null) {
          return Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                SizedBox(height: 8),
                Text(
                  'No active trip',
                  style:
                      GoogleFonts.outfit(fontSize: 16, color: Colors.grey[600]),
                ),
                Text(
                  'Start a trip to see pre-booked passengers',
                  style:
                      GoogleFonts.outfit(fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('conductors')
              .doc(conductorDocId)
              .collection('preBookings')
              .snapshots(), // ✅ Get all, filter in memory
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

            // ✅ CRITICAL: Filter by active trip AND not completed
            final preBookings = allPreBookings.where((doc) {
              final data = doc.data() as Map<String, dynamic>;

              // Must be for current trip
              final isForCurrentTrip = data['tripId'] == activeTripId;

              // Must not be completed
              final notCompleted = data['tripCompleted'] != true;

              // Only show pre-bookings that are paid but NOT scanned yet
              return data['route'] == widget.route &&
                  data['status'] == 'paid' &&
                  data['boardingStatus'] != 'boarded' &&
                  data['scannedBy'] == null &&
                  isForCurrentTrip &&
                  notCompleted; // ✅ NEW: Don't show completed trips
            }).toList();

            if (preBookings.isEmpty) {
              return Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.people_outline,
                        size: 48, color: Colors.grey[400]),
                    SizedBox(height: 8),
                    Text(
                      'No pre-booked passengers yet',
                      style: GoogleFonts.outfit(
                          fontSize: 16, color: Colors.grey[600]),
                    ),
                    Text(
                      'Passengers with paid pre-bookings will appear here',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: Colors.grey[500]),
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
                          child: Icon(Icons.person,
                              color: Colors.green[700], size: 20),
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
                                '${data['quantity']} passenger${data['quantity'] == 1 ? '' : 's'} • ${data['totalFare']?.toString() ?? '0.00'} PHP',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      },
    );
  }

  Widget _buildScannedQRDataList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Text('User not authenticated',
          style: GoogleFonts.outfit(color: Colors.red));
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

        if (conductorSnapshot.hasError ||
            conductorSnapshot.data?.docs.isEmpty == true) {
          return Text(
            'Error loading conductor data',
            style: GoogleFonts.outfit(color: Colors.red),
          );
        }

        final conductorDocId = conductorSnapshot.data!.docs.first.id;
        final conductorData =
            conductorSnapshot.data!.docs.first.data() as Map<String, dynamic>;
        final activeTripId =
            conductorData['activeTrip']?['tripId']; // ✅ GET ACTIVE TRIP

        // ✅ FIX: Only show scanned QR codes if there's an active trip
        if (activeTripId == null) {
          return _buildEmptyScannedQRState();
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('conductors')
              .doc(conductorDocId)
              .collection('scannedQRCodes')
              .snapshots(), // ✅ REMOVED orderBy to avoid index error
          builder: (context, qrSnapshot) {
            if (qrSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (qrSnapshot.hasError) {
              print('Error loading scanned QR codes: ${qrSnapshot.error}');
              // ✅ SHOW ERROR instead of infinite loading
              return Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: Colors.orange[400]),
                    SizedBox(height: 8),
                    Text(
                      'Unable to load scanned QR codes',
                      style: GoogleFonts.outfit(
                          fontSize: 16, color: Colors.orange[600]),
                    ),
                    Text(
                      'Please create the required Firebase index',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            // ✅ FILTER by active trip and sort in memory
            var scannedQRs = (qrSnapshot.data?.docs ?? []).where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['tripId'] == activeTripId &&
                  data['tripCompleted'] != true;
            }).toList();

            // ✅ SORT in memory (since we removed orderBy)
            scannedQRs.sort((a, b) {
              final aTime =
                  (a.data() as Map<String, dynamic>)['scannedAt'] as Timestamp?;
              final bTime =
                  (b.data() as Map<String, dynamic>)['scannedAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime); // Descending
            });

            if (scannedQRs.isEmpty) {
              return _buildEmptyScannedQRState();
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
                ..._mapDocsToScannedTiles(scannedQRs),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyScannedQRState() {
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

  List<Widget> _mapDocsToScannedTiles(List<QueryDocumentSnapshot> docs) {
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final scannedAt = data['scannedAt'] as Timestamp?;

      // Support both scannedQRCodes and preBookings document structures
      final from = data['from'] ?? data['data']?['from'] ?? 'Unknown';
      final to = data['to'] ?? data['data']?['to'] ?? 'Unknown';
      final qty = (data['quantity'] as num?)?.toInt() ??
          (data['data']?['quantity'] as num?)?.toInt() ??
          1;

      // Handle different fare field names
      double amount = 0.0;
      final totalFareStr = data['totalFare'] ?? data['data']?['totalFare'];
      if (totalFareStr is String) {
        amount = double.tryParse(totalFareStr) ?? 0.0;
      } else if (totalFareStr is num) {
        amount = totalFareStr.toDouble();
      } else {
        // Try other possible amount fields
        final amountStr =
            data['data']?['amount'] ?? data['data']?['totalAmount'];
        if (amountStr != null) {
          if (amountStr is String) {
            amount = double.tryParse(amountStr) ?? 0.0;
          } else if (amountStr is num) {
            amount = amountStr.toDouble();
          }
        }
      }

      // Get status from data
      final status = data['status'] ?? 'boarded';
      final isAccomplished = status == 'accomplished';

      return Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAccomplished ? Colors.green[50] : Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isAccomplished ? Colors.green[200]! : Colors.blue[200]!),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isAccomplished ? Colors.green[100] : Colors.blue[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAccomplished ? Icons.check_circle : Icons.qr_code_scanner,
                color: isAccomplished ? Colors.green[700] : Colors.blue[700],
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$from → $to',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$qty passenger${qty == 1 ? '' : 's'} • ${amount.toStringAsFixed(2)} PHP',
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
                color: isAccomplished ? Colors.green[100] : Colors.blue[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isAccomplished ? 'ACCOMPLISHED' : 'BOARDED',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isAccomplished ? Colors.green[700] : Colors.blue[700],
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
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
    final welcomeFontSize = isMobile
        ? 24.0
        : isTablet
            ? 28.0
            : 32.0;
    final routeFontSize = isMobile
        ? 18.0
        : isTablet
            ? 20.0
            : 22.0;
    final cardTitleFontSize = isMobile
        ? 20.0
        : isTablet
            ? 22.0
            : 24.0;
    final bodyFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final smallFontSize = isMobile
        ? 12.0
        : isTablet
            ? 14.0
            : 16.0;
    final buttonFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final resetButtonFontSize = isMobile
        ? 14.0
        : isTablet
            ? 16.0
            : 18.0;
    final instructionsFontSize = isMobile
        ? 14.0
        : isTablet
            ? 16.0
            : 18.0;
    final iconSize = isMobile
        ? 24.0
        : isTablet
            ? 28.0
            : 32.0;
    final bodyPadding = isMobile
        ? 16.0
        : isTablet
            ? 20.0
            : 24.0;
    final cardPadding = isMobile
        ? 16.0
        : isTablet
            ? 20.0
            : 24.0;
    final spacing = isMobile
        ? 20.0
        : isTablet
            ? 24.0
            : 28.0;
    final smallSpacing = isMobile
        ? 8.0
        : isTablet
            ? 10.0
            : 12.0;
    final mediumSpacing = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;

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
                        Icon(Icons.people,
                            color: Color(0xFF0091AD), size: iconSize),
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
                          .where('uid',
                              isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                          .limit(1)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Text(
                            'Error loading passenger count: ${snapshot.error}',
                            style: GoogleFonts.outfit(
                                color: Colors.red, fontSize: bodyFontSize),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Text(
                            'No conductor data found',
                            style: GoogleFonts.outfit(
                                color: Colors.grey, fontSize: bodyFontSize),
                          );
                        }

                        final conductorData =
                            docs.first.data() as Map<String, dynamic>;
                        final conductorDocId = docs.first.id;
                        final boardedPassengers =
                            conductorData['passengerCount'] ?? 0;

                        // Get pre-booked passengers count
                        final activeTripId =
                            conductorData['activeTrip']?['tripId'];
                        return StreamBuilder<QuerySnapshot>(
                          stream: activeTripId != null
                              ? FirebaseFirestore.instance
                                  .collection('conductors')
                                  .doc(conductorDocId)
                                  .collection('preBookings')
                                  .where('tripId', isEqualTo: activeTripId)
                                  .where('tripCompleted', isEqualTo: false)
                                  .snapshots()
                              : FirebaseFirestore.instance
                                  .collection('conductors')
                                  .doc(conductorDocId)
                                  .collection('preBookings')
                                  .where('tripCompleted', isEqualTo: false)
                                  .snapshots(),
                          builder: (context, preBookingSnapshot) {
                            int preBookedPassengers = 0;

                            if (preBookingSnapshot.hasData) {
                              final allPreBookings =
                                  preBookingSnapshot.data!.docs;
                              for (var doc in allPreBookings) {
                                final data = doc.data() as Map<String, dynamic>;
                                final isForCurrentTrip = activeTripId == null ||
                                    data['tripId'] == activeTripId ||
                                    data['tripId'] == null;

                                // FIXED: Only count pre-bookings that are NOT yet boarded/scanned
                                // Boarded/scanned pre-bookings are already in passengerCount
                                if (data['route'] == widget.route &&
                                    isForCurrentTrip &&
                                    data['status'] == 'paid' &&
                                    data['boardingStatus'] != 'boarded' &&
                                    data['scannedBy'] == null) {
                                  // NOT scanned yet
                                  final qty = (data['quantity'] as int?) ?? 1;
                                  preBookedPassengers += qty;
                                }
                              }
                            }

                            // Get additional scanned pre-bookings from scannedQRCodes collection
                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('conductors')
                                  .doc(conductorDocId)
                                  .collection('scannedQRCodes')
                                  .where('type', isEqualTo: 'preBooking')
                                  .where('tripCompleted', isEqualTo: false)
                                  .snapshots(),
                              builder: (context, scannedSnapshot) {
                                // REMOVED: scannedPreBookedPassengers calculation
                                // Scanned pre-bookings are already in passengerCount

                                // passengerCount already includes all boarded passengers (regular + pre-booked)
                                final totalBoardedPassengers =
                                    boardedPassengers;

                                // Total capacity = boarded + waiting pre-bookings
                                final totalPassengers = totalBoardedPassengers +
                                    preBookedPassengers;
                                final maxCapacity = 27;
                                final percentage =
                                    (totalPassengers / maxCapacity) * 100;

                                return Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
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
                                            color:
                                                totalPassengers >= maxCapacity
                                                    ? Colors.red
                                                    : Color(0xFF0091AD),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: smallSpacing),
                                    // Color-coded breakdown
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Boarded passengers (light blue)
                                        Row(
                                          children: [
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: Colors.lightBlue[400],
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'Boarded: $totalBoardedPassengers',
                                              style: GoogleFonts.outfit(
                                                fontSize: smallFontSize,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Pre-booked not boarded (orange)
                                        if (preBookedPassengers > 0)
                                          Row(
                                            children: [
                                              Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: Colors.orange[400],
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Pre-booked: $preBookedPassengers',
                                                style: GoogleFonts.outfit(
                                                  fontSize: smallFontSize,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: smallSpacing),
                                    // Custom progress bar with two colors
                                    Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        children: [
                                          // Boarded passengers (light blue)
                                          if (totalBoardedPassengers > 0)
                                            Expanded(
                                              flex: totalBoardedPassengers,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.lightBlue[400],
                                                  borderRadius:
                                                      BorderRadius.only(
                                                    topLeft: Radius.circular(4),
                                                    bottomLeft:
                                                        Radius.circular(4),
                                                    topRight:
                                                        preBookedPassengers == 0
                                                            ? Radius.circular(4)
                                                            : Radius.zero,
                                                    bottomRight:
                                                        preBookedPassengers == 0
                                                            ? Radius.circular(4)
                                                            : Radius.zero,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          // Pre-booked not boarded (orange)
                                          if (preBookedPassengers > 0)
                                            Expanded(
                                              flex: preBookedPassengers,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.orange[400],
                                                  borderRadius:
                                                      BorderRadius.only(
                                                    topRight:
                                                        Radius.circular(4),
                                                    bottomRight:
                                                        Radius.circular(4),
                                                    topLeft:
                                                        totalBoardedPassengers ==
                                                                0
                                                            ? Radius.circular(4)
                                                            : Radius.zero,
                                                    bottomLeft:
                                                        totalBoardedPassengers ==
                                                                0
                                                            ? Radius.circular(4)
                                                            : Radius.zero,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          // Remaining capacity (gray)
                                          if (totalPassengers < maxCapacity)
                                            Expanded(
                                              flex: (maxCapacity -
                                                      totalPassengers)
                                                  .clamp(1, maxCapacity)
                                                  .toInt(),
                                              child: Container(
                                                color: Colors.grey[300],
                                                child: SizedBox.shrink(),
                                              ),
                                            ),
                                        ],
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
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.red[200]!),
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
                                            onPressed:
                                                totalBoardedPassengers > 0
                                                    ? () async {
                                                        // Show manual passenger count adjustment dialog
                                                        _showManualPassengerAdjustmentDialog(
                                                            context,
                                                            totalBoardedPassengers);
                                                      }
                                                    : null,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text(
                                              'Adjust Count',
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
                          backgroundColor:
                              _isTracking ? Colors.red : Color(0xFF0091AD),
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
                        Icon(Icons.people,
                            color: Color(0xFF0091AD), size: iconSize),
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
                        Icon(Icons.qr_code_scanner,
                            color: Color(0xFF0091AD), size: iconSize),
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
                        Icon(Icons.info_outline,
                            color: Color(0xFF0091AD), size: iconSize),
                        SizedBox(width: smallSpacing),
                        Text(
                          'Instructions',
                          style: GoogleFonts.outfit(
                            fontSize: cardTitleFontSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: mediumSpacing),
                    Text(
                      '• Start location tracking when you begin your route\n'
                      '• Stop tracking when you end your shift\n'
                      '• Passengers will see your bus location in real-time\n'
                      '• Your location updates every 5 seconds\n'
                      '• Check pre-booked passengers for guaranteed seats\n'
                      '• Use the Maps tab to see passenger locations\n'
                      '• Geofence radius: 250 meters for accurate passenger drop-off detection\n'
                      '• If geofencing fails, use "Adjust Count" to manually subtract dropped-off passengers\n'
                      '• Manual adjustments are logged for audit purposes',
                      style: GoogleFonts.outfit(
                        fontSize: instructionsFontSize,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: spacing),
          ],
        ),
      ),
    );
  }
}
