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

  String? _verificationId;
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

  Future<void> _sendOTP() async {
    String phone = phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a phone number.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (phone.startsWith('0')) phone = phone.substring(1);
    String fullPhone = selectedCountryCode + phone;

    // Check if phone number exists in Firestore before sending OTP
    bool isRegistered = await _authServices.isPhoneNumberRegistered(fullPhone);
    if (!isRegistered) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This phone number is not registered. Please register first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: fullPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            setState(() => _isLoading = false);
            Navigator.pushReplacementNamed(context, '/user_selection');
          } catch (e) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Login failed. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
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
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
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
          setState(() => _verificationId = verificationId);
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send OTP. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final isDesktop = ResponsiveBreakpoints.of(context).isDesktop;
    
    // Calculate responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Responsive sizing
    final logoWidth = isMobile ? 120.0 : (isTablet ? 150.0 : 180.0);
    final titleFontSize = isMobile ? 35.0 : (isTablet ? 45.0 : 50.0);
    final subtitleFontSize = isMobile ? 16.0 : (isTablet ? 18.0 : 20.0);
    final buttonHeight = isMobile ? 50.0 : (isTablet ? 60.0 : 70.0);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.38,
            decoration: BoxDecoration(
              color: Color(0xFFE5E9F0),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double maxLogoWidth = 400.0;
                double logoWidth = 150;
                math.min(constraints.maxWidth * 0.4, maxLogoWidth);
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
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: Container(
                margin: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.24),
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: EdgeInsets.only(
                  top: screenHeight * 0.05,
                  left: screenWidth * 0.07,
                  right: screenWidth * 0.07,
                  bottom: screenHeight * 0.25,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
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
                    SizedBox(height: 20),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 25.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFE5E9F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 14.0, right: 4.0),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedCountryCode,
                                  items: countries.map((country) {
                                    return DropdownMenuItem<String>(
                                      value: country['code'],
                                      child: Text(country['code']!,
                                          style: GoogleFonts.outfit(
                                              fontWeight:
                                                  FontWeight.w500)),
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
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Phone Number",
                                  hintStyle: GoogleFonts.outfit(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),


                    SizedBox(height: 20),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 25.0),
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator())
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: phoneController.text.trim().isNotEmpty 
                                    ? Color(0xFF0091AD) 
                                    : Colors.grey,
                                minimumSize: Size(double.infinity, buttonHeight),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                // Ensure button is not disabled
                                disabledBackgroundColor: Color(0x68454547),
                              ),
                              onPressed: phoneController.text.trim().isNotEmpty 
                                  ? _sendOTP
                                  : null,
                              child: Text(
                                'Send OTP',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                    ),
                    SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account?',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w500,
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
                            ),
                          ),
                        )
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
