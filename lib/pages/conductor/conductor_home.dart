import 'package:flutter/material.dart';
import 'package:b_go/pages/conductor/trip_list/trip_page.dart';
import 'package:b_go/pages/conductor/conductor_dashboard.dart';
import 'package:b_go/pages/conductor/conductor_maps.dart';
import 'package:b_go/pages/conductor/conductor_departure.dart';
import 'package:b_go/pages/conductor/location_service.dart';
import 'package:b_go/services/background_geofencing_service.dart';
import 'package:b_go/services/foreground_service_manager.dart';
import 'package:b_go/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConductorHome extends StatefulWidget {
  final String route;
  final String role;
  final String placeCollection;
  final int selectedIndex;

  ConductorHome({
    Key? key,
    required this.route,
    required this.role,
    required this.placeCollection,
    this.selectedIndex = 0,
  }) : super(key: key);

  @override
  _ConductorHomeState createState() => _ConductorHomeState();
}

class _ConductorHomeState extends State<ConductorHome> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  late List<Widget> _pages;
  final BackgroundGeofencingService _backgroundGeofencing = BackgroundGeofencingService();

  @override
  void initState() {
    super.initState();
    
    // Add app lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
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

    // Initialize background geofencing service
    _initializeBackgroundGeofencing();
  }

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Stop geofencing service when conductor logs out
    _stopBackgroundGeofencing();
    print('🛑 Stopped conductor geofencing service on logout');
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    print('📱 App lifecycle changed: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App returned to foreground
        print('✅ App resumed - checking geofencing status...');
        _checkAndRestartGeofencing();
        break;
      case AppLifecycleState.paused:
        // App went to background - geofencing continues
        print('⏸️ App paused - background geofencing continues');
        break;
      case AppLifecycleState.inactive:
        print('⏸️ App inactive');
        break;
      case AppLifecycleState.detached:
        print('⏸️ App detached');
        break;
      case AppLifecycleState.hidden:
        print('⏸️ App hidden');
        break;
    }
  }

  /// Initialize background geofencing service
  Future<void> _initializeBackgroundGeofencing() async {
    try {
      // Initialize the background service
      await _backgroundGeofencing.initialize();
      
      // Request background location permission
      await ForegroundServiceManager.requestBackgroundLocationPermission();
      
      // Start geofencing if conductor was previously online
      await _startGeofencingService();
      
    } catch (e) {
      print('❌ Error initializing background geofencing: $e');
    }
  }

  /// Start geofencing service and location tracking for conductor
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

        // ✅ Start foreground service (required for Android)
        await ForegroundServiceManager.startForegroundService();

        // ✅ ALWAYS start background geofencing monitoring
        final started = await _backgroundGeofencing.startMonitoring(
          widget.route,
          conductorDocId,
        );

        if (started) {
          print('✅ Started background geofencing service for route: ${widget.route}');
        } else {
          print('⚠️ Failed to start background geofencing service');
        }

        if (wasTracking) {
          print('🔄 Resuming location tracking from previous session...');
          // Also resume location tracking from previous session
          await LocationService().startLocationTracking();
          print('✅ Resumed location tracking');
        }
      }
    } catch (e) {
      print('❌ Error starting conductor geofencing service: $e');
    }
  }

  /// Stop background geofencing
  Future<void> _stopBackgroundGeofencing() async {
    try {
      await _backgroundGeofencing.stopMonitoring();
      await ForegroundServiceManager.stopForegroundService();
      print('✅ Background geofencing stopped');
    } catch (e) {
      print('❌ Error stopping background geofencing: $e');
    }
  }

  /// Check and restart geofencing if needed (when app resumes)
  Future<void> _checkAndRestartGeofencing() async {
    try {
      final isMonitoring = await _backgroundGeofencing.isMonitoring();
      
      if (!isMonitoring) {
        print('⚠️ Geofencing not active, restarting...');
        await _startGeofencingService();
      } else {
        print('✅ Background geofencing already active');
        // Refresh destinations in case new passengers boarded while app was in background
        await _backgroundGeofencing.refreshDestinations();
      }
    } catch (e) {
      print('❌ Error checking geofencing status: $e');
    }
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
      ).then((_) {
        // Refresh destinations when returning from ticketing page
        _backgroundGeofencing.refreshDestinations();
      });
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