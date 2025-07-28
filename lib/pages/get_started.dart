import 'package:flutter/material.dart';
import 'package:b_go/auth/main_page.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
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
                      top: _spread ? 10 : 200,
                      left: _spread ? 5 : 150,
                      child: Image.asset(
                        _miniImages[_currentIndex][0],
                        key: ValueKey('${_currentIndex}_topLeft'),
                        height: 80,
                      ),
                    ),

                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      top: _spread ? 10 : 200,
                      right: _spread ? 5 : 150,
                      child: Image.asset(
                        _miniImages[_currentIndex][1],
                        key: ValueKey('${_currentIndex}_topRight'),
                        height: 80,
                      ),
                    ),

                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      bottom: _spread ? 40 : 200,
                      left: _spread ? 5 : 150,
                      child: Image.asset(
                        _miniImages[_currentIndex][2],
                        key: ValueKey('${_currentIndex}_bottomLeft'),
                        height: 80,
                      ),
                    ),

                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      bottom: _spread ? 40 : 200,
                      right: _spread ? 5 : 150,
                      child: Image.asset(
                        _miniImages[_currentIndex][3],
                        key: ValueKey('${_currentIndex}_bottomRight'),
                        height: 80,
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
                            height: 200,
                            width: 200,
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
              margin:
                  const EdgeInsets.only(top: 10), // Adjust this value as needed
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  Text(
                    'B-Go',
                    style: GoogleFonts.outfit(
                      fontSize: 60,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Travel with Confidence',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // Get Started button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MainPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(55),
                  backgroundColor: const Color(0xFF007A8F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Get Started',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
