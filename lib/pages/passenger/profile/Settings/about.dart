import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cyan = const Color(0xFF0091AD);
    final paddingH = width * 0.05;
    final fontSizeTitle = width * 0.05;
    final fontSizeSection = width * 0.045;
    final fontSizeBody = width * 0.041;
    final iconSize = width * 0.09;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: cyan,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black, size: fontSizeTitle + 2),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'About',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: fontSizeTitle,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: width * 0.04, horizontal: paddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Icon(Icons.directions_bus, color: cyan, size: iconSize * 1.2),
                  SizedBox(height: width * 0.02),
                  Text(
                    'Welcome to B-Go — Your Smart Bus Companion in Batangas!',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w500,
                      fontSize: fontSizeSection,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: width * 0.05),
            Text(
              'B-Go is a mobile app created to improve the daily commuting experience for passengers of the Batangas Transport Cooperative (BATRASCO). Whether you’re heading to school, work, or home, B-Go makes riding BATRASCO buses easier, more predictable, and more convenient.',
              style: GoogleFonts.outfit(fontSize: fontSizeBody),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: width * 0.06),
            _sectionTitle('🚍 What B-Go Offers:', fontSizeSection),
            _featureRow(Icons.location_on, 'Live Bus Tracking', 'Know exactly where your bus is and when it will arrive using real-time GPS updates.', iconSize, cyan, fontSizeBody),
            _featureRow(Icons.event_seat, 'Seat Availability Monitoring', 'Check how many seats are available before boarding so you can plan your trip more comfortably.', iconSize, cyan, fontSizeBody),
            _featureRow(Icons.confirmation_num, 'Ticket Management', 'The conductor issues and updates tickets through their interface, and you see accurate trip data in real-time.', iconSize, cyan, fontSizeBody),
            SizedBox(height: width * 0.06),
            _sectionTitle('🎯 Our Mission:', fontSizeSection),
            Text(
              'To support safe, efficient, and modern public transport in Batangas through reliable digital solutions that connect passengers and bus operators in real time.',
              style: GoogleFonts.outfit(fontSize: fontSizeBody),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: width * 0.06),
            _sectionTitle('👥 Who We Serve:', fontSizeSection),
            _bullet('Local commuters', fontSizeBody),
            _bullet('Students', fontSizeBody),
            _bullet('Workers', fontSizeBody),
            _bullet('Tourists exploring Batangas', fontSizeBody),
            SizedBox(height: width * 0.06),
            _sectionTitle('⚙️ Powered By:', fontSizeSection),
            Text(
              'The B-Go app is proudly developed in partnership with local developers and the BATRASCO cooperative, aiming to promote innovation in provincial transportation.',
              style: GoogleFonts.outfit(fontSize: fontSizeBody),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: width * 0.06),
            Center(
              child: Column(
                children: [
                  Text(
                    'Download the B-Go app and ride smarter with BATRASCO!',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w500,
                      fontSize: fontSizeBody,
                      color: cyan,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: width * 0.02),
                  Text(
                    'For feedback or support: support@bgo-batangas.com',
                    style: GoogleFonts.outfit(fontSize: fontSizeBody, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: width * 0.04),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, double fontSize) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w500,
          fontSize: fontSize,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String title, String desc, double iconSize, Color color, double fontSizeBody) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: iconSize),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: fontSizeBody)),
                Text(desc, style: GoogleFonts.outfit(fontSize: fontSizeBody)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text, double fontSize) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
      child: Row(
        children: [
          Text('• ', style: GoogleFonts.outfit(fontSize: fontSize)),
          Expanded(child: Text(text, style: GoogleFonts.outfit(fontSize: fontSize))),
        ],
      ),
    );
  }
}
