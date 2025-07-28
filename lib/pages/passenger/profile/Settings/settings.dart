import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cyan = const Color(0xFF0091AD);
    final options = [
      _SettingsOption('Pre-Ticket QRs', Icons.confirmation_num),
      _SettingsOption('Reservation Confirmations', Icons.event_available),
      _SettingsOption('Help Center / FAQs', Icons.help_outline),
      _SettingsOption('Privacy Policy', Icons.groups),
      _SettingsOption('About', Icons.info_outline),
      _SettingsOption('ID Verification', Icons.badge),
    ];

    final width = MediaQuery.of(context).size.width;
    final paddingH = width * 0.04; // 4% of width
    final paddingV = width * 0.06; // 6% of width
    final cardRadius = width * 0.03; // 3% of width
    final iconRadius = width * 0.07; // 7% of width
    final iconSize = width * 0.06; // 6% of width
    final fontSizeTitle = width * 0.045; // 4.5% of width
    final fontSizeAppBar = width * 0.05; // 5% of width

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: cyan,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: iconSize + 2),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: fontSizeAppBar,
          ),
        ),
      ),
      body: ListView.separated(
        padding: EdgeInsets.symmetric(vertical: paddingV, horizontal: paddingH),
        itemCount: options.length,
        separatorBuilder: (_, __) => SizedBox(height: width * 0.03),
        itemBuilder: (context, i) {
          final opt = options[i];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(cardRadius),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Color.fromARGB(255, 1, 123, 148),
                radius: iconRadius,
                child: Icon(opt.icon, color: Colors.white, size: iconSize),
              ),
              title: Text(
                opt.title,
                style: GoogleFonts.outfit(
                  fontSize: fontSizeTitle,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              trailing: Icon(Icons.chevron_right, color: Colors.black, size: iconSize + 6),
              onTap: () {
                if (opt.title == 'Pre-Ticket QRs') {
                  Navigator.pushNamed(context, '/pre_ticket_qr');
                } else if (opt.title == 'Reservation Confirmations') {
                  Navigator.pushNamed(context, '/reservation_confirmations');
                } else if (opt.title == 'Help Center / FAQs') {
                  Navigator.pushNamed(context, '/help_center');
                } else if (opt.title == 'Privacy Policy') {
                  Navigator.pushNamed(context, '/privacy_policy');
                } else if (opt.title == 'About') {
                  Navigator.pushNamed(context, '/about');
                } else if (opt.title == 'ID Verification') {
                  Navigator.pushNamed(context, '/id_verification');
                }
              }, // Add navigation if needed
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
