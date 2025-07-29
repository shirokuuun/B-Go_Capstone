import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cyan = const Color(0xFF0091AD);
    final paddingH = width * 0.05;
    final fontSizeTitle = width * 0.05;
    final fontSizeSection = width * 0.045;
    final fontSizeBody = width * 0.041;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: cyan,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: fontSizeTitle + 2),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.outfit(
            color: Colors.white,
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
            Text('Effective Date: July 24, 2025',
                style: GoogleFonts.outfit(fontSize: fontSizeBody, color: Colors.black54)),
            SizedBox(height: width * 0.04),
            Text('B-Go ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and protect the personal data of users who access or use the B-Go mobile application. By using the app, you agree to the terms outlined here.',
                style: GoogleFonts.outfit(fontSize: fontSizeBody)),
            SizedBox(height: width * 0.06),
            _sectionTitle('1. Information We Collect', fontSizeSection),
            _sectionBody('We may collect the following information:', fontSizeBody),
            _sectionBody('• Location Data: To show nearby buses and provide real-time tracking, we collect your GPS location while using the app.', fontSizeBody),
            _sectionBody('• Usage Data: We collect anonymous data on how you use the app, such as screen visits and features accessed.', fontSizeBody),
            _sectionBody('• Device Information: This includes mobile device ID, operating system, and app version.', fontSizeBody),
            _sectionBody('• Optional Personal Info: If you submit feedback or contact support, we may collect your name or email address.', fontSizeBody),
            SizedBox(height: width * 0.05),
            _sectionTitle('2. How We Use Your Information', fontSizeSection),
            _sectionBody('We use your data to:', fontSizeBody),
            _sectionBody('• Display live bus locations and arrival estimates', fontSizeBody),
            _sectionBody('• Show seat availability and trip details', fontSizeBody),
            _sectionBody('• Improve app performance and features', fontSizeBody),
            _sectionBody('• Respond to inquiries and user support requests', fontSizeBody),
            SizedBox(height: width * 0.05),
            _sectionTitle('3. Data Sharing', fontSizeSection),
            _sectionBody('We do not sell or rent your personal information. We only share data with:', fontSizeBody),
            _sectionBody('• BATRASCO cooperative staff (for operational monitoring)', fontSizeBody),
            _sectionBody('• Third-party service providers (e.g., Firebase) for app functionality', fontSizeBody),
            _sectionBody('All third parties are required to keep your data secure.', fontSizeBody),
            SizedBox(height: width * 0.05),
            _sectionTitle('4. Data Security', fontSizeSection),
            _sectionBody('We implement safeguards (encryption, access control) to protect your information. However, no method of transmission over the internet is 100% secure.', fontSizeBody),
            SizedBox(height: width * 0.05),
            _sectionTitle('5. Your Rights', fontSizeSection),
            _sectionBody('You can disable GPS access anytime in your device settings (some features may stop working).', fontSizeBody),
            _sectionBody('You can request deletion of your data by contacting us at: privacy@bgo-batangas.com', fontSizeBody),
            SizedBox(height: width * 0.05),
            _sectionTitle('6. Children’s Privacy', fontSizeSection),
            _sectionBody('B-Go is not intended for users under the age of 13. We do not knowingly collect data from children.', fontSizeBody),
            SizedBox(height: width * 0.05),
            _sectionTitle('7. Changes to This Policy', fontSizeSection),
            _sectionBody('We may update this Privacy Policy from time to time. We’ll notify users of significant changes through the app.', fontSizeBody),
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

  Widget _sectionBody(String text, double fontSize) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: fontSize,
          color: Colors.black87,
        ),
      ),
    );
  }
}
