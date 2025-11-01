import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({Key? key}) : super(key: key);

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
          icon: Icon(Icons.arrow_back,
              color: Colors.white, size: appBarFontSize + 2),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: appBarFontSize,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
            vertical: verticalPadding, horizontal: horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Effective Date: July 24, 2025',
                style: GoogleFonts.outfit(
                    fontSize: bodyFontSize, color: Colors.black54)),
            SizedBox(height: 16),
            Text(
                'BusGo ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and protect the personal data of users who access or use the BusGo mobile application. By using the app, you agree to the terms outlined here.',
                style: GoogleFonts.outfit(fontSize: bodyFontSize)),
            SizedBox(height: 24),
            _sectionTitle('1. Information We Collect', sectionFontSize),
            _sectionBody(
                'We may collect the following information:', bodyFontSize),
            _sectionBody(
                '• Location Data: To show nearby buses and provide real-time tracking, we collect your GPS location while using the app.',
                bodyFontSize),
            _sectionBody(
                '• Usage Data: We collect anonymous data on how you use the app, such as screen visits and features accessed.',
                bodyFontSize),
            _sectionBody(
                '• Device Information: This includes mobile device ID, operating system, and app version.',
                bodyFontSize),
            _sectionBody(
                '• Optional Personal Info: If you submit feedback or contact support, we may collect your name or email address.',
                bodyFontSize),
            SizedBox(height: 20),
            _sectionTitle('2. How We Use Your Information', sectionFontSize),
            _sectionBody('We use your data to:', bodyFontSize),
            _sectionBody('• Display live bus locations and arrival estimates',
                bodyFontSize),
            _sectionBody(
                '• Show seat availability and trip details', bodyFontSize),
            _sectionBody(
                '• Improve app performance and features', bodyFontSize),
            _sectionBody('• Respond to inquiries and user support requests',
                bodyFontSize),
            SizedBox(height: 20),
            _sectionTitle('3. Data Sharing', sectionFontSize),
            _sectionBody(
                'We do not sell or rent your personal information. We only share data with:',
                bodyFontSize),
            _sectionBody(
                '• BATRASCO cooperative staff (for operational monitoring)',
                bodyFontSize),
            _sectionBody(
                '• Third-party service providers (e.g., Firebase) for app functionality',
                bodyFontSize),
            _sectionBody(
                'All third parties are required to keep your data secure.',
                bodyFontSize),
            SizedBox(height: 20),
            _sectionTitle('4. Data Security', sectionFontSize),
            _sectionBody(
                'We implement safeguards (encryption, access control) to protect your information.',
                bodyFontSize),
            SizedBox(height: 20),
            _sectionTitle('5. Your Rights', sectionFontSize),
            _sectionBody(
                'You can disable GPS access anytime in your device settings (some features may stop working).',
                bodyFontSize),
            _sectionBody(
                'You can request deletion of your data by contacting us at: batrascoservices@gmail.com',
                bodyFontSize),
            SizedBox(height: 20),
            _sectionTitle("6. Children's Privacy", sectionFontSize),
            _sectionBody(
                "BusGo is not intended for users under the age of 13.",
                bodyFontSize),
            SizedBox(height: 20),
            _sectionTitle("7. Changes to This Policy", sectionFontSize),
            _sectionBody(
                "We may update this Privacy Policy from time to time. We'll notify users of significant changes through the app.",
                bodyFontSize),
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
