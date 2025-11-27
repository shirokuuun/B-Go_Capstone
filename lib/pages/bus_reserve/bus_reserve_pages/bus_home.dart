import 'package:b_go/pages/bus_reserve/bus_reserve_pages/user_reservations.dart';
import 'package:b_go/pages/user_role/user_selection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/bus_reserve/reservation_service.dart';
import 'package:responsive_framework/responsive_framework.dart';

class BusHome extends StatefulWidget {
  const BusHome({super.key});

  @override
  State<BusHome> createState() => _BusHomeState();
}

class _BusHomeState extends State<BusHome> {
  List<Map<String, dynamic>> _availableBuses = [];
  String? _selectedBusId;
  String? _selectedWeekday;
  String _availabilityFilter = 'all';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fetchConductorBuses();
    ReservationService.updateExpiredReservations();
  }

  Future<void> _fetchConductorBuses() async {
    final buses = await ReservationService.getAllConductorsAsBuses();
    setState(() {
      _availableBuses = buses;
    });
  }

  DateTime _getDateFromWeekday(String weekday) {
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final targetWeekday = weekdays.indexOf(weekday) + 1;

    final today = DateTime.now();
    final currentWeekday = today.weekday;

    int daysUntilTarget = (targetWeekday - currentWeekday) % 7;
    if (daysUntilTarget == 0) {
      daysUntilTarget = 7;
    }

    return today.add(Duration(days: daysUntilTarget));
  }

  List<Map<String, dynamic>> _getFilteredBuses() {
    List<Map<String, dynamic>> filtered = List.from(_availableBuses);

    if (_selectedWeekday != null) {
      final selectedDate = _getDateFromWeekday(_selectedWeekday!);
      filtered = filtered.where((bus) {
        final plateNumber = bus['plateNumber'] as String? ?? '';
        return ReservationService.isBusAvailableForReservation(
            plateNumber, selectedDate);
      }).toList();
    }

    if (_availabilityFilter != 'all') {
      filtered = filtered.where((bus) {
        final conductor = bus['conductorData'] as Map<String, dynamic>?;

        if (conductor == null) {
          return _availabilityFilter == 'available';
        }

        final busAvailabilityStatus =
            ReservationService.getBusAvailabilityStatus(conductor);

        if (_availabilityFilter == 'available') {
          return busAvailabilityStatus == 'available';
        } else if (_availabilityFilter == 'unavailable') {
          return busAvailabilityStatus == 'unavailable' ||
              busAvailabilityStatus == 'pending';
        } else if (_availabilityFilter == 'reserved') {
          return busAvailabilityStatus == 'reserved';
        }

        return true;
      }).toList();
    }

    return filtered;
  }

  void _showBusDetails(Map<String, dynamic> bus) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final conductor = bus['conductorData'] as Map<String, dynamic>?;
    final busAvailabilityStatus = conductor != null
        ? ReservationService.getBusAvailabilityStatus(conductor)
        : 'available';

    // Check if bus is available for reservation
    final plateNumber = bus['plateNumber'] as String? ?? '';
    bool isAvailable = busAvailabilityStatus == 'available';

    if (_selectedWeekday != null && isAvailable) {
      final selectedDate = _getDateFromWeekday(_selectedWeekday!);
      isAvailable = ReservationService.isBusAvailableForReservation(
          plateNumber, selectedDate);
    }

    // Get status display
    Color statusColor;
    String statusText;

    if (busAvailabilityStatus == 'pending') {
      statusColor = Colors.orange;
      statusText = 'Pending Payment';
    } else if (busAvailabilityStatus == 'reserved') {
      statusColor = Colors.blue;
      statusText = 'Reserved (Verified)';
    } else if (busAvailabilityStatus == 'unavailable') {
      statusColor = Colors.red;
      statusText = 'Unavailable';
    } else {
      statusColor = Colors.green;
      statusText = 'Available';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_bus,
                      color: Color(0xFF0091AD),
                      size: isMobile ? 24 : 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Bus Details',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile
                            ? 20
                            : isTablet
                                ? 22
                                : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, size: isMobile ? 24 : 28),
                      onPressed: () => Navigator.pop(context),
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1),

              // Content
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Bus Image
                        if (conductor?['busImageUrl'] != null)
                          Container(
                            margin: EdgeInsets.only(bottom: 20),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                conductor!['busImageUrl'],
                                width: double.infinity,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 200,
                                    color: Colors.grey.shade200,
                                    child: Center(
                                      child: Icon(
                                        Icons.directions_bus,
                                        size: 80,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                        // Bus Information
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(0xFF0091AD).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              _buildDetailRow(
                                'Bus Number',
                                'Bus #${conductor?['busNumber']?.toString() ?? bus['busNumber']?.toString() ?? 'N/A'}',
                                isMobile,
                                isTablet,
                              ),
                              SizedBox(height: 12),
                              _buildDetailRow(
                                'Plate Number',
                                conductor?['plateNumber'] ??
                                    bus['plateNumber'] ??
                                    'N/A',
                                isMobile,
                                isTablet,
                              ),
                              SizedBox(height: 12),
                              _buildDetailRow(
                                'Route',
                                conductor?['route'] ?? bus['route'] ?? 'N/A',
                                isMobile,
                                isTablet,
                              ),
                              SizedBox(height: 12),
                              _buildDetailRow(
                                'Driver',
                                conductor?['driverName'] ?? 'Unknown',
                                isMobile,
                                isTablet,
                              ),
                              SizedBox(height: 12),
                              _buildDetailRow(
                                'Conductor',
                                conductor?['name'] ?? 'Unknown',
                                isMobile,
                                isTablet,
                              ),
                              SizedBox(height: 12),
                              _buildDetailRow(
                                'Available Days',
                                List<String>.from(bus['codingDays'] ?? [])
                                    .join(', '),
                                isMobile,
                                isTablet,
                              ),
                              SizedBox(height: 12),
                              _buildDetailRow(
                                'Price',
                                '₱${bus['Price']}',
                                isMobile,
                                isTablet,
                              ),
                              SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Status',
                                    style: GoogleFonts.outfit(
                                      fontSize: isMobile
                                          ? 14
                                          : isTablet
                                              ? 16
                                              : 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: statusColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: GoogleFonts.outfit(
                                        fontSize: isMobile
                                            ? 12
                                            : isTablet
                                                ? 14
                                                : 16,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 20),

                        // Continue Button
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(0xFF0091AD).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Color(0xFF0091AD).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Color(0xFF0091AD),
                                size: isMobile ? 20 : 24,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'To make a reservation, please go back and use the calendar to select your preferred date first.',
                                  style: GoogleFonts.outfit(
                                    fontSize: isMobile ? 14 : 16,
                                    color: Color(0xFF0091AD),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
      String label, String value, bool isMobile, bool isTablet) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: isMobile
                  ? 14
                  : isTablet
                      ? 16
                      : 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: isMobile
                  ? 14
                  : isTablet
                      ? 16
                      : 18,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _availabilityFilter == value;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    return GestureDetector(
      onTap: () {
        setState(() {
          _availabilityFilter = value;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 12, vertical: isMobile ? 5 : 6),
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

  Widget _buildConductorInfo(Map<String, dynamic> bus) {
    final conductor = bus['conductorData'] as Map<String, dynamic>?;
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    if (conductor == null || conductor.isEmpty) {
      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Status: ',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            TextSpan(
              text: 'No conductor data',
              style: GoogleFonts.outfit(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    final busAvailabilityStatus =
        ReservationService.getBusAvailabilityStatus(conductor);

    Color statusColor;
    String statusText;

    if (busAvailabilityStatus == 'pending') {
      statusColor = Colors.orange;
      statusText = 'Pending Payment';
    } else if (busAvailabilityStatus == 'reserved') {
      statusColor = Colors.blue;
      statusText = 'Reserved (Verified)';
    } else if (busAvailabilityStatus == 'unavailable') {
      statusColor = Colors.red;
      statusText = 'Unavailable';
    } else {
      statusColor = Colors.green;
      statusText = 'Available';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Driver: ',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextSpan(
                text: conductor['driverName'] ?? 'Unknown',
                style: GoogleFonts.outfit(
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Route: ',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextSpan(
                text: conductor['route'] ?? bus['route'] ?? 'N/A',
                style: GoogleFonts.outfit(
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Status: ',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextSpan(
                text: statusText,
                style: GoogleFonts.outfit(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _selectWeekday() {
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      color: Color(0xFF0091AD),
                      size: isMobile ? 24 : 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Filter by Day',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile
                            ? 20
                            : isTablet
                                ? 22
                                : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, size: isMobile ? 24 : 28),
                      onPressed: () => Navigator.pop(context),
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedWeekday = null;
                          });
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: _selectedWeekday == null
                                ? Color(0xFF0091AD).withOpacity(0.1)
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: isMobile ? 20 : 24,
                                height: isMobile ? 20 : 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _selectedWeekday == null
                                        ? Color(0xFF0091AD)
                                        : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                  color: _selectedWeekday == null
                                      ? Color(0xFF0091AD)
                                      : Colors.transparent,
                                ),
                                child: _selectedWeekday == null
                                    ? Center(
                                        child: Container(
                                          width: isMobile ? 8 : 10,
                                          height: isMobile ? 8 : 10,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              SizedBox(width: 16),
                              Text(
                                'Show All Days',
                                style: GoogleFonts.outfit(
                                  fontSize: isMobile
                                      ? 16
                                      : isTablet
                                          ? 18
                                          : 20,
                                  fontWeight: _selectedWeekday == null
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: _selectedWeekday == null
                                      ? Color(0xFF0091AD)
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ...weekdays
                          .map((weekday) => InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedWeekday = weekday;
                                  });
                                  Navigator.of(context).pop();
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: _selectedWeekday == weekday
                                        ? Color(0xFF0091AD).withOpacity(0.1)
                                        : Colors.transparent,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey.shade200,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: isMobile ? 20 : 24,
                                        height: isMobile ? 20 : 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _selectedWeekday == weekday
                                                ? Color(0xFF0091AD)
                                                : Colors.grey.shade400,
                                            width: 2,
                                          ),
                                          color: _selectedWeekday == weekday
                                              ? Color(0xFF0091AD)
                                              : Colors.transparent,
                                        ),
                                        child: _selectedWeekday == weekday
                                            ? Center(
                                                child: Container(
                                                  width: isMobile ? 8 : 10,
                                                  height: isMobile ? 8 : 10,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              )
                                            : null,
                                      ),
                                      SizedBox(width: 16),
                                      Text(
                                        weekday,
                                        style: GoogleFonts.outfit(
                                          fontSize: isMobile
                                              ? 16
                                              : isTablet
                                                  ? 18
                                                  : 20,
                                          fontWeight:
                                              _selectedWeekday == weekday
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                          color: _selectedWeekday == weekday
                                              ? Color(0xFF0091AD)
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ))
                          .toList(),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

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
    final titleFontSize = isMobile
        ? 25.0
        : isTablet
            ? 28.0
            : 32.0;
    final busListingsFontSize = isMobile
        ? 24.0
        : isTablet
            ? 28.0
            : 32.0;
    final busNameFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final expandedHeight = isMobile
        ? 70.0
        : isTablet
            ? 80.0
            : 90.0;
    final horizontalPadding = isMobile
        ? 16.0
        : isTablet
            ? 20.0
            : 24.0;
    final verticalPadding = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;
    final containerPadding = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;
    final marginSpacing = isMobile
        ? 6.0
        : isTablet
            ? 8.0
            : 10.0;
    final horizontalMargin = isMobile
        ? 10.0
        : isTablet
            ? 12.0
            : 16.0;

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
                Navigator.pushNamed(context, '/bus_home');
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UserReservations()),
                );
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
                'BATRASCO',
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
                  icon: const Icon(Icons.schedule, color: Colors.white),
                  onPressed: _selectWeekday,
                ),
              ),
            ],
          ),
          SliverAppBar(
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF0091AD),
            pinned: true,
            expandedHeight: expandedHeight,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007A8F),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'Bus Listings',
                        style: GoogleFonts.outfit(
                          fontSize: busListingsFontSize,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(containerPadding),
              child: Column(
                children: [
                  if (_selectedWeekday != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              "Filtering by: $_selectedWeekday",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: isMobile ? 12 : 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Clear Filter',
                          onPressed: () {
                            setState(() {
                              _selectedWeekday = null;
                            });
                          },
                        )
                      ],
                    ),
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Filter:',
                          style: GoogleFonts.outfit(
                            fontSize: isMobile
                                ? 14
                                : isTablet
                                    ? 16
                                    : 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip('All', 'all'),
                                SizedBox(width: 8),
                                _buildFilterChip('Available', 'available'),
                                SizedBox(width: 8),
                                _buildFilterChip('Unavailable', 'unavailable'),
                                SizedBox(width: 8),
                                _buildFilterChip('Reserved', 'reserved'),
                                SizedBox(width: 8),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _getFilteredBuses().isEmpty
              ? const SliverFillRemaining(
                  child: Center(child: Text("No buses available.")),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final bus = _getFilteredBuses()[index];
                      final plateNumber = bus['plateNumber'] as String? ?? '';
                      final conductor =
                          bus['conductorData'] as Map<String, dynamic>?;
                      final busAvailabilityStatus = conductor != null
                          ? ReservationService.getBusAvailabilityStatus(
                              conductor)
                          : 'available';

                      bool isGrayedOut = false;

                      if (busAvailabilityStatus == 'reserved' ||
                          busAvailabilityStatus == 'pending' ||
                          busAvailabilityStatus == 'unavailable') {
                        isGrayedOut = true;
                      } else if (_selectedWeekday != null) {
                        final selectedDate =
                            _getDateFromWeekday(_selectedWeekday!);
                        final isAvailableOnSelectedDay =
                            ReservationService.isBusAvailableForReservation(
                                plateNumber, selectedDate);
                        isGrayedOut = !isAvailableOnSelectedDay;
                      }

                      return GestureDetector(
                        onTap: () => _showBusDetails(bus),
                        child: Container(
                          margin: EdgeInsets.symmetric(
                              vertical: marginSpacing,
                              horizontal: horizontalMargin),
                          padding: EdgeInsets.all(containerPadding),
                          decoration: BoxDecoration(
                            color: isGrayedOut
                                ? Colors.grey.shade100
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            border: Border.all(
                              color: isGrayedOut
                                  ? Colors.grey.shade400
                                  : const Color(0xFF0091AD).withOpacity(0.7),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Bus #${conductor?['busNumber']?.toString() ?? bus['busNumber']?.toString() ?? 'N/A'}',
                                      style: GoogleFonts.outfit(
                                        fontSize: busNameFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: isGrayedOut
                                            ? Colors.grey.shade600
                                            : Color(0xFF0091AD),
                                      ),
                                      overflow: TextOverflow.visible,
                                      maxLines: 2,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: isGrayedOut
                                        ? Colors.grey.shade500
                                        : Color(0xFF0091AD),
                                  ),
                                ],
                              ),
                              SizedBox(height: isMobile ? 12 : 16),
                              Padding(
                                padding:
                                    EdgeInsets.only(left: isMobile ? 0 : 8),
                                child: _buildConductorInfo(bus),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _getFilteredBuses().length,
                  ),
                ),
        ],
      ),
    );
  }
}
