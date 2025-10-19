import 'package:b_go/pages/bus_reserve/bus_reserve_pages/bus_home.dart';
import 'package:b_go/pages/bus_reserve/bus_reserve_pages/payment_view_page.dart';
import 'package:b_go/pages/bus_reserve/reservation_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:b_go/pages/user_role/user_selection.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserReservations extends StatefulWidget {
  const UserReservations({Key? key}) : super(key: key);

  @override
  State<UserReservations> createState() => _UserReservationsState();
}

class _UserReservationsState extends State<UserReservations> {
  List<Map<String, dynamic>> _userReservations = [];
  bool _isLoading = true;
  String _statusFilter = 'all';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fetchUserReservations();
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

  Future<void> _fetchUserReservations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        setState(() {
          _isLoading = false;
        });
        _showCustomSnackBar('Please log in to view your reservations', 'error');
        return;
      }

      final reservations =
          await ReservationService.getUserReservationsByEmail(user.email!);
      setState(() {
        _userReservations = reservations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showCustomSnackBar('Error loading reservations: $e', 'error');
    }
  }

  Future<void> _deleteReservation(String reservationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId)
          .delete();

      _showCustomSnackBar('Reservation deleted successfully', 'success');

      // Refresh the list
      await _fetchUserReservations();
    } catch (e) {
      _showCustomSnackBar('Error deleting reservation: $e', 'error');
    }
  }

  Future<List<String>> _getConductorNames(List<String> conductorIds) async {
    try {
      final conductors = await ReservationService.getAllConductors();
      final conductorNames = <String>[];

      for (String conductorId in conductorIds) {
        final conductor = conductors.firstWhere(
          (c) => c['id'] == conductorId,
          orElse: () => <String, dynamic>{},
        );

        if (conductor.isNotEmpty) {
          conductorNames.add(conductor['name'] ?? 'Unknown Conductor');
        } else {
          conductorNames.add('Unknown Conductor');
        }
      }

      return conductorNames;
    } catch (e) {
      print('Error fetching conductor names: $e');
      return conductorIds.map((id) => 'Unknown Conductor').toList();
    }
  }

  List<Map<String, dynamic>> _getFilteredReservations() {
    if (_statusFilter == 'all') {
      return _userReservations;
    }
    return _userReservations.where((reservation) {
      return reservation['status'] == _statusFilter;
    }).toList();
  }

  Widget _buildStatusChip(String status) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    Color statusColor;
    String statusText;

    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Pending Payment';
        break;
      case 'receipt_uploaded':
        statusColor = Colors.blue;
        statusText = 'Receipt Uploaded';
        break;
      case 'confirmed':
        statusColor = Colors.green;
        statusText = 'Confirmed';
        break;
      case 'completed':
        statusColor = Colors.purple;
        statusText = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Text(
        statusText,
        style: GoogleFonts.outfit(
          fontSize: isMobile
              ? 10
              : isTablet
                  ? 11
                  : 12,
          fontWeight: FontWeight.w600,
          color: statusColor,
        ),
      ),
    );
  }

  Widget _buildReservationCard(Map<String, dynamic> reservation) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    final reservationId = reservation['id'] ?? 'Unknown';
    final from = reservation['from'] ?? 'Unknown';
    final to = reservation['to'] ?? 'Unknown';
    final isRoundTrip = reservation['isRoundTrip'] ?? false;
    final fullName = reservation['fullName'] ?? 'Unknown';
    final email = reservation['email'] ?? 'Unknown';
    final status = reservation['status'] ?? 'unknown';
    final timestamp = reservation['timestamp'] as Timestamp?;
    final selectedBusIds =
        List<String>.from(reservation['selectedBusIds'] ?? []);
    final receiptUrl = reservation['receiptUrl'] as String?;

    final formattedDate = timestamp != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(timestamp.toDate())
        : 'Unknown date';

    // Check if status allows deletion (completed or cancelled)
    final canDelete = status == 'completed' || status == 'cancelled';

    Widget cardContent = GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentViewPage(
                reservationId: reservationId,
                selectedBusIds: selectedBusIds,
                reservationDetails: reservation,
                status: status,
              ),
            ),
          );
        },
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: status == 'confirmed'
                  ? Colors.green.shade200
                  : status == 'completed'
                      ? Colors.purple.shade200
                      : status == 'pending'
                          ? Colors.orange.shade200
                          : status == 'cancelled'
                              ? Colors.red.shade200
                              : Colors.grey.shade200,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with reservation ID and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Reservation #${reservationId.split(' ').last}',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile
                            ? 14
                            : isTablet
                                ? 16
                                : 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0091AD),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _buildStatusChip(status),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 12),

              // Trip details
              Row(
                children: [
                  Icon(Icons.location_on,
                      size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$from → $to',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile
                            ? 14
                            : isTablet
                                ? 16
                                : 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (isRoundTrip)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Round Trip',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 10 : 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(height: 8),

              // Passenger info
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Text(
                    fullName,
                    style: GoogleFonts.outfit(
                      fontSize: isMobile
                          ? 12
                          : isTablet
                              ? 14
                              : 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 4),

              // Email
              Row(
                children: [
                  Icon(Icons.email, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      email,
                      style: GoogleFonts.outfit(
                        fontSize: isMobile
                            ? 12
                            : isTablet
                                ? 14
                                : 16,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 8),

              // Date and buses
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: GoogleFonts.outfit(
                      fontSize: isMobile
                          ? 12
                          : isTablet
                              ? 14
                              : 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 4),

              // Conductor names
              Row(
                children: [
                  Icon(Icons.directions_bus,
                      size: 16, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Expanded(
                    child: FutureBuilder<List<String>>(
                      future: _getConductorNames(selectedBusIds),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Text(
                            'Loading conductor info...',
                            style: GoogleFonts.outfit(
                              fontSize: isMobile
                                  ? 12
                                  : isTablet
                                      ? 14
                                      : 16,
                              color: Colors.grey.shade700,
                            ),
                          );
                        }

                        if (snapshot.hasError || !snapshot.hasData) {
                          return Text(
                            '${selectedBusIds.length} bus${selectedBusIds.length > 1 ? 'es' : ''} selected',
                            style: GoogleFonts.outfit(
                              fontSize: isMobile
                                  ? 12
                                  : isTablet
                                      ? 14
                                      : 16,
                              color: Colors.grey.shade700,
                            ),
                          );
                        }

                        final conductorNames = snapshot.data!;
                        return Text(
                          conductorNames.join(', '),
                          style: GoogleFonts.outfit(
                            fontSize: isMobile
                                ? 12
                                : isTablet
                                    ? 14
                                    : 16,
                            color: Colors.grey.shade700,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // Receipt image indicator - only show for receipt_uploaded and confirmed statuses
              if (receiptUrl != null &&
                  (status == 'receipt_uploaded' || status == 'confirmed')) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.receipt,
                          size: 16, color: Colors.blue.shade700),
                      SizedBox(width: 8),
                      Text(
                        'Receipt uploaded',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 12 : 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Status-specific messages
              if (status == 'pending') ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.orange.shade700),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please complete your payment and upload the receipt',
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 12 : 13,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (status == 'receipt_uploaded') ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 16, color: Colors.blue.shade700),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Payment receipt received. Waiting for admin verification',
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 12 : 13,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (status == 'confirmed') ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 16, color: Colors.green.shade700),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Reservation confirmed! Your bus is reserved',
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 12 : 13,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (status == 'completed') ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.flag_circle,
                          size: 16, color: Colors.purple.shade700),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Journey completed!',
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 12 : 13,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (status == 'cancelled') ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cancel, size: 16, color: Colors.red.shade700),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Reservation cancelled.',
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 12 : 13,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Clickable hint
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Tap to view details',
                    style: GoogleFonts.outfit(
                      fontSize: isMobile ? 10 : 11,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ));

    // Wrap with Dismissible if status is completed or cancelled
    if (canDelete) {
      return Dismissible(
        key: Key(reservationId),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 20),
          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete, color: Colors.white, size: 32),
              SizedBox(height: 4),
              Text(
                'Delete',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        confirmDismiss: (direction) async {
          return await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(
                  'Delete Reservation',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                content: Text(
                  'Are you sure you want to delete this reservation? This action cannot be undone.',
                  style: GoogleFonts.outfit(fontSize: 14),
                ),
                actions: [
                  TextButton(
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.outfit(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: Text(
                      'Delete',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              );
            },
          );
        },
        onDismissed: (direction) {
          _deleteReservation(reservationId);
        },
        child: cardContent,
      );
    }

    // Return card without Dismissible for other statuses
    return cardContent;
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    return GestureDetector(
      onTap: () {
        setState(() {
          _statusFilter = value;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF0091AD) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Color(0xFF0091AD) : Colors.grey.shade400,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: isMobile
                ? 12
                : isTablet
                    ? 14
                    : 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    final titleFontSize = isMobile
        ? 20.0
        : isTablet
            ? 24.0
            : 28.0;
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

    final filteredReservations = _getFilteredReservations();

    return Scaffold(
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
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => BusHome()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.directions_bus),
              title: Text(
                'Reserved Buses',
                style: GoogleFonts.outfit(
                  fontSize: drawerItemFontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
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
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: const Color(0xFF0091AD),
            leading: Padding(
              padding: EdgeInsets.only(top: 18.0, left: 8.0),
              child: IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ),
            title: Padding(
              padding: EdgeInsets.only(top: 22.0),
              child: Text(
                'My Reservations',
                style: GoogleFonts.outfit(
                  fontSize: titleFontSize,
                  color: Colors.white,
                ),
              ),
            ),
            centerTitle: true,
            actions: [
              Padding(
                padding: EdgeInsets.only(top: 18),
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _fetchUserReservations,
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Filter chips
                  Row(
                    children: [
                      Text(
                        'Filter:',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile
                              ? 16
                              : isTablet
                                  ? 18
                                  : 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('All', 'all'),
                              SizedBox(width: 8),
                              _buildFilterChip('Pending', 'pending'),
                              SizedBox(width: 8),
                              _buildFilterChip(
                                  'Receipt Uploaded', 'receipt_uploaded'),
                              SizedBox(width: 8),
                              _buildFilterChip('Confirmed', 'confirmed'),
                              SizedBox(width: 8),
                              _buildFilterChip('Completed', 'completed'),
                              SizedBox(width: 8),
                              _buildFilterChip('Cancelled', 'cancelled'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Loading or content
                  if (_isLoading)
                    Container(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF0091AD)),
                        ),
                      ),
                    )
                  else if (filteredReservations.isEmpty)
                    Container(
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.directions_bus_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            SizedBox(height: 16),
                            Text(
                              _statusFilter == 'all'
                                  ? 'No reservations found'
                                  : 'No ${_statusFilter == 'receipt_uploaded' ? 'uploaded receipt' : _statusFilter} reservations found',
                              style: GoogleFonts.outfit(
                                fontSize: isMobile
                                    ? 16
                                    : isTablet
                                        ? 18
                                        : 20,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Make a reservation to see it here',
                              style: GoogleFonts.outfit(
                                fontSize: isMobile
                                    ? 14
                                    : isTablet
                                        ? 16
                                        : 18,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        // Summary
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(0xFF0091AD).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Color(0xFF0091AD).withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              // First Row: Total and Cancelled
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          '${_userReservations.length}',
                                          style: GoogleFonts.outfit(
                                            fontSize: isMobile
                                                ? 20
                                                : isTablet
                                                    ? 24
                                                    : 28,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0091AD),
                                          ),
                                        ),
                                        Text(
                                          'Total',
                                          style: GoogleFonts.outfit(
                                            fontSize: isMobile
                                                ? 12
                                                : isTablet
                                                    ? 14
                                                    : 16,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          '${_userReservations.where((r) => r['status'] == 'cancelled').length}',
                                          style: GoogleFonts.outfit(
                                            fontSize: isMobile
                                                ? 20
                                                : isTablet
                                                    ? 24
                                                    : 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                        Text(
                                          'Cancelled',
                                          style: GoogleFonts.outfit(
                                            fontSize: isMobile
                                                ? 12
                                                : isTablet
                                                    ? 14
                                                    : 16,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              // Second Row: Confirmed and Completed
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          '${_userReservations.where((r) => r['status'] == 'confirmed').length}',
                                          style: GoogleFonts.outfit(
                                            fontSize: isMobile
                                                ? 20
                                                : isTablet
                                                    ? 24
                                                    : 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                        Text(
                                          'Confirmed',
                                          style: GoogleFonts.outfit(
                                            fontSize: isMobile
                                                ? 12
                                                : isTablet
                                                    ? 14
                                                    : 16,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          '${_userReservations.where((r) => r['status'] == 'completed').length}',
                                          style: GoogleFonts.outfit(
                                            fontSize: isMobile
                                                ? 20
                                                : isTablet
                                                    ? 24
                                                    : 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.purple.shade700,
                                          ),
                                        ),
                                        Text(
                                          'Completed',
                                          style: GoogleFonts.outfit(
                                            fontSize: isMobile
                                                ? 12
                                                : isTablet
                                                    ? 14
                                                    : 16,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 16),

                        // Reservations list
                        ...filteredReservations
                            .map((reservation) =>
                                _buildReservationCard(reservation))
                            .toList(),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
