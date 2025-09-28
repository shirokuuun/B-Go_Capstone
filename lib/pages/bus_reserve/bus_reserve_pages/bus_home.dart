import 'package:b_go/pages/bus_reserve/bus_reserve_pages/reservation_form.dart';
import 'package:b_go/pages/user_role/user_selection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/bus_reserve/reservation_service.dart';
import 'package:intl/intl.dart';
import 'package:responsive_framework/responsive_framework.dart';

class BusHome extends StatefulWidget {
  const BusHome({super.key});

  @override
  State<BusHome> createState() => _BusHomeState();
}

class _BusHomeState extends State<BusHome> {
  List<Map<String, dynamic>> _availableBuses = [];
  Set<String> _selectedBusIds = {};
  DateTime? _selectedDate;
  String _availabilityFilter = 'all'; // 'all', 'available', 'unavailable'
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fetchConductorBuses();
  }

  Future<void> _fetchConductorBuses() async {
    // Fetch all conductors formatted as bus data
    final buses = await ReservationService.getAllConductorsAsBuses();
    setState(() {
      _availableBuses = buses;
    });
  }

  List<Map<String, dynamic>> _getFilteredBuses() {
    List<Map<String, dynamic>> filtered = List.from(_availableBuses);

    // Apply availability filter
    if (_availabilityFilter != 'all') {
      filtered = filtered.where((bus) {
        final conductor = bus['conductorData'] as Map<String, dynamic>?;
        final plateNumber = bus['plateNumber'] as String? ?? '';
        
        // Check if bus is on its coding day (available for reservation)
        final isOnCodingDay = ReservationService.isBusAvailableForReservation(
          plateNumber, 
          _selectedDate ?? DateTime.now()
        );
        
        if (conductor == null) {
          // No conductor data - bus is only available if it's on coding day
          print('🔍 Filter - Bus: ${bus['name']}, No conductor data, IsOnCodingDay: $isOnCodingDay');
          return _availabilityFilter == 'available' ? isOnCodingDay : !isOnCodingDay;
        }
        
        // Get conductor availability status
        final busAvailabilityStatus = ReservationService.getBusAvailabilityStatus(conductor);
        
        print('🔍 Filter - Bus: ${bus['name']}, Plate: $plateNumber');
        print('🔍 Filter - IsOnCodingDay: $isOnCodingDay, BusAvailabilityStatus: $busAvailabilityStatus');
        
        // Bus is available if it's on its coding day AND conductor status is available
        final isAvailable = isOnCodingDay && busAvailabilityStatus == 'available';
        print('🔍 Filter - Final isAvailable: $isAvailable');
        
        if (_availabilityFilter == 'available') {
          return isAvailable;
        } else if (_availabilityFilter == 'unavailable') {
          return !isAvailable;
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
    final isGrayedOut = ReservationService.isBusGrayedOutDueToCoding(plateNumber, _selectedDate);

    if (conductor == null || conductor.isEmpty) {
      final isOnCodingDay = ReservationService.isBusAvailableForReservation(
        plateNumber, 
        _selectedDate ?? DateTime.now()
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
    }

    final isOnCodingDay = ReservationService.isBusAvailableForReservation(
      plateNumber, 
      _selectedDate ?? DateTime.now()
    );
    final busAvailabilityStatus = ReservationService.getBusAvailabilityStatus(conductor);
    
    print('🔍 Bus: ${bus['name']}, Plate: $plateNumber');
    print('🔍 Selected Date: ${_selectedDate ?? DateTime.now()}');
    print('🔍 IsOnCodingDay: $isOnCodingDay');
    print('🔍 BusAvailabilityStatus: $busAvailabilityStatus');
    
    // Bus is available if it's on its coding day AND conductor status is available
    final isAvailable = isOnCodingDay && busAvailabilityStatus == 'available';
    print('🔍 Final isAvailable: $isAvailable');
    
    final statusColor = isAvailable ? Colors.green : Colors.red;
    final statusText = isAvailable ? 'Available' : 'Unavailable';
    final statusReason = !isOnCodingDay ? ' (Not coding day)' : 
                       busAvailabilityStatus != 'available' ? ' (Conductor busy)' : '';

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
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchConductorBuses();
    }
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
                  icon: const Icon(Icons.calendar_today, color: Colors.white),
                  onPressed: _selectDate,
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
                  // Date filter
                  if (_selectedDate != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Selected: ${DateFormat('EEE, MMM d').format(_selectedDate!)}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Clear Filter',
                          onPressed: () {
                            setState(() {
                              _selectedDate = null;
                            });
                            _fetchConductorBuses();
                          },
                        )
                      ],
                    ),
                  
                  // Availability filter
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Text(
                          'Filter:',
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 16 : isTablet ? 18 : 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              _buildFilterChip('All', 'all'),
                              SizedBox(width: 8),
                              _buildFilterChip('Available', 'available'),
                              SizedBox(width: 8),
                              _buildFilterChip('Unavailable', 'unavailable'),
                            ],
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
                      final effectiveDate = _selectedDate ?? DateTime.now();
                      final isGrayedOut = ReservationService.isBusGrayedOutDueToCoding(plateNumber, effectiveDate);
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
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Icon(
                                Icons.directions_bus,
                                size: iconSize,
                                color: isGrayedOut ? Colors.grey.shade500 : Color(0xFF0091AD),
                              ),
                            ),
                            SizedBox(width: isMobile ? 12 : 16),
                            SizedBox(
                              width: isMobile ? 100 : 120,
                              child: Text(
                                bus['name'] ?? '',
                                style: GoogleFonts.outfit(
                                  fontSize: busNameFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: isGrayedOut ? Colors.grey.shade600 : Color(0xFF0091AD),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: isMobile ? 12 : 16),
                            Expanded(
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
                                          text: '${bus['Price']}',
                                          style: GoogleFonts.outfit(
                                            color: isGrayedOut ? Colors.grey.shade500 : Colors.grey[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Conductor information
                                  _buildConductorInfo(bus),
                                ],
                              ),
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child: Checkbox(
                                activeColor: Color(0xFF0091AD),
                                value: _selectedBusIds.contains(bus['id']),
                                onChanged: isGrayedOut ? null : (bool? selected) {
                                  // Double check if bus is available for the current/selected date
                                  final conductor = bus['conductorData'] as Map<String, dynamic>?;
                                  final effectiveDate = _selectedDate ?? DateTime.now();
                                  final isOnCodingDay = ReservationService.isBusAvailableForReservation(plateNumber, effectiveDate);
                                  final busAvailabilityStatus = conductor != null ? ReservationService.getBusAvailabilityStatus(conductor) : 'available';
                                  final isBusActuallyAvailable = isOnCodingDay && busAvailabilityStatus == 'available';
                                  
                                  if (!isBusActuallyAvailable) {
                                    // Show a snackbar or toast to inform user why they can't select
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Bus is not available ${!isOnCodingDay ? '(not on coding day)' : '(conductor busy)'}'),
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