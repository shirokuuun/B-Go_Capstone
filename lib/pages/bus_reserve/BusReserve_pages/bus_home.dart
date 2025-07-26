import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/bus_reserve/reservation_service.dart';
import 'package:b_go/pages/bus_reserve/admin_add_bus.dart'; // Import your new admin page

class BusHome extends StatefulWidget {
  BusHome({super.key});

  @override
  State<BusHome> createState() => _BusHomeState();
}

class _BusHomeState extends State<BusHome> {
  List<Map<String, dynamic>> _availableBuses = [];

  @override
  void initState() {
    super.initState();
    _fetchAvailableBuses();
  }

  Future<void> _fetchAvailableBuses() async {
    final buses = await ReservationService.getAvailableBuses();
    setState(() {
      _availableBuses = buses;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Available Buses',
          style: GoogleFonts.outfit(
            fontSize: 20,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF1D2B53),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _availableBuses.isEmpty
            ? Center(child: Text("No buses available."))
            : ListView.builder(
                itemCount: _availableBuses.length,
                itemBuilder: (context, index) {
                  final bus = _availableBuses[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(bus['name'] ?? ''),
                      subtitle: Text("Route: ${bus['route']}\nPlate: ${bus['plateNumber']}"),
                      trailing: Text("🚌"),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF1D2B53),
        child: Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AdminAddBus()),
          ).then((_) => _fetchAvailableBuses()); // Refresh after adding
        },
      ),
    );
  }
}
