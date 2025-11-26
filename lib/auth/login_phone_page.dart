import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  ];
  String selectedCountryCode = '+63';

  @override
  void initState() {
    super.initState();
    phoneController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  // Format phone number with parenthesis
  // If starts with 0: (0XXX) XXXXXXX (4 digits in parenthesis)
  // If starts with other digit: (XXX) XXXXXXX (3 digits in parenthesis)
  String _formatPhoneNumber(String value) {
    // Remove all non-digit characters
    String digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.isEmpty) return '';
    
    // Check if starts with 0
    bool startsWithZero = digitsOnly.startsWith('0');
    
    if (startsWithZero) {
      // Format with 4 digits in parenthesis: (0XXX) XXXXXXX
      if (digitsOnly.length <= 4) {
        return '($digitsOnly';
      } else if (digitsOnly.length <= 11) {
        return '(${digitsOnly.substring(0, 4)}) ${digitsOnly.substring(4)}';
      } else {
        // Limit to 11 digits total
        return '(${digitsOnly.substring(0, 4)}) ${digitsOnly.substring(4, 11)}';
      }
    } else {
      // Format with 3 digits in parenthesis: (XXX) XXXXXXX
      if (digitsOnly.length <= 3) {
        return '($digitsOnly';
      } else if (digitsOnly.length <= 10) {
        return '(${digitsOnly.substring(0, 3)}) ${digitsOnly.substring(3)}';
      } else {
        // Limit to 10 digits total
        return '(${digitsOnly.substring(0, 3)}) ${digitsOnly.substring(3, 10)}';
      }
    }
  }

  // Get raw phone number (digits only, no formatting)
  String _getRawPhoneNumber(String formatted) {
    String digitsOnly = formatted.replaceAll(RegExp(r'[^\d]'), '');
    // Remove leading 0 if present for sending to Firebase
    if (digitsOnly.startsWith('0')) {
      digitsOnly = digitsOnly.substring(1);
    }
    return digitsOnly;
  }

  // Validate phone number length (10-11 digits for Philippines)
  bool _isValidPhoneLength(String phone) {
    String digitsOnly = _getRawPhoneNumber(phone);
    return digitsOnly.length >= 10 && digitsOnly.length <= 11;
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
    String phone = _getRawPhoneNumber(phoneController.text);
    
    if (phone.isEmpty) {
      _showCustomSnackBar('Please enter a phone number.', 'warning');
      return;
    }

    // Validate phone number length
    if (!_isValidPhoneLength(phoneController.text)) {
      _showCustomSnackBar('Phone number must be 10-11 digits.', 'warning');
      return;
    }

    // Ensure it starts with 9 or 09 for Philippines (after removing 0, it should start with 9)
    if (selectedCountryCode == '+63' && !phone.startsWith('9')) {
      _showCustomSnackBar('Philippine phone numbers must start with 9 or 09.', 'warning');
      return;
    }

    String fullPhone = selectedCountryCode + phone;

    setState(() => _isLoading = true);

    try {
      print('📱 Checking if phone number is registered: $fullPhone');

      // The phone number is already normalized (leading 0 removed) so it will match in the database
      bool isRegistered = await _authServices.isPhoneNumberRegistered(fullPhone);

      if (!isRegistered) {
        setState(() => _isLoading = false);
        _showCustomSnackBar(
            'This phone number is not registered. Please register first.',
            'error');
        return;
      }

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

          print('✅ OTP sent to $fullPhone');

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationPage(
                phoneNumber: fullPhone,
                verificationId: verificationId,
                isRegistration: false,
                onVerificationSuccess: () {
                  print('✅ Login successful, navigating to user selection');
                  Navigator.pushReplacementNamed(context, '/user_selection');
                },
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } on FirebaseException catch (e) {
      print('❌ Firestore error: ${e.code} - ${e.message}');
      setState(() => _isLoading = false);

      if (e.code == 'permission-denied') {
        print('⚠️ Permission denied, proceeding with OTP anyway');
        _showCustomSnackBar('Proceeding with verification...', 'warning');

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
              _showCustomSnackBar(e.message ?? 'Verification failed', 'error');
            },
            codeSent: (String verificationId, int? resendToken) {
              setState(() => _isLoading = false);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OTPVerificationPage(
                    phoneNumber: fullPhone,
                    verificationId: verificationId,
                    isRegistration: false,
                    onVerificationSuccess: () {
                      Navigator.pushReplacementNamed(context, '/user_selection');
                    },
                  ),
                ),
              );
            },
            codeAutoRetrievalTimeout: (String verificationId) {},
          );
        } catch (e) {
          print('❌ Error sending OTP: $e');
          _showCustomSnackBar('Failed to send OTP. Please try again.', 'error');
        }
      } else {
        _showCustomSnackBar('An error occurred. Please try again.', 'error');
      }
    } catch (e) {
      print('❌ Unexpected error: $e');
      setState(() => _isLoading = false);
      _showCustomSnackBar('An unexpected error occurred. Please try again.', 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    final logoSize = isMobile ? 120.0 : isTablet ? 140.0 : 150.0;
    final titleFontSize = isMobile ? 35.0 : isTablet ? 40.0 : 45.0;
    final subtitleFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final buttonFontSize = isMobile ? 18.0 : isTablet ? 19.0 : 20.0;
    final textFieldFontSize = isMobile ? 14.0 : isTablet ? 15.0 : 16.0;
    final hintFontSize = isMobile ? 12.0 : isTablet ? 13.0 : 14.0;
    final registerFontSize = isMobile ? 13.0 : isTablet ? 13.0 : 14.0;

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
              SizedBox(height: isMobile ? 40.0 : isTablet ? 50.0 : 60.0),
              Image.asset(
                'assets/batrasco-logo.png',
                width: logoSize,
                fit: BoxFit.contain,
              ),
              SizedBox(height: isMobile ? 40.0 : isTablet ? 50.0 : 60.0),

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
                                left: containerPadding * 0.8,
                                right: containerPadding * 0.2),
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
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[\d\(\)\s]')),
                                TextInputFormatter.withFunction((oldValue, newValue) {
                                  String formatted = _formatPhoneNumber(newValue.text);
                                  return TextEditingValue(
                                    text: formatted,
                                    selection: TextSelection.collapsed(offset: formatted.length),
                                  );
                                }),
                              ],
                              style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontSize: textFieldFontSize,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: "(929) XXXXXXX or (0929) XXXXXX",
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
                              backgroundColor: _isValidPhoneLength(phoneController.text)
                                  ? Color(0xFF0091AD)
                                  : Colors.grey,
                              minimumSize: Size(double.infinity, buttonHeight),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              disabledBackgroundColor: Color(0x68454547),
                            ),
                            onPressed: _isValidPhoneLength(phoneController.text)
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