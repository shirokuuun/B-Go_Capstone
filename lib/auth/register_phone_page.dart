import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:b_go/pages/terms_and_conditions_page.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:b_go/auth/auth_services.dart';
import 'package:b_go/auth/otp_verification_page.dart';
import 'package:b_go/auth/custom_phone_auth.dart';

class RegisterPhonePage extends StatefulWidget {
  const RegisterPhonePage({super.key});

  @override
  State<RegisterPhonePage> createState() => _RegisterPhonePageState();
}

class _RegisterPhonePageState extends State<RegisterPhonePage> {
  final TextEditingController phoneController = TextEditingController();
  final AuthServices _authServices = AuthServices();
  final CustomPhoneAuth _customPhoneAuth = CustomPhoneAuth();

  String? _verificationId;
  bool _isLoading = false;
  bool agreedToTerms = false;

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
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
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

    // Remove leading 0 if present
    if (phone.startsWith('0')) phone = phone.substring(1);
    String fullPhone = selectedCountryCode + phone;

    // Check if phone number already exists
    bool isRegistered = await _authServices.isPhoneNumberRegistered(fullPhone);
    if (isRegistered) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('This phone number is already registered. Please login instead.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Use the custom phone auth service that bypasses reCAPTCHA
      await _customPhoneAuth.sendOTPWithoutCaptcha(
        phoneNumber: fullPhone,
        onVerificationCompleted: (PhoneAuthCredential credential) async {
          // This will be called if verification completes automatically
          // Usually happens on Android when SMS is auto-retrieved
          try {
            UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            final user = userCredential.user;
            if (user != null) {
              // Save user to Firestore
              await _authServices.savePhoneUserToFirestore(
                uid: user.uid,
                phoneNumber: fullPhone,
              );
              setState(() => _isLoading = false);
              Navigator.pushReplacementNamed(context, '/user_selection');
            }
          } catch (e) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Registration failed. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        onVerificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          String errorMessage = 'Verification failed';
          
          // Handle specific error cases
          switch (e.code) {
            case 'invalid-phone-number':
              errorMessage = 'Invalid phone number format';
              break;
            case 'too-many-requests':
              errorMessage = 'Too many attempts. Please try again later.';
              break;
            case 'quota-exceeded':
              errorMessage = 'SMS quota exceeded. Please try again later.';
              break;
            case 'app-not-authorized':
              errorMessage = 'App not authorized. Please try again.';
              break;
            case 'captcha-check-failed':
              errorMessage = 'Verification failed. Please try again.';
              break;
            case 'platform-error':
              errorMessage = 'Platform error. Please try again.';
              break;
            case 'unknown-error':
              errorMessage = 'Failed to send OTP. Please try again.';
              break;
            default:
              errorMessage = e.message ?? 'Verification failed';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        },
        onCodeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('OTP sent successfully to $fullPhone'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Navigate to OTP verification page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationPage(
                phoneNumber: fullPhone,
                verificationId: verificationId,
                isRegistration: true,
                onVerificationSuccess: () async {
                  // After successful OTP verification and user creation, navigate to user selection
                  print('OTP verification successful, navigating to user selection');
                  Navigator.pushReplacementNamed(context, '/user_selection');
                },
              ),
            ),
          );
        },
        onCodeAutoRetrievalTimeout: (String verificationId) {
          setState(() => _verificationId = verificationId);
          // Show timeout message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('OTP auto-retrieval timed out. Please enter the code manually.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
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
                double maxLogoWidth = 400.0; // Adjust this value as needed
                double logoWidth = 150;
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
                            "Register Your Phone Number!",
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
                    // --- All the rest of the registration content goes here, directly in this Column ---
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

                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 25.0),
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
                                    color: Colors.black),
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
                                            builder: (context) => TermsAndConditionsPage(showRegisterPage: () {}),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Terms and Conditions',
                                        style: GoogleFonts.outfit(
                                          color: Colors.blue,
                                          decoration: TextDecoration.underline,
                                          fontWeight: FontWeight.w500,
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
                              ),
                              onPressed: agreedToTerms
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
                          'Already have an account?',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          child: Text(
                            ' Login',
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
