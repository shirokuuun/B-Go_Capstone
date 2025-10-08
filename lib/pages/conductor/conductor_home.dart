import 'package:flutter/material.dart';
import 'package:b_go/pages/conductor/trip_list/trip_page.dart';
import 'package:b_go/pages/conductor/conductor_dashboard.dart';
import 'package:b_go/pages/conductor/conductor_maps.dart';
import 'package:b_go/pages/conductor/conductor_departure.dart';
import 'package:b_go/pages/passenger/services/geofencing_service.dart';
import 'package:b_go/pages/conductor/location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConductorHome extends StatefulWidget {
  final String route;
  final String role;
  final String placeCollection;
  final int selectedIndex;

  ConductorHome({Key? key, required this.route, required this.role, required this.placeCollection, this.selectedIndex = 0, }) : super(key: key);

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
      ConductorMaps(
        route: widget.route,
        role: widget.role,
      ),
      TripsPage(
        route: widget.route,
        role: widget.role,
        placeCollection: widget.placeCollection,
      ),
    ];

    // Start geofencing service when conductor logs in
    _startGeofencingService();
  }

  // Start geofencing service and location tracking for conductor
  Future<void> _startGeofencingService() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get conductor document ID
      final conductorQuery = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (conductorQuery.docs.isNotEmpty) {
        final conductorDocId = conductorQuery.docs.first.id;
        final conductorData = conductorQuery.docs.first.data();

        // Check if conductor was previously tracking (isOnline = true)
        final wasTracking = conductorData['isOnline'] ?? false;

        if (wasTracking) {
          print('🔄 Resuming location tracking and geofencing from previous session...');
          // Resume location tracking from previous session
          await LocationService().startLocationTracking();
          print('✅ Resumed location tracking and geofencing for route: ${widget.route}');
        } else {
          // Just start geofencing monitoring (location tracking will start when user clicks button)
          await GeofencingService()
              .startConductorMonitoring(widget.route, conductorDocId);
          print('✅ Started conductor geofencing service on login for route: ${widget.route}');
        }
      }
    } catch (e) {
      print('❌ Error starting conductor geofencing service: $e');
    }
  }

  @override
  void dispose() {
    // Stop geofencing service when conductor logs out
    GeofencingService().stopMonitoring();
    print('🛑 Stopped conductor geofencing service on logout');
    super.dispose();
  }

  void _onItemTapped(int index) {
  if (index == 1) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConductorDeparture(
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
    return PopScope(
      canPop: false, // Disable back button
      child: Scaffold(
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
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
              icon: Icon(Icons.map),
              label: 'Maps',
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
      ),
    );
  }
}
