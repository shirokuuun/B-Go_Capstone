import 'package:b_go/pages/passenger/home_page.dart';
import 'package:b_go/pages/passenger/passenger_service.dart';
import 'package:b_go/pages/passenger/profile/profile.dart';
import 'package:flutter/material.dart';

class PassengerShellPage extends StatefulWidget {
  @override
  _PassengerShellPageState createState() => _PassengerShellPageState();
}

class _PassengerShellPageState extends State<PassengerShellPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomePage(role: 'passenger'), 
    PassengerService(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.directions_bus),
            label: 'Passenger Service',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        selectedItemColor: Color(0xFF0091AD),
      ),
    );
  }
}
