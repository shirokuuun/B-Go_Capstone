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
    'assets/bus.png',
    'assets/bus2.png',
  ];

  final List<List<String>> _miniImages = [
    [
      'assets/ticket.png',
      'assets/gps.png',
      'assets/signal.png',
      'assets/highway-sign.png',
    ],
    [
      'assets/work.png',
      'assets/passenger.png',
      'assets/bag.png',
      'assets/bus-stop.png'
    ],
  ];

  int _currentIndex = 0;
  Timer? _timer;
  bool _spread = false;

  @override
  void initState() {
    super.initState();

    // Initial spread
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _spread = true;
      });
    });

    _timer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!mounted) return;

      // Step 1: Pull icons back to center
      setState(() {
        _spread = false;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Step 2: Slide to next image
      final newIndex = (_currentIndex + 1) % _images.length;

      await _pageController.animateToPage(
        newIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );

      if (!mounted) return;

      // Step 3: Set current index AFTER animation completes
      setState(() {
        _currentIndex = newIndex;
        _spread = true;
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
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final isDesktop = ResponsiveBreakpoints.of(context).isDesktop;
    
    // Responsive sizing
    final titleFontSize = isMobile ? 60.0 : isTablet ? 72.0 : 84.0;
    final subtitleFontSize = isMobile ? 22.0 : isTablet ? 26.0 : 30.0;
    final buttonFontSize = isMobile ? 20.0 : isTablet ? 22.0 : 24.0;
    final buttonHeight = isMobile ? 55.0 : isTablet ? 60.0 : 65.0;
    final iconSize = isMobile ? 80.0 : isTablet ? 100.0 : 120.0;
    final centerImageSize = isMobile ? 200.0 : isTablet ? 250.0 : 300.0;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: isMobile ? 30 : 40),
            // Slideshow with corner icons
            Expanded(
              flex: 7,
              child: Center(
                child: Stack(
                  children: [
                    // Floating product images (replace with your actual paths or assets)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      top: _spread ? (isMobile ? 10 : 20) : (isMobile ? 200 : 250),
                      left: _spread ? (isMobile ? 5 : 10) : (isMobile ? 150 : 200),
                      child: Image.asset(
                        _miniImages[_currentIndex][0],
                        key: ValueKey('${_currentIndex}_topLeft'),
                        height: iconSize,
                      ),
                    ),

                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      top: _spread ? (isMobile ? 10 : 20) : (isMobile ? 200 : 250),
                      right: _spread ? (isMobile ? 5 : 10) : (isMobile ? 150 : 200),
                      child: Image.asset(
                        _miniImages[_currentIndex][1],
                        key: ValueKey('${_currentIndex}_topRight'),
                        height: iconSize,
                      ),
                    ),

                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      bottom: _spread ? (isMobile ? 40 : 60) : (isMobile ? 200 : 250),
                      left: _spread ? (isMobile ? 5 : 10) : (isMobile ? 150 : 200),
                      child: Image.asset(
                        _miniImages[_currentIndex][2],
                        key: ValueKey('${_currentIndex}_bottomLeft'),
                        height: iconSize,
                      ),
                    ),

                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      bottom: _spread ? (isMobile ? 40 : 60) : (isMobile ? 200 : 250),
                      right: _spread ? (isMobile ? 5 : 10) : (isMobile ? 150 : 200),
                      child: Image.asset(
                        _miniImages[_currentIndex][3],
                        key: ValueKey('${_currentIndex}_bottomRight'),
                        height: iconSize,
                      ),
                    ),

                    Align(
                      alignment: Alignment.center,
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _images.length,
                        itemBuilder: (context, index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeInOut,
                            height: centerImageSize,
                            width: centerImageSize,
                            child: Image.asset(
                              _images[index],
                              fit: BoxFit.contain,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Title and subtitle to match the screenshot
            Container(
              margin: EdgeInsets.only(top: isMobile ? 10 : 20),
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 20),
              child: Column(
                children: [
                  Text(
                    'B-Go',
                    style: GoogleFonts.outfit(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isMobile ? 5 : 10),
                  Text(
                    'Travel with Confidence',
                    style: GoogleFonts.outfit(
                      fontSize: subtitleFontSize,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            SizedBox(height: isMobile ? 25 : 35),

            // Get Started button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 30 : 40),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MainPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.fromHeight(buttonHeight),
                  backgroundColor: const Color(0xFF007A8F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Get Started',
                  style: GoogleFonts.outfit(
                    fontSize: buttonFontSize,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            SizedBox(height: isMobile ? 50 : 60),
          ],
        ),
      ),
    );
  }
}
