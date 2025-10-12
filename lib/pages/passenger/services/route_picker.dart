import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:b_go/pages/passenger/services/pre_ticket.dart';

class RoutePicker extends StatelessWidget {
  const RoutePicker({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // App color palette
    final primaryTeal = const Color(0xFF0091AD);

    final routes = [
      _RouteOption('Batangas', 'SM Lipa to Batangas City'),
      _RouteOption('Rosario', 'SM Lipa to Rosario'),
      _RouteOption('Mataas na Kahoy', 'SM Lipa to Mataas na Kahoy'),
      _RouteOption(
          'Mataas Na Kahoy Palengke', 'Lipa Palengke to Mataas na Kahoy'),
      _RouteOption('Tiaong', 'SM Lipa to Tiaong'),
      _RouteOption('San Juan', 'SM Lipa to San Juan'),
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
    final subtitleFontSize = isMobile
        ? 13.0
        : isTablet
            ? 14.0
            : 16.0;
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
          'Select Route',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: appBarFontSize,
          ),
        ),
      ),
      body: ListView.builder(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        itemCount: routes.length,
        itemBuilder: (context, i) {
          final route = routes[i];

          return Container(
            color: Colors.white,
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: listItemPadding,
              ),
              title: Text(
                route.routeName,
                style: GoogleFonts.outfit(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  route.displayName,
                  style: GoogleFonts.outfit(
                    fontSize: subtitleFontSize,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: primaryTeal,
                size: trailingIconSize,
              ),
              onTap: () {
                // Navigate to PreTicket with selected route
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PreTicket(selectedRoute: route.routeName),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RouteOption {
  final String routeName;
  final String displayName;
  const _RouteOption(this.routeName, this.displayName);
}
