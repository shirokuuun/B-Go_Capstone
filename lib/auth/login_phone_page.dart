import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:b_go/auth/auth_services.dart';
import 'package:b_go/auth/otp_verification_page.dart';
import 'dart:math' as math;

class LoginPhonePage extends StatefulWidget {
  const LoginPhonePage({Key? key}) : super(key: key);

  @override
  State<LoginPhonePage> createState() => _LoginPhonePageState();
}

class _LoginPhonePageState extends State<LoginPhonePage> {
  final TextEditingController phoneController = TextEditingController();
  final AuthServices _authServices = AuthServices();

  bool _isLoading = false;

  // Country code dropdown
  final List<Map<String, String>> countries = [
    {'name': 'Philippines', 'code': '+63'},
    {'name': 'United States', 'code': '+1'},
    {'name': 'India', 'code': '+91'},
    {'name': 'United Kingdom', 'code': '+44'},
    // Add more countries as needed
  ];
  String selectedCountryCode = '+63';

  @override
  void initState() {
    super.initState();
    // Add listener to phone controller to trigger rebuild when text changes
    phoneController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  // Custom snackbar widget
  void _showCustomSnackBar(String message, String type) {
    Color backgroundColor;
    IconData icon;
    Color iconColor;
    
    switch (type) {
      case 'success':
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        iconColor = Colors.white;
        break;
      case 'error':
        backgroundColor = Colors.red;
        icon = Icons.error;
        iconColor = Colors.white;
        break;
      case 'warning':
        backgroundColor = Colors.orange;
        icon = Icons.warning;
        iconColor = Colors.white;
        break;
      default:
        backgroundColor = Colors.grey;
        icon = Icons.info;
        iconColor = Colors.white;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 12,
                color: backgroundColor,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.all(16),
        action: SnackBarAction(
          label: '✕',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  Future<void> _sendOTP() async {
    String phone = phoneController.text.trim();
    if (phone.isEmpty) {
      _showCustomSnackBar('Please enter a phone number.', 'warning');
      return;
    }

    if (phone.startsWith('0')) phone = phone.substring(1);
    String fullPhone = selectedCountryCode + phone;

    // Check if phone number exists in Firestore before sending OTP
    bool isRegistered = await _authServices.isPhoneNumberRegistered(fullPhone);
    if (!isRegistered) {
      _showCustomSnackBar('This phone number is not registered. Please register first.', 'error');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            setState(() => _isLoading = false);
            Navigator.pushReplacementNamed(context, '/user_selection');
          } catch (e) {
            setState(() => _isLoading = false);
            _showCustomSnackBar('Login failed. Please try again.', 'error');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          String errorMessage = 'Verification failed';
          
          // Handle specific Firebase Auth errors
          if (e.code == 'invalid-phone-number') {
            errorMessage = 'Invalid phone number format';
          } else if (e.code == 'too-many-requests') {
            errorMessage = 'Too many attempts. Please try again later.';
          } else if (e.message != null) {
            errorMessage = e.message!;
          }
          
          _showCustomSnackBar(errorMessage, 'error');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
          });
          
          // Navigate to OTP verification page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationPage(
                phoneNumber: fullPhone,
                verificationId: verificationId,
                isRegistration: false,
                onVerificationSuccess: () {
                  // Navigate to user selection after successful verification
                  Navigator.pushReplacementNamed(context, '/user_selection');
                },
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Handle timeout if needed
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showCustomSnackBar('Failed to send OTP. Please try again.', 'error');
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
    final buttonHeight = isMobile ? 50.0 : isTablet ? 55.0 : 60.0;
    
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
                          "Login with Phone Number!",
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
                  
                  // Phone number field
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
                      child: Row(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                                left: containerPadding * 0.8, right: containerPadding * 0.2),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedCountryCode,
                                items: countries.map((country) {
                                  return DropdownMenuItem<String>(
                                    value: country['code'],
                                    child: Text(country['code']!,
                                        style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w500,
                                            fontSize: textFieldFontSize)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedCountryCode = value!;
                                  });
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              enabled: true,
                              style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontSize: textFieldFontSize,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: "Phone Number",
                                hintStyle: GoogleFonts.outfit(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                  fontSize: hintFontSize,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: fieldSpacing),
                  
                  // Send OTP button
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding * 0.9),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: phoneController.text.trim().isNotEmpty 
                                  ? Color(0xFF0091AD) 
                                  : Colors.grey,
                              minimumSize: Size(double.infinity, buttonHeight),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              disabledBackgroundColor: Color(0x68454547),
                            ),
                            onPressed: phoneController.text.trim().isNotEmpty 
                                ? _sendOTP
                                : null,
                            child: Text(
                              'Send OTP',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: buttonFontSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                  ),
                  
                  SizedBox(height: isMobile ? 50.0 : isTablet ? 60.0 : 70.0),
                  
                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account?',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w500,
                          fontSize: registerFontSize,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(context, '/phone_register');
                        },
                        child: Text(
                          ' Register',
                          style: GoogleFonts.outfit(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                            fontSize: registerFontSize,
                          ),
                        ),
                      )
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
                        