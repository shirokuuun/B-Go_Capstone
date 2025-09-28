import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    // Responsive sizing
    final appBarFontSize = isMobile
        ? 18.0
        : isTablet
            ? 20.0
            : 24.0;
    final sectionFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final bodyFontSize = isMobile
        ? 14.0
        : isTablet
            ? 16.0
            : 18.0;
    final iconSize = isMobile
        ? 20.0
        : isTablet
            ? 24.0
            : 28.0;
    final horizontalPadding = isMobile
        ? 16.0
        : isTablet
            ? 20.0
            : 24.0;
    final verticalPadding = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;

    final cyan = const Color(0xFF0091AD);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: cyan,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: appBarFontSize + 2),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'About',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: appBarFontSize,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Image.asset(
                      'assets/batrasco-logo.png',
                      width: 150,
                      fit: BoxFit.contain,
                    ),
                  SizedBox(height: 8),
                  Text(
                    'Welcome to B-Go — Your Smart Bus Companion in Batangas!',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w500,
                      fontSize: sectionFontSize,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text(
              "B-Go is a mobile app created to improve the daily commuting experience for passengers of the Batangas Transport Cooperative (BATRASCO). Whether you're heading to school, work, or home, B-Go makes riding BATRASCO buses easier, more predictable, and more convenient.",
              style: GoogleFonts.outfit(fontSize: bodyFontSize),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 24),
            _sectionTitle('What B-Go Offers:', sectionFontSize),
            _featureRow(Icons.location_on, 'Live Bus Tracking', 'Know exactly where your bus is and when it will arrive using real-time GPS updates.', iconSize, cyan, bodyFontSize),
            _featureRow(Icons.event_seat, 'Seat Availability Monitoring', 'Check how many seats are available before boarding so you can plan your trip more comfortably.', iconSize, cyan, bodyFontSize),
            _featureRow(Icons.confirmation_num, 'Ticket Management', 'The conductor issues and updates tickets through their interface, and you see accurate trip data in real-time.', iconSize, cyan, bodyFontSize),
            SizedBox(height: 24),
            _sectionTitle('Our Mission:', sectionFontSize),
            Text(
              'To support safe, efficient, and modern public transport in Batangas through reliable digital solutions that connect passengers and bus operators in real time.',
              style: GoogleFonts.outfit(fontSize: bodyFontSize),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 24),
            _sectionTitle('Who We Serve:', sectionFontSize),
            _bullet('Local commuters', bodyFontSize),
            _bullet('Students', bodyFontSize),
            _bullet('Workers', bodyFontSize),
            _bullet('Tourists exploring Batangas', bodyFontSize),
            SizedBox(height: 24),
            _sectionTitle('Powered By:', sectionFontSize),
            Text(
              'The B-Go app is proudly developed in partnership with local developers and the BATRASCO cooperative, aiming to promote innovation in provincial transportation.',
              style: GoogleFonts.outfit(fontSize: bodyFontSize),
              textAlign: TextAlign.justify,
            ),
            SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Text(
                    'Download the B-Go app and ride smarter with BATRASCO!',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w500,
                      fontSize: bodyFontSize,
                      color: cyan,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'For feedback or support: support@bgo-batangas.com',
                    style: GoogleFonts.outfit(fontSize: bodyFontSize, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
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
