import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TripSchedPage extends StatelessWidget {
  const TripSchedPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Trip Schedules',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFF0091AD),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF0091AD),
              ),
              child: Text(
                'Menu',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 30,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text(
                'Home',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/home');
              },
            ),
            ListTile(
              leading: Icon(Icons.schedule),
              title: Text(
                'Trip Schedules',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.map),
              title: Text(
                'Batrasco Routes',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildScheduleCard(
            route: 'Batangas City - SM Lipa',
            schedules: [
              '5:00 AM',
              '5:30 AM',
              '6:00 AM',
              '6:30 AM',
            ],
          ),
          SizedBox(height: 16),
          _buildScheduleCard(
            route: 'Rosario - SM Lipa',
            schedules: [
              '5:00 AM',
              '5:30 AM',
              '6:00 AM',
              '6:30 AM',
            ],
          ),
          SizedBox(height: 16),
          _buildScheduleCard(
            route: 'Tiaong - SM Lipa',
            schedules: [
              '5:00 AM',
              '5:30 AM',
              '6:00 AM',
              '6:30 AM',
            ],
          ),
          SizedBox(height: 16),
          _buildScheduleCard(
            route: 'Mataas na Kahoy - SM Lipa',
            schedules: [
              '5:00 AM',
              '5:30 AM',
              '6:00 AM',
              '6:30 AM',
            ],
          ),
          SizedBox(height: 16),
          _buildScheduleCard(
            route: 'San Juan - SM Lipa',
            schedules: [
              '5:00 AM',
              '5:30 AM',
              '6:00 AM',
              '6:30 AM',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard({required String route, required List<String> schedules}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              route,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0091AD),
              ),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: schedules
                  .map((time) => Chip(
                        label: Text(time, style: GoogleFonts.outfit()),
                        backgroundColor: Color(0xFFE0F7FA),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
