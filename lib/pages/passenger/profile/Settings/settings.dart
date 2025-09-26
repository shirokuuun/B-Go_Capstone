import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // App color palette
    final primaryTeal = const Color(0xFF0091AD);
    final secondaryTeal = const Color(0xFF007A8F);
    final lightTeal = const Color(0xFFE0F7FA);
    
    final options = [
      _SettingsOption('Pre-Ticket QRs', Icons.confirmation_num),
      _SettingsOption('Reservation Confirmations', Icons.event_available),
      _SettingsOption('Help Center / FAQs', Icons.help_outline),
      _SettingsOption('Privacy Policy', Icons.groups),
      _SettingsOption('About', Icons.info_outline),
      _SettingsOption('ID Verification', Icons.badge),
    ];

    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    // Responsive sizing
    final appBarFontSize = isMobile
        ? 18.0
        : isTablet
            ? 20.0
            : 24.0;
    final titleFontSize = isMobile
        ? 15.0
        : isTablet
            ? 16.0
            : 18.0;
    final iconSize = isMobile
        ? 22.0
        : isTablet
            ? 24.0
            : 28.0;
    final trailingIconSize = isMobile
        ? 18.0
        : isTablet
            ? 20.0
            : 24.0;

    // Responsive padding and spacing
    final horizontalPadding = isMobile
        ? 16.0
        : isTablet
            ? 20.0
            : 32.0;
    final verticalPadding = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;
    final listItemPadding = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: iconSize),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: appBarFontSize,
          ),
        ),
      ),
      body: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        itemCount: options.length,
        itemBuilder: (context, i) {
          final opt = options[i];
          final isFirstItem = i == 0;
          
          return Container(
            color: isFirstItem ? lightTeal : Colors.white,
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: listItemPadding,
              ),
              leading: Icon(
                opt.icon,
                color: primaryTeal,
                size: iconSize,
              ),
              title: Text(
                opt.title,
                style: GoogleFonts.outfit(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: primaryTeal,
                size: trailingIconSize,
              ),
              onTap: () {
                if (opt.title == 'Pre-Ticket QRs') {
                  Navigator.pushNamed(context, '/pre_ticket_qr');
                } else if (opt.title == 'Reservation Confirmations') {
                  Navigator.pushNamed(context, '/reservation_confirm');
                } else if (opt.title == 'Help Center / FAQs') {
                  Navigator.pushNamed(context, '/help_center');
                } else if (opt.title == 'Privacy Policy') {
                  Navigator.pushNamed(context, '/privacy_policy');
                } else if (opt.title == 'About') {
                  Navigator.pushNamed(context, '/about');
                } else if (opt.title == 'ID Verification') {
                  Navigator.pushNamed(context, '/id_verification');
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _SettingsOption {
  final String title;
  final IconData icon;
  const _SettingsOption(this.title, this.icon);
}

