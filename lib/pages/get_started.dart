import 'package:flutter/material.dart';
import 'package:b_go/auth/main_page.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';

class GetStartedPage extends StatefulWidget {
  const GetStartedPage({Key? key}) : super(key: key);

  @override
  State<GetStartedPage> createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage> {
  final PageController _pageController = PageController();
  final List<String> _images = [
    'assets/bus_portrait.jpg',
  ];

  int _currentIndex = 0;
  Timer? _timer;
  double _dragPosition = 0.0;
  final double _maxDragDistance = 200.0;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted) return;

      final newIndex = (_currentIndex + 1) % _images.length;

      await _pageController.animateToPage(
        newIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );

      if (!mounted) return;

      setState(() {
        _currentIndex = newIndex;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    final titleFontSize = isMobile ? 48.0 : isTablet ? 56.0 : 64.0;
    final subtitleFontSize = isMobile ? 18.0 : isTablet ? 20.0 : 22.0;
    final buttonFontSize = isMobile ? 18.0 : isTablet ? 20.0 : 22.0;

    return Scaffold(
      body: Stack(
        children: [
          // Full screen background image with PageView
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _images.length,
              itemBuilder: (context, index) {
                return Image.asset(
                  _images[index],
                  fit: BoxFit.cover,
                );
              },
            ),
          ),

          // Gradient overlay to ensure text readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Content on top
          SafeArea(
            child: Column(
              children: [
                Spacer(),

                // Title and subtitle section
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 30 : 40,
                  ),
                  child: Column(
                    children: [
                      // Title
                      Text(
                        'B-Go',
                        style: GoogleFonts.outfit(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                          shadows: [
                            Shadow(
                              offset: Offset(2, 2),
                              blurRadius: 8,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isMobile ? 12 : 16),

                      // Subtitle
                      Text(
                        'Travel with Confidence',
                        style: GoogleFonts.outfit(
                          fontSize: subtitleFontSize,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 4,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: isMobile ? 50 : 60),

                // Swipeable button
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 30 : 40,
                  ),
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _dragPosition += details.delta.dx;
                        // Clamp between 0 and max width
                        if (_dragPosition < 0) _dragPosition = 0;
                        if (_dragPosition > _maxDragDistance) {
                          _dragPosition = _maxDragDistance;
                        }
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      if (_dragPosition > _maxDragDistance * 0.7) {
                        // Successfully swiped - navigate
                        Navigator.pushReplacementNamed(context, '/auth_check');
                      } else {
                        // Reset position with animation
                        setState(() {
                          _dragPosition = 0.0;
                        });
                      }
                    },
                    child: Container(
                      height: isMobile ? 64 : 72,
                      decoration: BoxDecoration(
                        color: Color(0xFF0097A7),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF0097A7).withOpacity(0.3),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Animated arrow icon on the left that slides
                          AnimatedPositioned(
                            duration: Duration(milliseconds: _dragPosition == 0 ? 300 : 0),
                            curve: Curves.easeOut,
                            left: 8 + _dragPosition,
                            top: 8,
                            bottom: 8,
                            child: Container(
                              width: isMobile ? 48 : 56,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.arrow_forward,
                                color: Color(0xFF0097A7),
                                size: 24,
                              ),
                            ),
                          ),
                          // Text centered
                          Center(
                            child: Text(
                              'Swipe to get started',
                              style: GoogleFonts.outfit(
                                fontSize: buttonFontSize,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(height: isMobile ? 50 : 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}