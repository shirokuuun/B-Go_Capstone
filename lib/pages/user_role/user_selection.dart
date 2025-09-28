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
    
    // Responsive sizing
    final titleFontSize = isMobile ? 24.0 : isTablet ? 28.0 : 32.0;
    final containerWidth = isMobile ? 0.85 : isTablet ? 0.7 : 0.6;
    final containerHeight = isMobile ? 0.15 : isTablet ? 0.12 : 0.1;
    final iconSize = isMobile ? 40.0 : isTablet ? 48.0 : 56.0;
    final sparkleSize = isMobile ? 16.0 : isTablet ? 20.0 : 24.0;
    final circleSize = isMobile ? 24.0 : isTablet ? 28.0 : 32.0;
    final buttonHeight = isMobile ? 50.0 : isTablet ? 56.0 : 60.0;
    final buttonFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    
    return PopScope(
      canPop: false, // This disables the back button
      child: Scaffold(
      //  backgroundColor: Color(0xFFF5F5DC), // Light beige background
      backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 20.0 : 32.0),
            child: Column(
              children: [
                // Title section
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text(
                      'Choose your role below',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    SizedBox(width: 8),
                  ],
                ),
                
                // Role selection containers
                Expanded(
                  
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                        () {
                          setState(() {
                            selectedIndex = 0;
                          });
                        },
                      ),
                      
                      // "or" separator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 8),
                          Text(
                            'or',
                            style: TextStyle(
                              fontSize: titleFontSize * 0.8,
                              color: Colors.black,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
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
                    top: isMobile ? 16.0 : 24.0,
                  ),
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
    VoidCallback onTap,
  ) {
    final isSelected = selectedIndex == index;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width * containerWidth,
        height: MediaQuery.of(context).size.height * containerHeight,
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
                width: circleSize,
                height: circleSize,
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
                        size: circleSize * 0.6,
                      )
                    : null,
              ),
            ),
            
            // Main content
            Padding(
              padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
              child: Row(
                children: [
                  // Person illustration (icon)
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      role['icon'],
                      size: iconSize * 0.6,
                      color: Colors.white,
                    ),
                  ),
                  
                  SizedBox(width: 16),
                  
                  // Text content
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role['name'],
                          style: TextStyle(
                            fontSize: isMobile ? 18.0 : 22.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        Text(
                          role['description'],
                          style: TextStyle(
                            fontSize: isMobile ? 14.0 : 16.0,
                            color: Colors.white.withOpacity(0.9),
                            fontFamily: 'Outfit',
                          ),
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
