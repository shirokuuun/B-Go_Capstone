import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:b_go/pages/terms_and_conditions_page.dart';
import 'package:b_go/responsiveness/responsive_page.dart';

class RegisterPhonePage extends StatefulWidget {
  const RegisterPhonePage({super.key});

  @override
  State<RegisterPhonePage> createState() => _RegisterPhonePageState();
}

class _RegisterPhonePageState extends State<RegisterPhonePage> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _verificationId;
  bool _otpSent = false;
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
    otpController.dispose();
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
    setState(() => _isLoading = true);
    String phone = phoneController.text.trim();
    // Remove leading 0 if present
    if (phone.startsWith('0')) phone = phone.substring(1);
    String fullPhone = selectedCountryCode + phone;
    await _auth.verifyPhoneNumber(
      phoneNumber: fullPhone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        setState(() => _isLoading = false);
        Navigator.pop(context);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message ?? 'Verification failed'),
              backgroundColor: Colors.red),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
          _isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        setState(() => _verificationId = verificationId);
      },
    );
  }

  Future<void> _verifyOTP() async {
    if (_verificationId == null) return;
    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otpController.text.trim(),
      );
      await _auth.signInWithCredential(credential);
      setState(() => _isLoading = false);
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Invalid OTP or verification failed'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
        Responsive responsive = Responsive(context);
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
                    top: responsive.height * 0.05,
                    left: responsive.width * 0.07,
                    right: responsive.width * 0.07,
                    bottom: responsive.height * 0.25,
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
                              fontSize: 45,
                            ),
                          ),
                          Text(
                            "Register Your Phone Number!",
                            style: GoogleFonts.outfit(
                              fontSize: 18,
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
                                  onChanged: !_otpSent
                                      ? (value) {
                                          setState(() {
                                            selectedCountryCode = value!;
                                          });
                                        }
                                      : null,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                enabled: !_otpSent,
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
                    if (_otpSent)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 25.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(0xFFE5E9F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20.0),
                            child: TextField(
                              controller: otpController,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.outfit(
                                color: Colors.black,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: "Enter OTP",
                                hintStyle: GoogleFonts.outfit(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
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
                                backgroundColor: Color(0xFF1D2B53),
                                minimumSize: Size(double.infinity, 60),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: agreedToTerms
                                  ? (_otpSent ? _verifyOTP : _sendOTP)
                                  : null,
                              child: Text(
                                _otpSent ? 'Verify OTP' : 'Send OTP',
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
