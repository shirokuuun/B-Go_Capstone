import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/bus_reserve/reservation_service.dart';

class AdminAddBus extends StatefulWidget {

  AdminAddBus({super.key});

  @override
  State<AdminAddBus> createState() => _AdminAddBusState();
}

class _AdminAddBusState extends State<AdminAddBus> {

  final TextEditingController _busNameController = TextEditingController();
  final TextEditingController _routeController = TextEditingController();
  final TextEditingController _plateNumberController = TextEditingController();

  final List<String> _daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  final Set<String> _selectedDays = {};

  Future<void> _submitBus() async {
    final busName = _busNameController.text.trim();
    final route = _routeController.text.trim();
    final plate = _plateNumberController.text.trim();

    if (busName.isEmpty || route.isEmpty || plate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill in all fields.")),
      );
      return;
    }

    await ReservationService.addBus(
      busName: busName,
      route: route,
      plateNumber: plate,
      codingDays: _selectedDays.toList(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Bus added successfully")),
    );

    _busNameController.clear();
    _routeController.clear();
    _plateNumberController.clear();
    setState(() => _selectedDays.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bus Reservation',
          style: GoogleFonts.outfit(
            fontSize: 20, 
            color: Colors.white,
            fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1D2B53),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _busNameController,
                  decoration: InputDecoration(labelText: "Bus Number"),
                ),
                TextField(
                  controller: _routeController,
                  decoration: InputDecoration(labelText: "Route"),
                ),
                TextField(
                  controller: _plateNumberController,
                  decoration: InputDecoration(labelText: "Plate Number"),
                ),
                SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Select Coding Days", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                Wrap(
                  spacing: 8,
                  children: _daysOfWeek.map((day) {
                    return FilterChip(
                      label: Text(day),
                      selected: _selectedDays.contains(day),
                      onSelected: (bool selected) {
                        setState(() {
                          selected ? _selectedDays.add(day) : _selectedDays.remove(day);
                        });
                      },
                    );
                  }).toList(),
                ),
                SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _submitBus,
                  icon: Icon(Icons.save),
                  label: Text("Save to Firestore"),
                )
              ],
            ),
              ) 
          ),
        ),
      ),
    );
  }
}
