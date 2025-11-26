import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  bool _isLoading = false;
  bool agreedToTerms = false;

  // Country code dropdown
  final List<Map<String, String>> countries = [
    {'name': 'Philippines', 'code': '+63'},
    {'name': 'United States', 'code': '+1'},
    {'name': 'India', 'code': '+91'},
    {'name': 'United Kingdom', 'code': '+44'},
  ];
  String selectedCountryCode = '+63';

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
    if (!agreedToTerms) {
      _showCustomSnackBar(
          'You must agree to the Terms and Conditions to sign up.', 'warning');
      return;
    }

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

    // Ensure it starts with 9 or 09 for Philippines
    if (selectedCountryCode == '+63' && !phone.startsWith('9')) {
      _showCustomSnackBar('Philippine phone numbers must start with 9 or 09.', 'warning');
      return;
    }

    String fullPhone = selectedCountryCode + phone;

    setState(() => _isLoading = true);

    try {
      print('📱 Checking if phone number is registered: $fullPhone');

      bool isRegistered = await _authServices.isPhoneNumberRegistered(fullPhone);

      if (isRegistered) {
        setState(() => _isLoading = false);
        _showCustomSnackBar(
            'This phone number is already registered. Please login instead.',
            'error');
        return;
      }

      await _customPhoneAuth.sendOTPWithoutCaptcha(
        phoneNumber: fullPhone,
        onVerificationCompleted: (PhoneAuthCredential credential) async {
          print('✅ Auto verification completed');
          try {
            UserCredential userCredential =
                await FirebaseAuth.instance.signInWithCredential(credential);
            final user = userCredential.user;

            if (user != null) {
              print('✅ User auto-signed in: ${user.uid}');

              await _authServices.savePhoneUserToFirestore(
                uid: user.uid,
                phoneNumber: fullPhone,
              );

              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({
                'isPhoneVerified': true,
                'updatedAt': FieldValue.serverTimestamp(),
              });

              print('✅ User data saved to Firestore');

              await FirebaseAuth.instance.signOut();
              print('✅ User signed out - redirecting to login page');

              if (!mounted) return;

              setState(() => _isLoading = false);

              _showCustomSnackBar(
                  'Registration successful! Please log in to continue.',
                  'success');

              await Future.delayed(const Duration(milliseconds: 800));

              if (!mounted) return;

              Navigator.pushReplacementNamed(context, '/phone_login');
            }
          } catch (e) {
            print('❌ Auto verification error: $e');
            setState(() => _isLoading = false);
            _showCustomSnackBar(
                'Registration failed. Please try again.', 'error');
          }
        },
        onVerificationFailed: (FirebaseAuthException e) {
          print('❌ Verification failed: ${e.code} - ${e.message}');
          setState(() => _isLoading = false);
          String errorMessage = 'Verification failed';

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

          _showCustomSnackBar(errorMessage, 'error');
        },
        onCodeSent: (String verificationId, int? resendToken) {
          print('✅ OTP sent successfully');
          setState(() {
            _isLoading = false;
          });

          _showCustomSnackBar('OTP sent successfully to $fullPhone', 'success');

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationPage(
                phoneNumber: fullPhone,
                verificationId: verificationId,
                isRegistration: true,
                onVerificationSuccess: () async {
                  print('✅ OTP verification successful during registration');

                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({
                      'isPhoneVerified': true,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    await FirebaseAuth.instance.signOut();
                    print(
                        '✅ User signed out after registration - redirecting to login');
                  }

                  if (!mounted) return;

                  _showCustomSnackBar(
                      'Registration successful! Please log in to continue.',
                      'success');

                  await Future.delayed(const Duration(milliseconds: 800));

                  if (!mounted) return;

                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/phone_login',
                    (route) => false,
                  );
                },
              ),
            ),
          );
        },
        onCodeAutoRetrievalTimeout: (String verificationId) {
          print('⏱️ OTP auto-retrieval timed out');

          if (mounted) {
            _showCustomSnackBar(
                'OTP auto-retrieval timed out. Please enter the code manually.',
                'warning');
          }
        },
      );
    } on FirebaseException catch (e) {
      print('❌ Firestore error: ${e.code} - ${e.message}');

      if (e.code == 'permission-denied') {
        print('⚠️ Permission denied, proceeding with registration anyway');
        _showCustomSnackBar('Proceeding with registration...', 'warning');

        try {
          await _customPhoneAuth.sendOTPWithoutCaptcha(
            phoneNumber: fullPhone,
            onVerificationCompleted: (PhoneAuthCredential credential) async {
              print('✅ Auto verification completed');
              try {
                UserCredential userCredential = await FirebaseAuth.instance
                    .signInWithCredential(credential);
                final user = userCredential.user;

                if (user != null) {
                  print('✅ User auto-signed in: ${user.uid}');

                  await _authServices.savePhoneUserToFirestore(
                    uid: user.uid,
                    phoneNumber: fullPhone,
                  );

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({
                    'isPhoneVerified': true,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  print('✅ User data saved to Firestore');

                  await FirebaseAuth.instance.signOut();
                  print('✅ User signed out - redirecting to login page');

                  if (!mounted) return;

                  setState(() => _isLoading = false);

                  _showCustomSnackBar(
                      'Registration successful! Please log in to continue.',
                      'success');

                  await Future.delayed(const Duration(milliseconds: 800));

                  if (!mounted) return;

                  Navigator.pushReplacementNamed(context, '/phone_login');
                }
              } catch (e) {
                print('❌ Auto verification error: $e');
                setState(() => _isLoading = false);
                _showCustomSnackBar(
                    'Registration failed. Please try again.', 'error');
              }
            },
            onVerificationFailed: (FirebaseAuthException e) {
              print('❌ Verification failed: ${e.code} - ${e.message}');
              setState(() => _isLoading = false);
              String errorMessage = 'Verification failed';

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

              _showCustomSnackBar(errorMessage, 'error');
            },
            onCodeSent: (String verificationId, int? resendToken) {
              print('✅ OTP sent successfully');
              setState(() {
                _isLoading = false;
              });

              _showCustomSnackBar(
                  'OTP sent successfully to $fullPhone', 'success');

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OTPVerificationPage(
                    phoneNumber: fullPhone,
                    verificationId: verificationId,
                    isRegistration: true,
                    onVerificationSuccess: () async {
                      print(
                          '✅ OTP verification successful during registration');

                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .update({
                          'isPhoneVerified': true,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });

                        await FirebaseAuth.instance.signOut();
                        print(
                            '✅ User signed out after registration - redirecting to login');
                      }

                      if (!mounted) return;

                      _showCustomSnackBar(
                          'Registration successful! Please log in to continue.',
                          'success');

                      await Future.delayed(const Duration(milliseconds: 800));

                      if (!mounted) return;

                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/phone_login',
                        (route) => false,
                      );
                    },
                  ),
                ),
              );
            },
            onCodeAutoRetrievalTimeout: (String verificationId) {
              print('⏱️ OTP auto-retrieval timed out');

              if (mounted) {
                _showCustomSnackBar(
                    'OTP auto-retrieval timed out. Please enter the code manually.',
                    'warning');
              }
            },
          );
        } catch (e) {
          print('❌ Error sending OTP: $e');
          setState(() => _isLoading = false);
          _showCustomSnackBar('Failed to send OTP. Please try again.', 'error');
        }
      } else {
        setState(() => _isLoading = false);
        _showCustomSnackBar('An error occurred. Please try again.', 'error');
      }
    } catch (e) {
      print('❌ Unexpected error: $e');
      setState(() => _isLoading = false);
      _showCustomSnackBar(
          'An unexpected error occurred. Please try again.', 'error');
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

                  // Terms and conditions checkbox
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
                                  color: Colors.black, fontSize: hintFontSize),
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
                                        fontWeight: FontWeight.w500,
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
                  SizedBox(height: fieldSpacing),

                  // Send OTP button
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding * 0.9),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (_isValidPhoneLength(phoneController.text) && agreedToTerms)
                                  ? Color(0xFF0091AD)
                                  : Colors.grey,
                              minimumSize: Size(double.infinity, buttonHeight),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: (_isValidPhoneLength(phoneController.text) && agreedToTerms)
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

                  // Login link
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
                        onTap: () {
                          Navigator.pushReplacementNamed(context, '/phone_login');
                        },
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