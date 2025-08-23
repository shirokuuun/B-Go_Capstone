import 'package:b_go/pages/passenger/home_page.dart';
import 'package:flutter/material.dart';
import 'package:b_go/pages/bus_reserve/bus_reserve_pages/bus_home.dart';
import 'package:responsive_framework/responsive_framework.dart';

class UserSelection extends StatefulWidget {
  const UserSelection({super.key});

  @override
  State<UserSelection> createState() => _UserSelectionState();
}

class _UserSelectionState extends State<UserSelection> {
  final List<String> roles = ['Passenger', 'Bus Reservation'];
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final isDesktop = ResponsiveBreakpoints.of(context).isDesktop;
    
    // Responsive sizing
    final arrowSize = isMobile ? 48.0 : isTablet ? 56.0 : 64.0;
    final fontSize = isMobile ? 28.0 : isTablet ? 32.0 : 36.0;
    final containerWidth = isMobile ? 0.7 : isTablet ? 0.6 : 0.5;
    final containerHeight = isMobile ? 0.8 : isTablet ? 0.75 : 0.7;
    
    return PopScope(
      canPop: false, // This disables the back button
      child: Scaffold(
        body: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Left arrow (only show if not first)
              if (currentIndex > 0)
                IconButton(
                  icon: Icon(Icons.arrow_left, size: arrowSize),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      currentIndex--;
                    });
                  },
                )
              else
                SizedBox(width: arrowSize), // Placeholder for alignment

              // Role selection modal
              GestureDetector(
                onTap: () {
                  if (roles[currentIndex] == 'Passenger') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HomePage(role: roles[currentIndex]),
                      ),
                    );
                  } else if (roles[currentIndex] == 'Bus Reservation') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => BusHome()),
                    );
                  } 
                },
                child: Container(
                  width: MediaQuery.of(context).size.width * containerWidth,
                  height: MediaQuery.of(context).size.height * containerHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    roles[currentIndex],
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // Right arrow (only show if not last)
              if (currentIndex < roles.length - 1)
                IconButton(
                  icon: Icon(Icons.arrow_right, size: arrowSize),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      currentIndex++;
                    });
                  },
                )
              else
                SizedBox(width: arrowSize), // Placeholder for alignment
            ],
          ),
        ),
      ),
    );
  }
}
