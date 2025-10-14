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
  bool _obscurePassword = true;

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0091AD),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'OK',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Validate empty fields
    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog(
        'Login Error',
        'Please enter both email and password.',
      );
      return;
    }

    try {
      // Use Firebase Auth for sign-in
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Only work with conductors that have uid field (created via admin website)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorDialog(
          'Authentication Error',
          'Authentication failed. Please try again.',
        );
        return;
      }

      final query = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _showErrorDialog(
          'Account Not Found',
          'No conductor record found. This conductor must be created via the admin website.',
        );
        return;
      }

      // Navigate to auth check - it will handle the routing automatically
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/auth_check');
      
    } on FirebaseAuthException catch (e) {
      String errorTitle = 'Login Error';
      String errorMessage = 'An error occurred. Please try again.';

      // Handle specific Firebase Auth error codes
      switch (e.code) {
        case 'user-not-found':
          errorTitle = 'Email Not Found';
          errorMessage = 'No account found with this email address.';
          break;
        case 'wrong-password':
          errorTitle = 'Incorrect Password';
          errorMessage = 'The password you entered is incorrect.';
          break;
        case 'invalid-email':
          errorTitle = 'Invalid Email';
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          errorTitle = 'Account Disabled';
          errorMessage = 'This account has been disabled.';
          break;
        case 'invalid-credential':
          errorTitle = 'Invalid Credentials';
          errorMessage = 'The supplied auth credential is incorrect, malformed or has expired.';
          break;
        case 'too-many-requests':
          errorTitle = 'Too Many Attempts';
          errorMessage = 'Too many failed login attempts. Please try again later.';
          break;
        default:
          errorMessage = e.message ?? 'Login failed. Please try again.';
      }

      _showErrorDialog(errorTitle, errorMessage);
    } catch (e) {
      print("Error fetching conductor data: $e");
      _showErrorDialog(
        'Error',
        'Failed to fetch conductor data. Please try again.',
      );
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: isMobile ? 20.0 : isTablet ? 25.0 : 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo section - now scrollable
              SizedBox(height: isMobile ? 40.0 : isTablet ? 50.0 : 60.0),
              Image.asset(
                'assets/batrasco-logo.png',
                width: logoSize,
                fit: BoxFit.contain,
              ),
              SizedBox(height: isMobile ? 40.0 : isTablet ? 50.0 : 60.0),

              // Login form content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Login title
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

                  // Email field
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding * 0.9),
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

                  // Password field
                  SizedBox(height: fieldSpacing),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding * 0.9),
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

                  // Login button
                  SizedBox(height: fieldSpacing),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding * 0.9),
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
                  
                  SizedBox(height: isMobile ? 50.0 : isTablet ? 60.0 : 70.0),

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
                          padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                          minimumSize: Size(0, 0),
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
                  
                  // Add bottom padding
                  SizedBox(height: isMobile ? 30.0 : 40.0),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}