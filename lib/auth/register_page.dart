import 'package:b_go/auth/auth_services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:b_go/pages/terms_and_conditions_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:responsive_framework/responsive_framework.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback showLoginPage;

  const RegisterPage({
    Key? key,
    required this.showLoginPage,
  }) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // text controller
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final AuthServices _authServices = AuthServices();

  bool agreedToTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> signUp() async {
    if (!agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('You must agree to the Terms and Conditions to sign up.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final errorMessage = await _authServices.signUpWithEmail(
      name: nameController.text,
      email: emailController.text,
      password: passwordController.text,
      confirmPassword: confirmPasswordController.text,
    );

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // If registration is successful, send verification email
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Verify your email',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'A verification link has been sent to ${user.email}. Please verify your email before logging in.',
              style: GoogleFonts.outfit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'OK',
                  style: GoogleFonts.outfit(
                    color: Color(0xFF0091AD),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

        // Sign out user after registration (they need to verify email first)
        await _authServices.signOut();
        
        // Clear form fields
        nameController.clear();
        emailController.clear();
        passwordController.clear();
        confirmPasswordController.clear();
        setState(() {
          agreedToTerms = false;
        });
        
        // Navigate back to login page
        widget.showLoginPage();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification email. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
          // register form
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: Container(
                margin: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.24),
                width: double.infinity,

                padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding, 
                    vertical: isMobile ? 32.0 : isTablet ? 36.0 : 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Hello!",
                            style: GoogleFonts.outfit(
                              fontSize: titleFontSize,
                            ),
                          ),
                          Text(
                            "Register Here!",
                            style: GoogleFonts.outfit(
                              fontSize: subtitleFontSize,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                            controller: nameController,
                            style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontSize: textFieldFontSize,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: "Enter your full name",
                              hintStyle: GoogleFonts.outfit(
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                                fontSize: hintFontSize,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
                            controller: emailController,
                            style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontSize: textFieldFontSize,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: "Email Address",
                              hintStyle: GoogleFonts.outfit(
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                                fontSize: hintFontSize,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
                                fontSize: hintFontSize,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
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
                            controller: confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            style: GoogleFonts.outfit(
                              color: Colors.black,
                              fontSize: textFieldFontSize,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: "Confirm your Password",
                              hintStyle: GoogleFonts.outfit(
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                                fontSize: hintFontSize,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword = !_obscureConfirmPassword;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding * 0.9),
                      child: Row(
                        children: [
                          Checkbox(
                            value: agreedToTerms,
                            onChanged: (bool? value) {
                              setState(() {
                                agreedToTerms = value ?? false;
                              });
                            },
                          ),
                          Flexible(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.outfit(
                                  color: Colors.black,
                                  fontSize: hintFontSize,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'I agree to the ',
                                  ),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                TermsAndConditionsPage(
                                                    showRegisterPage: () {}),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Terms and Conditions',
                                        style: GoogleFonts.outfit(
                                          color: Colors.blue,
                                          decoration: TextDecoration.underline,
                                          fontSize: hintFontSize,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isMobile ? 8.0 : isTablet ? 10.0 : 12.0),

                    // Add phone registration button
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding * 0.9),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(context, '/phone_register');
                            },
                            child: Text(
                              'Use Phone Number',
                              style: GoogleFonts.outfit(
                                color: Color(0xFF1D2B53),
                                fontWeight: FontWeight.w500,
                                fontSize: hintFontSize,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isMobile ? 8.0 : isTablet ? 10.0 : 12.0),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding * 0.9),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0091AD),
                          minimumSize: Size(double.infinity, isMobile ? 50.0 : isTablet ? 55.0 : 60.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: agreedToTerms
                            ? () {
                                signUp();
                              }
                            : null,
                        child: Text(
                          'Sign Up',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: buttonFontSize,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 25.0 : isTablet ? 28.0 : 30.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account?',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w500,
                            fontSize: registerFontSize,
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.showLoginPage,
                          child: Text(
                            ' Login',
                            style: GoogleFonts.outfit(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                              fontSize: registerFontSize,
                            ),
                          ),
                        )
                      ],
                    ),
                    SizedBox(height: 7),
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