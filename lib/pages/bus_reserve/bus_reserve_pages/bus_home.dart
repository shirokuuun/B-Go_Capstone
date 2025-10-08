import 'package:b_go/pages/bus_reserve/bus_reserve_pages/reservation_form.dart';
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
  Set<String> _selectedBusIds = {};
  String? _selectedWeekday; // 'Monday', 'Tuesday', etc. or null for all
  String _availabilityFilter = 'all'; // 'all', 'available', 'unavailable', 'reserved'
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fetchConductorBuses();
    // Update expired reservations when the page loads
    ReservationService.updateExpiredReservations();
  }

  Future<void> _fetchConductorBuses() async {
    // Fetch all conductors formatted as bus data
    final buses = await ReservationService.getAllConductorsAsBuses();
    setState(() {
      _availableBuses = buses;
    });
  }

  // Helper method to get a date for a specific weekday (next occurrence)
  DateTime _getDateFromWeekday(String weekday) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final targetWeekday = weekdays.indexOf(weekday) + 1; // Convert to 1-7 format
    
    final today = DateTime.now();
    final currentWeekday = today.weekday;
    
    // Calculate days until target weekday
    int daysUntilTarget = (targetWeekday - currentWeekday) % 7;
    if (daysUntilTarget == 0) {
      daysUntilTarget = 7; // If it's the same day, get next week's occurrence
    }
    
    return today.add(Duration(days: daysUntilTarget));
  }

  List<Map<String, dynamic>> _getFilteredBuses() {
    List<Map<String, dynamic>> filtered = List.from(_availableBuses);

    // Apply weekday filter first
    if (_selectedWeekday != null) {
      filtered = filtered.where((bus) {
        final plateNumber = bus['plateNumber'] as String? ?? '';
        return ReservationService.isBusAvailableForReservation(
          plateNumber, 
          _getDateFromWeekday(_selectedWeekday!)
        );
      }).toList();
    }

    // Apply availability filter
    if (_availabilityFilter != 'all') {
      filtered = filtered.where((bus) {
        final conductor = bus['conductorData'] as Map<String, dynamic>?;
        final plateNumber = bus['plateNumber'] as String? ?? '';
        
        if (conductor == null) {
          // No conductor data - check if bus is on its coding day
          final isOnCodingDay = _selectedWeekday != null 
            ? ReservationService.isBusAvailableForReservation(
                plateNumber, 
                _getDateFromWeekday(_selectedWeekday!)
              )
            : true; // Show all buses if no weekday filter
          
          return _availabilityFilter == 'available' ? isOnCodingDay : !isOnCodingDay;
        }
        
        // Get conductor availability status
        final busAvailabilityStatus = ReservationService.getBusAvailabilityStatus(conductor);
        
        if (_selectedWeekday != null) {
          // When weekday is selected, check coding day + conductor status
          final isOnCodingDay = ReservationService.isBusAvailableForReservation(
            plateNumber, 
            _getDateFromWeekday(_selectedWeekday!)
          );
          final selectedDate = _getDateFromWeekday(_selectedWeekday!);
          final isReservedForDate = ReservationService.isBusReservedForDate(conductor, selectedDate);
          final isAvailable = isOnCodingDay && busAvailabilityStatus == 'available' && !isReservedForDate;
          final isPending = busAvailabilityStatus == 'pending';
          final isReserved = busAvailabilityStatus == 'reserved' && isReservedForDate;
          
          if (_availabilityFilter == 'available') {
            return isAvailable;
          } else if (_availabilityFilter == 'unavailable') {
            return !isAvailable && !isPending && !isReserved;
          } else if (_availabilityFilter == 'reserved') {
            return isReserved;
          }
        } else {
          // When no weekday selected, only check conductor status
          final isAvailable = busAvailabilityStatus == 'available';
          final isPending = busAvailabilityStatus == 'pending';
          final isReserved = busAvailabilityStatus == 'reserved';
          
          if (_availabilityFilter == 'available') {
            return isAvailable;
          } else if (_availabilityFilter == 'unavailable') {
            return !isAvailable && !isPending && !isReserved;
          } else if (_availabilityFilter == 'reserved') {
            return isReserved;
          }
        }
        
        return true;
      }).toList();
    }

    return filtered;
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
          horizontal: isMobile ? 10 : 12, 
          vertical: isMobile ? 5 : 6
        ),
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
            fontSize: isMobile ? 12 : isTablet ? 14 : 16,
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
    final plateNumber = bus['plateNumber'] as String? ?? '';
    final effectiveDate = _selectedWeekday != null ? _getDateFromWeekday(_selectedWeekday!) : DateTime.now();
    final isGrayedOut = _selectedWeekday != null ? ReservationService.isBusGrayedOutDueToCoding(plateNumber, effectiveDate) : false;

    if (conductor == null || conductor.isEmpty) {
      if (_selectedWeekday != null) {
        final isOnCodingDay = ReservationService.isBusAvailableForReservation(
          plateNumber, 
          effectiveDate
        );
        
        return RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Status: ',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: isGrayedOut ? Colors.grey.shade600 : Colors.black,
                ),
              ),
              TextSpan(
                text: isOnCodingDay ? 'Available - Coding Day' : 'Not on Coding Day',
                style: GoogleFonts.outfit(
                  color: isOnCodingDay ? Colors.green : Colors.red,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      } else {
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
                text: 'Check coding day',
                style: GoogleFonts.outfit(
                  color: Colors.blue,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }
    }

    final busAvailabilityStatus = ReservationService.getBusAvailabilityStatus(conductor);
    
    if (_selectedWeekday != null) {
      // When weekday is selected, check coding day + conductor status
      final isOnCodingDay = ReservationService.isBusAvailableForReservation(
        plateNumber, 
        effectiveDate
      );
      final isReservedForDate = ReservationService.isBusReservedForDate(conductor, effectiveDate);
      final isAvailable = isOnCodingDay && busAvailabilityStatus == 'available' && !isReservedForDate;
      final isPending = busAvailabilityStatus == 'pending';
      final isReserved = busAvailabilityStatus == 'reserved' && isReservedForDate;
      
      final statusColor = isAvailable ? Colors.green : 
                         isPending ? Colors.orange : 
                         isReserved ? Colors.blue : Colors.red;
      final statusText = isAvailable ? 'Available' : 
                        isPending ? 'Pending Payment' : 
                        isReserved ? 'Reserved' : 'Unavailable';
      final statusReason = !isOnCodingDay ? ' (Not coding day)' : 
                         isPending ? ' (Awaiting payment verification)' : 
                         isReserved ? ' (Reserved for this date)' : '';
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Conductor: ',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: isGrayedOut ? Colors.grey.shade600 : Colors.black,
                  ),
                ),
                TextSpan(
                  text: conductor['name'] ?? 'Unknown',
                  style: GoogleFonts.outfit(
                    color: isGrayedOut ? Colors.grey.shade500 : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Status: ',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: isGrayedOut ? Colors.grey.shade600 : Colors.black,
                  ),
                ),
                TextSpan(
                  text: '$statusText$statusReason',
                  style: GoogleFonts.outfit(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (conductor['codingDay'] != null)
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Coding Day: ',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: isGrayedOut ? Colors.grey.shade600 : Colors.black,
                    ),
                  ),
                  TextSpan(
                    text: conductor['codingDay'] ?? 'Unknown',
                    style: GoogleFonts.outfit(
                      color: isGrayedOut ? Colors.grey.shade500 : Colors.grey[800],
                      fontSize: isMobile ? 11 : isTablet ? 12 : 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    } else {
      // When no weekday selected, only show conductor status
      final isAvailable = busAvailabilityStatus == 'available';
      final isPending = busAvailabilityStatus == 'pending';
      final isReserved = busAvailabilityStatus == 'reserved';
      
      final statusColor = isAvailable ? Colors.green : 
                         isPending ? Colors.orange : 
                         isReserved ? Colors.blue : Colors.red;
      final statusText = isAvailable ? 'Available' : 
                        isPending ? 'Pending Payment' : 
                        isReserved ? 'Reserved' : 'Unavailable';
      final statusReason = isPending ? ' (Awaiting payment verification)' : 
                          isReserved ? ' (Reserved for specific date)' : '';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Conductor: ',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                TextSpan(
                  text: conductor['name'] ?? 'Unknown',
                  style: GoogleFonts.outfit(
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
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
                  text: '$statusText$statusReason',
                  style: GoogleFonts.outfit(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (conductor['codingDay'] != null)
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Coding Day: ',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  TextSpan(
                    text: conductor['codingDay'] ?? 'Unknown',
                    style: GoogleFonts.outfit(
                      color: Colors.grey[800],
                      fontSize: isMobile ? 11 : isTablet ? 12 : 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
  }

  void _selectWeekday() {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
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
                      Icons.filter_list,
                      color: Color(0xFF0091AD),
                      size: isMobile ? 24 : 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Filter by Day',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 20 : isTablet ? 22 : 24,
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
              // Options list
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Show All Routes option
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedWeekday = null;
                          });
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                                  fontSize: isMobile ? 16 : isTablet ? 18 : 20,
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
                      // Weekday options
                      ...weekdays.map((weekday) => InkWell(
                        onTap: () {
                          setState(() {
                            _selectedWeekday = weekday;
                          });
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                                  fontSize: isMobile ? 16 : isTablet ? 18 : 20,
                                  fontWeight: _selectedWeekday == weekday 
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
                      )).toList(),
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
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    
    // Responsive sizing
    final drawerHeaderFontSize = isMobile ? 30.0 : isTablet ? 34.0 : 38.0;
    final drawerItemFontSize = isMobile ? 18.0 : isTablet ? 20.0 : 22.0;
    final titleFontSize = isMobile ? 25.0 : isTablet ? 28.0 : 32.0;
    final busListingsFontSize = isMobile ? 24.0 : isTablet ? 28.0 : 32.0;
    final busNameFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final buttonFontSize = isMobile ? 18.0 : isTablet ? 20.0 : 22.0;
    final iconSize = isMobile ? 40.0 : isTablet ? 48.0 : 56.0;
    final expandedHeight = isMobile ? 70.0 : isTablet ? 80.0 : 90.0;
    final horizontalPadding = isMobile ? 16.0 : isTablet ? 20.0 : 24.0;
    final verticalPadding = isMobile ? 12.0 : isTablet ? 16.0 : 20.0;
    final containerPadding = isMobile ? 12.0 : isTablet ? 16.0 : 20.0;
    final marginSpacing = isMobile ? 6.0 : isTablet ? 8.0 : 10.0;
    final horizontalMargin = isMobile ? 10.0 : isTablet ? 12.0 : 16.0;
    final buttonHeight = isMobile ? 50.0 : isTablet ? 55.0 : 60.0;
    
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
                'Bus Reservation',
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
                        horizontal: horizontalPadding, vertical: verticalPadding),
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
                  // Weekday filter
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
                  
                  // Availability filter - Now Scrollable
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Filter:',
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 14 : isTablet ? 16 : 18,
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
                                SizedBox(width: 8), // Extra space at the end
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
                      final effectiveDate = _selectedWeekday != null ? _getDateFromWeekday(_selectedWeekday!) : DateTime.now();
                      final conductor = bus['conductorData'] as Map<String, dynamic>?;
                      final isGrayedOutDueToCoding = _selectedWeekday != null ? ReservationService.isBusGrayedOutDueToCoding(plateNumber, effectiveDate) : false;
                      final isReservedForDate = conductor != null && _selectedWeekday != null ? ReservationService.isBusReservedForDate(conductor, effectiveDate) : false;
                      final isReserved = conductor != null ? ReservationService.getBusAvailabilityStatus(conductor) == 'reserved' : false;
                      final isGrayedOut = isGrayedOutDueToCoding || isReservedForDate || (isReserved && _selectedWeekday == null);
                      final isSelected = _selectedBusIds.contains(bus['id']);
                      
                      return Container(
                        margin: EdgeInsets.symmetric(
                            vertical: marginSpacing, horizontal: horizontalMargin),
                        padding: EdgeInsets.all(containerPadding),
                        decoration: BoxDecoration(
                          color: isGrayedOut ? Colors.grey.shade100 : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: isSelected
                                ? Colors.green
                                : isGrayedOut
                                    ? Colors.grey.shade400
                                    : const Color(0xFF0091AD).withOpacity(0.7),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with icon, name, and checkbox
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_bus,
                                  size: iconSize,
                                  color: isGrayedOut ? Colors.grey.shade500 : Color(0xFF0091AD),
                                ),
                                SizedBox(width: isMobile ? 12 : 16),
                                Expanded(
                                  child: Text(
                                    bus['name'] ?? '',
                                    style: GoogleFonts.outfit(
                                      fontSize: busNameFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: isGrayedOut ? Colors.grey.shade600 : Color(0xFF0091AD),
                                    ),
                                    overflow: TextOverflow.visible,
                                    maxLines: 2,
                                  ),
                                ),
                                Checkbox(
                                  activeColor: Color(0xFF0091AD),
                                  value: _selectedBusIds.contains(bus['id']),
                                  onChanged: isGrayedOut ? null : (bool? selected) {
                                  // Double check if bus is available for the current/selected date
                                  final conductor = bus['conductorData'] as Map<String, dynamic>?;
                                  final effectiveDate = _selectedWeekday != null ? _getDateFromWeekday(_selectedWeekday!) : DateTime.now();
                                  final busAvailabilityStatus = conductor != null ? ReservationService.getBusAvailabilityStatus(conductor) : 'available';
                                  
                                  bool isBusActuallyAvailable;
                                  if (_selectedWeekday != null) {
                                    final isOnCodingDay = ReservationService.isBusAvailableForReservation(plateNumber, effectiveDate);
                                    final isReservedForDate = conductor != null ? ReservationService.isBusReservedForDate(conductor, effectiveDate) : false;
                                    isBusActuallyAvailable = isOnCodingDay && busAvailabilityStatus == 'available' && !isReservedForDate;
                                  } else {
                                    final isReserved = busAvailabilityStatus == 'reserved';
                                    isBusActuallyAvailable = busAvailabilityStatus == 'available' && !isReserved;
                                  }
                                    
                                    if (!isBusActuallyAvailable) {
                                      String reason = '';
                                      if (_selectedWeekday != null) {
                                        final isOnCodingDay = ReservationService.isBusAvailableForReservation(plateNumber, effectiveDate);
                                        final isReservedForDate = conductor != null ? ReservationService.isBusReservedForDate(conductor, effectiveDate) : false;
                                        if (!isOnCodingDay) {
                                          reason = '(not on coding day)';
                                        } else if (busAvailabilityStatus == 'pending') {
                                          reason = '(payment pending)';
                                        } else if (isReservedForDate) {
                                          reason = '(reserved for this date)';
                                        }
                                      } else {
                                        if (busAvailabilityStatus == 'pending') {
                                          reason = '(payment pending)';
                                        } else if (busAvailabilityStatus == 'reserved') {
                                          reason = '(reserved)';
                                        } else {
                                          reason = '(conductor busy)';
                                        }
                                      }
                                      
                                      // Show a snackbar or toast to inform user why they can't select
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Bus is not available $reason'),
                                          duration: Duration(seconds: 2),
                                          backgroundColor: Colors.red.shade400,
                                        ),
                                      );
                                      return;
                                    }
                                    
                                    setState(() {
                                      final id = bus['id'];
                                      if (selected == true) {
                                        _selectedBusIds.add(id);
                                      } else {
                                        _selectedBusIds.remove(id);
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: isMobile ? 12 : 16),
                            // Details section
                            Padding(
                              padding: EdgeInsets.only(left: isMobile ? 10 : 16), // Align with text after icon
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'Plate: ',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            color: isGrayedOut ? Colors.grey.shade600 : Colors.black,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '${bus['plateNumber']}',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.normal,
                                            color: isGrayedOut ? Colors.grey.shade500 : Colors.grey[800],
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
                                          text: 'Available: ',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            color: isGrayedOut ? Colors.grey.shade600 : Colors.black,
                                          ),
                                        ),
                                        TextSpan(
                                          text: List<String>.from(
                                                  bus['codingDays'])
                                              .join(', '),
                                          style: GoogleFonts.outfit(
                                            color: isGrayedOut ? Colors.grey.shade500 : Colors.grey[800],
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
                                          text: 'Price: ',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            color: isGrayedOut ? Colors.grey.shade600 : Colors.black,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '₱${bus['Price']}',
                                          style: GoogleFonts.outfit(
                                            color: isGrayedOut ? Colors.grey.shade500 : Colors.grey[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  // Conductor information
                                  _buildConductorInfo(bus),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: _getFilteredBuses().length,
                  ),
                ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        bottom: true,
        top: false,
        left: false,
        right: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedBusIds.isNotEmpty
                  ? const Color(0xFF0091AD)
                  : Colors.grey.shade400,
              minimumSize: Size(double.infinity, buttonHeight),
            ),
            onPressed: _selectedBusIds.isNotEmpty
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReservationForm(
                          selectedBusIds: _selectedBusIds.toList(),
                        ),
                      ),
                    );
                  }
                : null,
            child: Text(
              'Continue with Selected Bus',
              style: TextStyle(
                color: Colors.white,
                fontSize: buttonFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}