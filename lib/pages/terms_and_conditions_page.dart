import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsAndConditionsPage extends StatefulWidget {
  final VoidCallback showRegisterPage;
  const TermsAndConditionsPage({Key? key, required this.showRegisterPage})
      : super(key: key);

  @override
  State<TermsAndConditionsPage> createState() => _TermsAndConditionsPageState();
}

class _TermsAndConditionsPageState extends State<TermsAndConditionsPage> {
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final fontSizeBody = width * 0.041;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Terms and Conditions',
          style: GoogleFonts.outfit(
            fontSize: 20, 
            fontWeight: FontWeight.w600, 
            color: Colors.white
          ),
        ),
        backgroundColor: Color(0xFF0091AD),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'B-Go Transportation Services - Terms and Conditions',
              style: GoogleFonts.outfit(
                fontSize: fontSizeBody * 1.2,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0091AD),
              ),
            ),
            SizedBox(height: 16),
            
            // 1. Acceptance of Terms
            _buildSection(
              '1. Acceptance of Terms',
              'By accessing and using the B-Go mobile application, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use our services.',
              fontSizeBody,
            ),
            
            // 2. Service Description
            _buildSection(
              '2. Service Description',
              'B-Go provides bus transportation services including pre-booking, ticketing, and real-time tracking. Our services are available to registered users who comply with our terms and policies.',
              fontSizeBody,
            ),
            
            // 3. User Registration and Account
            _buildSection(
              '3. User Registration and Account',
              '• You must provide accurate and complete information during registration\n'
              '• You are responsible for maintaining the confidentiality of your account\n'
              '• You must be at least 13 years old to create an account\n'
              '• One account per person is allowed\n'
              '• You are responsible for all activities under your account',
              fontSizeBody,
            ),
            
            // 4. ID Verification
            _buildSection(
              '4. ID Verification',
              '• Users may submit government-issued or school IDs for verification\n'
              '• Verified IDs may qualify for special discounts (Student, Senior Citizen, PWD)\n'
              '• ID verification is subject to approval by our admin team\n'
              '• Users must provide clear, unaltered images of their IDs\n'
              '• We reserve the right to reject ID submissions that do not meet our standards',
              fontSizeBody,
            ),
            
            // 5. Booking and Reservations
            _buildSection(
              '5. Booking and Reservations',
              '• Pre-booking is available for select routes and schedules\n'
              '• Reservations are subject to seat availability\n'
              '• Payment must be completed to confirm bookings\n'
              '• Cancellations must be made at least 2 hours before departure\n'
              '• No-shows may result in booking restrictions',
              fontSizeBody,
            ),
            
            // 6. Ticketing and Fares
            _buildSection(
              '6. Ticketing and Fares',
              '• Fares are calculated based on distance and passenger type\n'
              '• Discounts apply to verified Student, Senior Citizen, and PWD IDs\n'
              '• Fare prices are subject to change without prior notice\n'
              '• Tickets are non-transferable and non-refundable unless cancelled\n'
              '• Multiple passengers can be booked in a single transaction',
              fontSizeBody,
            ),
            
            // 7. Conduct and Safety
            _buildSection(
              '7. Conduct and Safety',
              '• Passengers must follow all safety regulations and driver instructions\n'
              '• Smoking, alcohol consumption, and disruptive behavior are prohibited\n'
              '• Passengers must wear seatbelts when available\n'
              '• Children under 12 must be accompanied by an adult\n'
              '• B-Go reserves the right to refuse service to unruly passengers',
              fontSizeBody,
            ),
            
            // 8. Privacy and Data Protection
            _buildSection(
              '8. Privacy and Data Protection',
              '• We collect and process personal data in accordance with our Privacy Policy\n'
              '• ID images are stored securely and used only for verification purposes\n'
              '• Location data may be collected for service improvement\n'
              '• We do not sell or share personal information with third parties\n'
              '• Users can request data deletion through our support channels',
              fontSizeBody,
            ),
            
            // 9. Service Availability
            _buildSection(
              '9. Service Availability',
              '• Services are subject to weather conditions and road safety\n'
              '• B-Go is not liable for delays due to traffic, weather, or unforeseen circumstances\n'
              '• Real-time tracking is provided as-is and may have delays\n'
              '• Service routes and schedules may be modified without notice\n'
              '• We strive to maintain service quality but cannot guarantee uninterrupted service',
              fontSizeBody,
            ),
            
            // 10. Payment Terms
            _buildSection(
              '10. Payment Terms',
              '• All payments are processed securely through our payment partners\n'
              '• Accepted payment methods include cash, mobile payments, and digital wallets\n'
              '• Receipts are provided electronically for all transactions\n'
              '• Disputed charges must be reported within 7 days\n'
              '• Refunds are processed according to our cancellation policy',
              fontSizeBody,
            ),
            
            // 11. Liability and Disclaimers
            _buildSection(
              '11. Liability and Disclaimers',
              '• B-Go provides transportation services but is not liable for personal injury or property damage\n'
              '• Passengers are responsible for their personal belongings\n'
              '• We are not liable for indirect, incidental, or consequential damages\n'
              '• Our liability is limited to the amount paid for the specific service\n'
              '• Force majeure events may affect service availability',
              fontSizeBody,
            ),
            
            // 12. Intellectual Property
            _buildSection(
              '12. Intellectual Property',
              '• The B-Go app, logo, and content are protected by copyright and trademark laws\n'
              '• Users may not copy, modify, or distribute our intellectual property\n'
              '• User-generated content remains the property of the user\n'
              '• We may use anonymized data for service improvement',
              fontSizeBody,
            ),
            
            // 13. Termination
            _buildSection(
              '13. Termination',
              '• Users may terminate their account at any time\n'
              '• B-Go may suspend or terminate accounts for violations of these terms\n'
              '• Account termination does not affect completed transactions\n'
              '• Outstanding payments must be settled before account closure',
              fontSizeBody,
            ),
            
            // 14. Changes to Terms
            _buildSection(
              '14. Changes to Terms',
              '• We may update these terms periodically\n'
              '• Users will be notified of significant changes\n'
              '• Continued use of the service constitutes acceptance of updated terms\n'
              '• Users may terminate their account if they disagree with changes',
              fontSizeBody,
            ),
            
            // 15. Contact Information
            _buildSection(
              '15. Contact Information',
              'For questions, concerns, or support regarding these terms, please contact us:\n\n'
              'Email: support@b-go.com\n'
              'Phone: +63 912 345 6789\n'
              'Address: B-Go Transportation Services, Batangas, Philippines\n\n'
              'Last updated: July 2025',
              fontSizeBody,
            ),
            
            SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                'By using the B-Go application, you acknowledge that you have read and agree to these Terms and Conditions.',
                style: GoogleFonts.outfit(
                  fontSize: fontSizeBody * 0.9,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, double fontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0091AD),
          ),
        ),
        SizedBox(height: 8),
        Text(
          content,
          style: GoogleFonts.outfit(
            fontSize: fontSize * 0.9,
            color: Colors.black87,
            height: 1.4,
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }
}
