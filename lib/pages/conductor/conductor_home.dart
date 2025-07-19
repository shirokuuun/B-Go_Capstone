import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/trip_list/trip_page.dart';
import 'package:b_go/pages/conductor/ticketing/conductor_from.dart';
import 'package:b_go/pages/conductor/conductor_dashboard.dart';
import 'package:b_go/pages/conductor/route_service.dart';

class ConductorHome extends StatefulWidget {
  String route;
  String role;
  String placeCollection;
  final int selectedIndex;

  ConductorHome({Key? key, required this.route, required this.role, this.selectedIndex = 0, required this.placeCollection}) : super(key: key);

  @override
  _ConductorHomeState createState() => _ConductorHomeState();
}

class _ConductorHomeState extends State<ConductorHome> {
  int _selectedIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;

    _pages = [
      ConductorDashboard(
      route: widget.route,
      role: widget.role,
    ),
    Container(),
    TripsPage(
      route: widget.route,
      role: widget.role,
      placeCollection: widget.placeCollection,
    ),
  ];
  }

  void _onItemTapped(int index) {
  if (index == 1) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConductorFrom(
          route: widget.route,
          role: widget.role,
        ),
      ),
    );
  } else {
    setState(() {
      _selectedIndex = index;
    });
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number),
            label: 'Ticketing',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_bus),
            label: 'Trips',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Color(0xFF0091AD),
        onTap: _onItemTapped,
      ),
    );
  }
}
