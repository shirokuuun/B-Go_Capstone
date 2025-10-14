import 'package:b_go/auth/auth_services.dart';
import 'package:b_go/pages/conductor/ticketing/conductor_from.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:b_go/auth/forgotPassword_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:b_go/auth/conductor_login.dart';
import 'package:responsive_framework/responsive_framework.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback showRegisterPage;
  const LoginPage({Key? key, required this.showRegisterPage}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  //text controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthServices _authServices = AuthServices();
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

  Future signIn() async {
    // Validate empty fields
    if (emailController.text.trim().isEmpty || passwordController.text.isEmpty) {
      _showErrorDialog(
        'Login Error',
        'Please enter both email and password.',
      );
      return;
    }

    try {
      await _authServices.signInWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final firestoreEmail = doc.data()?['email'];
        if (firestoreEmail != user.email) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'email': user.email,
          });
        }
      }

      if (user == null) return;

      // Only work with conductors that have uid field (created via admin website)
      final query = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (!mounted) return;

      if (query.docs.isNotEmpty) {
        final conductorData = query.docs.first.data();
        final route = conductorData['route'] ?? '';
        Navigator.pushReplacementNamed(context, '/auth_check');
        return;
      } else {
        // Not a conductor, navigate as a normal user
        Navigator.pushReplacementNamed(context, '/auth_check');
        return;
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      
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
        case 'email-not-verified':
          errorTitle = 'Email Not Verified';
          errorMessage = 'Please verify your email address before logging in.';
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
      if (!mounted) return;
      _showErrorDialog(
        'Error',
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    // Responsive sizing
    final logoSize = isMobile
        ? 120.0
        : isTablet
            ? 140.0
            : 150.0;
    final titleFontSize = isMobile
        ? 35.0
        : isTablet
            ? 40.0
            : 45.0;
    final subtitleFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final buttonFontSize = isMobile
        ? 18.0
        : isTablet
            ? 19.0
            : 20.0;
    final textFieldFontSize = isMobile
        ? 14.0
        : isTablet
            ? 15.0
            : 16.0;
    final hintFontSize = isMobile
        ? 12.0
        : isTablet
            ? 13.0
            : 14.0;
    final registerFontSize = isMobile
        ? 13.0
        : isTablet
            ? 13.0
            : 14.0;

    // Responsive padding and spacing
    final horizontalPadding = isMobile
        ? 20.0
        : isTablet
            ? 24.0
            : 28.0;
    final fieldSpacing = isMobile
        ? 20.0
        : isTablet
            ? 25.0
            : 30.0;
    final buttonPadding = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final containerPadding = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;

    return Scaffold(
      backgroundColor: Color(0xFFE5E9F0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: isMobile
                  ? 20.0
                  : isTablet
                      ? 25.0
                      : 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo section - now scrollable
              SizedBox(
                  height: isMobile
                      ? 40.0
                      : isTablet
                          ? 50.0
                          : 60.0),
              Image.asset(
                'assets/batrasco-logo.png',
                width: logoSize,
                fit: BoxFit.contain,
              ),
              SizedBox(
                  height: isMobile
                      ? 40.0
                      : isTablet
                          ? 50.0
                          : 60.0),

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
                          "Welcome Back!",
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
                          controller: emailController,
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
                          controller: passwordController,
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

                  // Forgot Password
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding * 0.9),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ForgotPasswordPage(),
                              ),
                            );
                          },
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                              fontSize: hintFontSize,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

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
                        onPressed: signIn,
                        child: Text(
                          'Sign In',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: buttonFontSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 25),

                  // Or divider
                  Row(
                    children: [
                      const Expanded(
                          child: Divider(
                              thickness: 1, color: Color(0xFF9B9B9B))),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: isMobile
                                ? 12.0
                                : isTablet
                                    ? 14.0
                                    : 16.0),
                        child: Text("Or login with",
                            style: GoogleFonts.outfit(
                                fontSize: isMobile
                                    ? 14.0
                                    : isTablet
                                        ? 15.0
                                        : 16.0,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400)),
                      ),
                      const Expanded(
                          child: Divider(
                              thickness: 1, color: Color(0xFF9B9B9B))),
                    ],
                  ),
                  SizedBox(
                      height: isMobile
                          ? 20.0
                          : isTablet
                              ? 22.0
                              : 25.0),

                  // Social login buttons
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: isMobile
                            ? 80.0
                            : isTablet
                                ? 90.0
                                : 100.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google Sign-In Button
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              try {
                                final userCredential =
                                    await _authServices.SignInWithGoogle();
                                if (userCredential == null) return;

                                // Handle successful Google Sign-In
                                if (!mounted) return;

                                final user = userCredential.user;
                                if (user != null) {
                                  // Check if user is a conductor
                                  String email = user.email!;
                                  String username = email.split('@').first;
                                  String conductorDocId =
                                      username[0].toUpperCase() +
                                          username.substring(1);

                                  final conductorDoc = await FirebaseFirestore
                                      .instance
                                      .collection('conductors')
                                      .doc(conductorDocId)
                                      .get();

                                  if (!mounted) return;

                                  // Navigate to auth check - it will handle routing
                                  Navigator.pushReplacementNamed(context, '/auth_check');
                                }
                              } catch (e) {
                                if (!mounted) return;
                                _showErrorDialog(
                                  'Google Sign-In Failed',
                                  'Unable to sign in with Google. Please try again.',
                                );
                              }
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 1),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: isMobile
                                        ? 45.0
                                        : isTablet
                                            ? 48.0
                                            : 50.0,
                                    height: isMobile
                                        ? 45.0
                                        : isTablet
                                            ? 48.0
                                            : 50.0,
                                    decoration: BoxDecoration(
                                      color: Color(0x579B9B9B),
                                      borderRadius:
                                          BorderRadius.circular(isMobile
                                              ? 22.5
                                              : isTablet
                                                  ? 24.0
                                                  : 25.0),
                                    ),
                                    child: Center(
                                      child: Image.asset(
                                        'assets/google-icon.png',
                                        width: isMobile
                                            ? 25.0
                                            : isTablet
                                                ? 28.0
                                                : 30.0,
                                        height: isMobile
                                            ? 25.0
                                            : isTablet
                                                ? 28.0
                                                : 30.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Phone Sign-In Button
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/phone_login');
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 1),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: isMobile
                                        ? 45.0
                                        : isTablet
                                            ? 48.0
                                            : 50.0,
                                    height: isMobile
                                        ? 45.0
                                        : isTablet
                                            ? 48.0
                                            : 50.0,
                                    decoration: BoxDecoration(
                                      color: Color(0x579B9B9B),
                                      borderRadius:
                                          BorderRadius.circular(isMobile
                                              ? 22.5
                                              : isTablet
                                                  ? 24.0
                                                  : 25.0),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.phone,
                                        size: isMobile
                                            ? 25.0
                                            : isTablet
                                                ? 28.0
                                                : 30.0,
                                        color: Colors.black,
                                      ),
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

                  SizedBox(
                      height: isMobile
                          ? 20.0
                          : isTablet
                              ? 22.0
                              : 25.0),

                  // Conductor Login Button
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding * 0.9),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFE5E9F0),
                          padding: EdgeInsets.all(isMobile
                              ? 10.0
                              : isTablet
                                  ? 11.0
                                  : 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ConductorLogin(),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.directions_bus,
                              color: Color(0xFF0091AD),
                              size: isMobile
                                  ? 18.0
                                  : isTablet
                                      ? 19.0
                                      : 20.0,
                            ),
                            SizedBox(
                                width: isMobile
                                    ? 6.0
                                    : isTablet
                                        ? 7.0
                                        : 8.0),
                            Text(
                              'Conductor Login',
                              style: GoogleFonts.outfit(
                                color: Color(0xFF0091AD),
                                fontSize: isMobile
                                    ? 14.0
                                    : isTablet
                                        ? 15.0
                                        : 16.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(
                      height: isMobile
                          ? 20.0
                          : isTablet
                              ? 22.0
                              : 25.0),

                  // Register section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w500,
                          fontSize: registerFontSize,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 4),
                          minimumSize: Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          "Sign Up",
                          style: GoogleFonts.outfit(
                            color: Color(0xFF0091AD),
                            fontWeight: FontWeight.w500,
                            fontSize: registerFontSize,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Add some bottom padding for better spacing
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