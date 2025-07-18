import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConductorDashboard extends StatelessWidget {
  final String route;
  final String role;

  const ConductorDashboard({super.key, required this.route, required this.role});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Welcome, $role!\nRoute: $route',
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(fontSize: 24),
      ),
    );
  }
}
