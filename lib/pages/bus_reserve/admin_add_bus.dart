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
  final TextEditingController _plateNumberController = TextEditingController();

  final List<String> _selectedDays = [];

  final List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  Future<void> _submitBus() async {
    final busName = _busNameController.text.trim();
    final plate = _plateNumberController.text.trim();

    if (busName.isEmpty || plate.isEmpty || _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill in all fields and select at least one coding day.")),
      );
      return;
    }

    await ReservationService.addBus(
      busName: busName,
      plateNumber: plate,
      codingDays: _selectedDays,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Bus added successfully")),
    );

    _busNameController.clear();
    _plateNumberController.clear();
    setState(() => _selectedDays.clear());
  }

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
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
            fontWeight: FontWeight.w600,
          ),
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
                    controller: _plateNumberController,
                    decoration: InputDecoration(labelText: "Plate Number"),
                  ),
                  SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Select Coding Days", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _weekDays.map((day) {
                      final selected = _selectedDays.contains(day);
                      return ChoiceChip(
                        label: Text(day),
                        selected: selected, 
                        onSelected: (_) => _toggleDay(day),
                        selectedColor: Colors.blue[700],
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black,
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _submitBus,
                    icon: Icon(Icons.save),
                    label: Text("Save Bus"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
