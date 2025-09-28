import 'package:flutter/material.dart';
import 'package:b_go/pages/conductor/conductor_home.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'dart:math' as math;

class ConductorLogin extends StatefulWidget {
  const ConductorLogin({super.key});

  @override
  State<ConductorLogin> createState() => _ConductorLoginState();
}

class _ConductorLoginState extends State<ConductorLogin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;
  bool _obscurePassword = true;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      // Use Firebase Auth for sign-in
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      setState(() {
        _errorMessage = null;
      });

      // Only work with conductors that have uid field (created via admin website)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Authentication failed. Please try again.';
        });
        return;
      }

      final query = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        setState(() {
          _errorMessage =
              'No conductor record found. This conductor must be created via the admin website.';
        });
        return;
      }

      final doc = query.docs.first;
      final data = doc.data();
      final route = data['route'] ?? '';
      final placeCollection = data['placeCollection'] ?? 'Place';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ConductorHome(
            role: 'Conductor',
            route: route,
            placeCollection: placeCollection,
            selectedIndex: 0,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Login failed. Please try again.';
      });
    } catch (e) {
      print("Error fetching conductor data: $e");
      setState(() {
        _errorMessage = 'Failed to fetch conductor route.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    
    // Responsive sizing
    final logoSize = isMobile ? 120.0 : isTablet ? 140.0 : 150.0;
    final titleFontSize = isMobile ? 35.0 : isTablet ? 40.0 : 45.0;
    final subtitleFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final buttonFontSize = isMobile ? 18.0 : isTablet ? 19.0 : 20.0;
    final textFieldFontSize = isMobile ? 14.0 : isTablet ? 15.0 : 16.0;
    final hintFontSize = isMobile ? 12.0 : isTablet ? 13.0 : 14.0;
    final registerFontSize = isMobile ? 13.0 : isTablet ? 13.0 : 14.0;
    
    // Responsive padding and spacing
    final horizontalPadding = isMobile ? 20.0 : isTablet ? 24.0 : 28.0;
    final fieldSpacing = isMobile ? 20.0 : isTablet ? 25.0 : 30.0;
    final buttonPadding = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final containerPadding = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    
    return Scaffold(
      backgroundColor: Color(0xFFE5E9F0),
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.38,
            decoration: BoxDecoration(
              color: Color(0xFFE5E9F0),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double maxLogoWidth = 400.0; // Adjust this value as needed
                double logoWidth = logoSize;
                math.min(constraints.maxWidth * 0.4, maxLogoWidth);
                // Use Center to make sure the logo always stays in the middle, even if alignment changes
                return Transform.translate(
                  offset: Offset(0, -20),
                  child: Center(
                    child: Image.asset(
                      'assets/batrasco-logo.png',
                      width: logoWidth,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),

          // --- LOGIN BOX ---
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: Container(
                margin: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.24),
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: isMobile
                        ? 32.0
                        : isTablet
                            ? 36.0
                            : 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        height: isMobile
                            ? 20.0
                            : isTablet
                                ? 25.0
                                : 30.0),
                    // --- LOGIN BOX ---
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Login",
                            style: GoogleFonts.outfit(
                              fontSize: titleFontSize,
                            ),
                          ),
                          Text(
                            "Welcome Back, Conductor!",
                            style: GoogleFonts.outfit(
                              fontSize: subtitleFontSize,
                              color: const Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: fieldSpacing),

                    // Email
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding * 0.9),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFE5E9F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade400,
                            width: 1.0,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(left: containerPadding),
                          child: TextField(
                            controller: _emailController,
                            style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontSize: textFieldFontSize,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: "Email",
                              hintStyle: GoogleFonts.outfit(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                  fontSize: hintFontSize),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Password
                    SizedBox(height: fieldSpacing),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding * 0.9),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFE5E9F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade400,
                            width: 1.0,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(left: containerPadding),
                          child: TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontSize: textFieldFontSize,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: "Password",
                              hintStyle: GoogleFonts.outfit(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                  fontSize: hintFontSize),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),

                    // Error message
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],

                    // Sign in button
                    SizedBox(height: fieldSpacing),
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding * 0.9),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0091AD),
                            padding: EdgeInsets.all(buttonPadding),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            _login();
                          },
                          child: Text(
                            'Login',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: buttonFontSize,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 280.0 : isTablet ? 290.0 : 295.0),

                    // Register section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Not a conductor? ",
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w500,
                            fontSize: registerFontSize,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/login');
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 4), // Increase tap area
                            minimumSize:
                                Size(0, 0), // Remove min size if needed
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            "Sign In",
                            style: GoogleFonts.outfit(
                              color: Color(0xFF0091AD),
                              fontWeight: FontWeight.w500,
                              fontSize: registerFontSize,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
