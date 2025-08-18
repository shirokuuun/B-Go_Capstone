import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';

class PassengerService extends StatelessWidget {
  const PassengerService({super.key});

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final isDesktop = ResponsiveBreakpoints.of(context).isDesktop;
    
    // Responsive sizing
    final titleFontSize = isMobile ? 20.0 : isTablet ? 22.0 : 24.0;
    final cardTitleFontSize = isMobile ? 24.0 : isTablet ? 28.0 : 32.0;
    final cardSubtitleFontSize = isMobile ? 14.0 : isTablet ? 16.0 : 18.0;
    final orFontSize = isMobile ? 24.0 : isTablet ? 28.0 : 32.0;
    final iconSize = isMobile ? 80.0 : isTablet ? 100.0 : 120.0;
    final horizontalPadding = isMobile ? 24.0 : isTablet ? 32.0 : 40.0;
    final verticalPadding = isMobile ? 16.0 : isTablet ? 20.0 : 24.0;
    final cardVerticalPadding = isMobile ? 32.0 : isTablet ? 40.0 : 48.0;
    final spacing = isMobile ? 16.0 : isTablet ? 20.0 : 24.0;
    final smallSpacing = isMobile ? 4.0 : isTablet ? 6.0 : 8.0;
    final orSpacing = isMobile ? 8.0 : isTablet ? 12.0 : 16.0;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Services",
          style: GoogleFonts.outfit(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0091AD),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
      ),
      body: Material(
        child: Container(
          color: Color(0xFFF3F3F3),
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pre-Ticketing Card
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding, vertical: verticalPadding),
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(context, '/pre_ticket');
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: cardVerticalPadding),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.confirmation_num_outlined,
                            size: iconSize, color: Colors.black),
                        SizedBox(height: spacing),
                        Text(
                          'Pre-Ticketing',
                          style: GoogleFonts.outfit(
                            fontSize: cardTitleFontSize,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: smallSpacing),
                        Text(
                          '(Boarding)',
                          style: GoogleFonts.outfit(
                            fontSize: cardSubtitleFontSize,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // OR text
              Padding(
                padding: EdgeInsets.symmetric(vertical: orSpacing),
                child: Text(
                  'OR',
                  style: GoogleFonts.outfit(
                    fontSize: orFontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
              // Pre-Booking Card
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding, vertical: verticalPadding),
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Pre-Booking Notice'),
                        content: Text(
                          'By using Pre-Booking, you are reserving a guaranteed seat for the entire trip (from the starting point to the last stop). The payment is fixed for the full route. Do you want to continue?',
                          style: GoogleFonts.outfit(
                            fontSize: isMobile ? 14 : 16,
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.outfit(
                                fontSize: isMobile ? 16 : 18,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF0091AD),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.pushNamed(context, '/pre_book');
                            },
                            child: Text(
                              'Continue',
                              style: GoogleFonts.outfit(
                                fontSize: isMobile ? 16 : 18,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: cardVerticalPadding),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_note_outlined,
                            size: iconSize, color: Colors.black),
                        SizedBox(height: spacing),
                        Text(
                          'Pre-Booking',
                          style: GoogleFonts.outfit(
                            fontSize: cardTitleFontSize,
                            fontWeight: FontWeight.w500,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: smallSpacing),
                        Text(
                          '(Reservation)',
                          style: GoogleFonts.outfit(
                            fontSize: cardSubtitleFontSize,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
