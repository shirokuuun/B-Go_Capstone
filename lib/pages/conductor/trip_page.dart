import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TripsPage extends StatefulWidget {
  const TripsPage({Key? key}) : super(key: key);

  @override
  _TripsPageState createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trips Page'),
      ),
      body: Center(
        child: Text(
          'Trips List',
          style: GoogleFonts.outfit(fontSize: 24),
        ),
      ),
    );
  }
}
