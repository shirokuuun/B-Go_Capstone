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
  int? selectedIndex; // Track which role is selected
  
  final List<Map<String, dynamic>> roles = [
    {
      'name': 'Passenger',
      'description': 'Track buses in real time and ride with ease.',
      'icon': Icons.person,
      'color': Color(0xFF0091AD), // Teal color
    },
    {
      'name': 'Bus Reservation',
      'description': 'Manage trips, seats, and schedules seamlessly.',
      'icon': Icons.directions_bus,
      'color': Color(0xFF0091AD), // Teal color
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    
    // Get screen dimensions
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Responsive sizing
    final titleFontSize = isMobile ? 24.0 : isTablet ? 28.0 : 32.0;
    final containerWidth = isMobile ? 0.85 : isTablet ? 0.7 : 0.6;
    // Slightly bigger for small screens to prevent overflow - 150px
    final containerHeight = screenHeight < 700 ? 130.0 : (isMobile ? 120.0 : isTablet ? 150.0 : 160.0);
    final iconSize = isMobile ? 40.0 : isTablet ? 48.0 : 56.0;
    final sparkleSize = isMobile ? 16.0 : isTablet ? 20.0 : 24.0;
    final circleSize = isMobile ? 24.0 : isTablet ? 28.0 : 32.0;
    final buttonHeight = isMobile ? 50.0 : isTablet ? 56.0 : 60.0;
    final buttonFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final bottomPadding = isMobile ? 16.0 : 24.0;
    
    return PopScope(
      canPop: false, // This disables the back button
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20.0 : 32.0,
              vertical: isMobile ? 20.0 : 32.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Role selection containers
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title section - positioned above Passenger container
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: MediaQuery.of(context).size.width * ((1 - containerWidth) / 2),
                            bottom: 12,
                          ),
                          child: Text(
                            'Choose your role below',
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      ),
                      // Passenger option
                      _buildRoleContainer(
                        context,
                        roles[0],
                        0, // index
                        containerWidth,
                        containerHeight,
                        iconSize,
                        sparkleSize,
                        circleSize,
                        isMobile,
                        screenHeight,
                        () {
                          setState(() {
                            selectedIndex = 0;
                          });
                        },
                      ),
                      
                      // "or" separator
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: screenHeight < 700 ? 8.0 : 12.0),
                        child: Text(
                          'or',
                          style: TextStyle(
                            fontSize: titleFontSize * 0.8,
                            color: Colors.black,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                      
                      // Bus Reservation option
                      _buildRoleContainer(
                        context,
                        roles[1],
                        1, // index
                        containerWidth,
                        containerHeight,
                        iconSize,
                        sparkleSize,
                        circleSize,
                        isMobile,
                        screenHeight,
                        () {
                          setState(() {
                            selectedIndex = 1;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                
                // Continue button
                Padding(
                  padding: EdgeInsets.only(
                    bottom: isMobile ? 20.0 : 32.0,
                    top: bottomPadding,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.6,
                      height: buttonHeight,
                      child: ElevatedButton(
                        onPressed: selectedIndex != null ? _handleContinue : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedIndex != null 
                              ? Color(0xFF0091AD) 
                              : Colors.grey.shade300,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: selectedIndex != null ? 4 : 0,
                        ),
                        child: Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: buttonFontSize,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleContinue() {
    if (selectedIndex != null) {
      if (selectedIndex == 0) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(role: roles[0]['name']),
          ),
        );
      } else if (selectedIndex == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BusHome()),
        );
      }
    }
  }

  Widget _buildRoleContainer(
    BuildContext context,
    Map<String, dynamic> role,
    int index,
    double containerWidth,
    double containerHeight,
    double iconSize,
    double sparkleSize,
    double circleSize,
    bool isMobile,
    double screenHeight,
    VoidCallback onTap,
  ) {
    final isSelected = selectedIndex == index;
    // Adjust font sizes for small screens - slightly bigger now
    final titleSize = screenHeight < 700 ? 17.0 : (isMobile ? 18.0 : 22.0);
    final descSize = screenHeight < 700 ? 13.0 : (isMobile ? 14.0 : 16.0);
    final adjustedIconSize = screenHeight < 700 ? 40.0 : iconSize;
    final adjustedCircleSize = screenHeight < 700 ? 24.0 : circleSize;
    final padding = screenHeight < 700 ? 30.0 : (isMobile ? 16.0 : 20.0);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width * containerWidth,
        height: containerHeight is double ? containerHeight : MediaQuery.of(context).size.height * containerHeight,
        decoration: BoxDecoration(
          color: role['color'],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.5), 
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? Colors.black.withOpacity(0.2)
                  : Colors.black.withOpacity(0.1),
              blurRadius: isSelected ? 12 : 8,
              offset: Offset(0, isSelected ? 6 : 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Selection circle in top right corner
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                width: adjustedCircleSize,
                height: adjustedCircleSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Color(0xFF0091AD) : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: Color(0xFF0091AD),
                        size: adjustedCircleSize * 0.6,
                      )
                    : null,
              ),
            ),
            
            // Main content
            Padding(
              padding: EdgeInsets.all(padding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Person illustration (icon)
                  Container(
                    width: adjustedIconSize,
                    height: adjustedIconSize,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      role['icon'],
                      size: adjustedIconSize * 0.6,
                      color: Colors.white,
                    ),
                  ),
                  
                  SizedBox(width: 16),
                  
                  // Text content - Using Flexible to prevent overflow
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          role['name'],
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Outfit',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          role['description'],
                          style: TextStyle(
                            fontSize: descSize,
                            color: Colors.white.withOpacity(0.9),
                            fontFamily: 'Outfit',
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}