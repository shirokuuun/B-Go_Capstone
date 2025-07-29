import 'package:b_go/pages/bus_reserve/BusReserve_pages/bus_home.dart';
import 'package:b_go/pages/user_role/user_selection.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/bus_reserve/reservation_service.dart';

class ReservationForm extends StatefulWidget {
  final List<String> selectedBusIds;

  ReservationForm({Key? key, required this.selectedBusIds}) : super(key: key);

  @override
  State<ReservationForm> createState() => _ReservationFormState();
}

final TextEditingController _fromController = TextEditingController();
final TextEditingController _toController = TextEditingController();
final TextEditingController _fullNameController = TextEditingController();
final TextEditingController _emailController = TextEditingController();

bool isRoundTrip = false;

class _ReservationFormState extends State<ReservationForm> {
  Future<void> _submitReservation() async {
    final from = _fromController.text.trim();
    final to = _toController.text.trim();
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();

   if (from.isEmpty || to.isEmpty || fullName.isEmpty || email.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill out all fields')),
    );
    return;
  }

  if (!_isValidEmail(email)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please enter a valid email address')),
    );
    return;
  }

    try {
      await ReservationService.saveReservation(
        selectedBusIds: widget.selectedBusIds,
        from: from,
        to: to,
        isRoundTrip: isRoundTrip,
        fullName: fullName,
        email: email,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation submitted successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _buildFormField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: (val) => setState(() {}), // 🔥 This fixes the issue
        style: GoogleFonts.outfit(fontSize: 16),
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          labelStyle: GoogleFonts.outfit(),
        ),
      ),
    );
  }


  bool _isValidEmail(String email) {
  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  return emailRegex.hasMatch(email);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: const Color(0xFF0091AD),
            leading: Padding(
              padding: const EdgeInsets.only(top: 18.0, left: 8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => BusHome()),
                  );
                },
              ),
            ),
            title: Padding(
              padding: const EdgeInsets.only(top: 22.0),
              child: Text(
                'Reservation Form',
                style: GoogleFonts.outfit(
                  fontSize: 25,
                  color: Colors.white,
                ),
              ),
            ),
            centerTitle: true,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        'Fill out the form below',
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
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildFormField('From', _fromController),
                  _buildFormField('To', _toController),
                  Row(
                    children: [
                      Checkbox(
                        value: isRoundTrip,
                        onChanged: (val) {
                          setState(() {
                            isRoundTrip = val ?? false;
                          });
                        },
                      ),
                      Text('Roundtrip', style: GoogleFonts.outfit(fontSize: 16)),
                    ],
                  ),
                  _buildFormField('Full Name', _fullNameController),
                  _buildFormField('Email Address', _emailController, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
       bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _fromController.text.isNotEmpty &&
                    _toController.text.isNotEmpty &&
                    _fullNameController.text.isNotEmpty &&
                    _emailController.text.isNotEmpty
                ? const Color(0xFF0091AD)
                : Colors.grey.shade400,
            minimumSize: const Size(double.infinity, 50),
          ),
         onPressed: _fromController.text.isNotEmpty &&
        _toController.text.isNotEmpty &&
        _fullNameController.text.isNotEmpty &&
        _emailController.text.isNotEmpty
    ? () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Confirm Reservation',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0091AD),
            )),
            content:  Text(
              'You are about to reserve an entire bus. Please note that this booking is non-refundable once confirmed.\n\nDo you wish to proceed?',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w500),
            ),
            actions: [
              TextButton(
                child: Text('Cancel',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 75, 221, 136),
                ),
                child: Text('Proceed',
                  style: GoogleFonts.outfit(
                    color: Colors.white,    
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );

        if (confirmed == true) {
        await _submitReservation(); // Wait until reservation is saved
        Navigator.pushReplacement( // Replaces ReservationForm
          context,
          MaterialPageRoute(
            builder: (context) => UserSelection(),
          ),
        );
      }

      }
    : null,
          child: Text(
            'Submit Reservation',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
