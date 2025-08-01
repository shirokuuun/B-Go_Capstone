import 'package:b_go/pages/bus_reserve/bus_reserve_pages/reservation_form.dart';
import 'package:b_go/pages/user_role/user_selection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/bus_reserve/reservation_service.dart';
import 'package:b_go/pages/bus_reserve/admin_add_bus.dart';
import 'package:intl/intl.dart';

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
                  fontSize: 30,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text(
                'Home',
                style: GoogleFonts.outfit(
                  fontSize: 18,
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
                  fontSize: 18,
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
              padding: const EdgeInsets.only(top: 18.0, left: 8.0),
              child: IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ),
            title: Padding(
              padding: const EdgeInsets.only(top: 22.0),
              child: Text(
                'Bus Reservation',
                style: GoogleFonts.outfit(
                  fontSize: 25,
                  color: Colors.white,
                ),
              ),
            ),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(top: 18),
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
            expandedHeight: 70,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
                          fontSize: 24,
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
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  if (_selectedDate != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
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
                        margin: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 10),
                        padding: const EdgeInsets.all(12),
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
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Icon(
                                Icons.directions_bus,
                                size: 40,
                                color: Color(0xFF0091AD),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 100,
                              child: Text(
                                bus['name'] ?? '',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0091AD),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0091AD),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AdminAddBus()),
          );
          _fetchAvailableBuses();
        },
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        top: false,
        left: false,
        right: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedBusIds.isNotEmpty
                  ? const Color(0xFF0091AD)
                  : Colors.grey.shade400,
              minimumSize: const Size(double.infinity, 50),
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
            child: const Text(
              'Continue with Selected Bus',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
