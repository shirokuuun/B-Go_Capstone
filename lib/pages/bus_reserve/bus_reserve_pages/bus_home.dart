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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fetchAvailableBuses();
  }

  Future<void> _fetchAvailableBuses() async {
    final buses = await ReservationService.getAvailableBuses();

    final filtered = _selectedDate == null
        ? buses
        : buses.where((bus) {
            final List<dynamic> codingDays = bus['codingDays'] ?? [];
            final selectedWeekday = DateFormat('EEEE').format(_selectedDate!);
            return codingDays.contains(selectedWeekday);
          }).toList();

    setState(() {
      _availableBuses = filtered;
    });
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
      _fetchAvailableBuses();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final isDesktop = ResponsiveBreakpoints.of(context).isDesktop;
    
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
                            _fetchAvailableBuses();
                          },
                        )
                      ],
                    ),
                ],
              ),
            ),
          ),
          _availableBuses.isEmpty
              ? const SliverFillRemaining(
                  child: Center(child: Text("No buses available.")),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final bus = _availableBuses[index];
                      return Container(
                        margin: EdgeInsets.symmetric(
                            vertical: marginSpacing, horizontal: horizontalMargin),
                        padding: EdgeInsets.all(containerPadding),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                            color: _selectedBusIds.contains(bus['id'])
                                ? Colors.green
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
                                color: Color(0xFF0091AD),
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
                                  color: Color(0xFF0091AD),
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
                                            color: Colors
                                                .black, // or your desired color
                                          ),
                                        ),
                                        TextSpan(
                                          text: '${bus['plateNumber']}',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.normal,
                                            color: Colors.grey[
                                                800], // or any style you want
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
                                            color: Colors.black,
                                          ),
                                        ),
                                        TextSpan(
                                          text: List<String>.from(
                                                  bus['codingDays'])
                                              .join(', '),
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
                                          text: 'Price: ',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        TextSpan(
                                          text: '${bus['Price']}',
                                          style: GoogleFonts.outfit(
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child: Checkbox(
                                activeColor: Color(0xFF0091AD),
                                value: _selectedBusIds.contains(bus['id']),
                                onChanged: (bool? selected) {
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
                    childCount: _availableBuses.length,
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
