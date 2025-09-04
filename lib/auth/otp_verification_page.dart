import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:b_go/pages/terms_and_conditions_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OTPVerificationPage extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final VoidCallback? onVerificationSuccess;
  final bool isRegistration;

  const OTPVerificationPage({
    Key? key,
    required this.phoneNumber,
    required this.verificationId,
    this.onVerificationSuccess,
    this.isRegistration = false,
  }) : super(key: key);

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

// Custom TextInputFormatter for OTP fields
class OTPTextInputFormatter extends TextInputFormatter {
  final int index;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;

  OTPTextInputFormatter({
    required this.index,
    required this.controllers,
    required this.focusNodes,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only allow single digit
    if (newValue.text.length > 1) {
      return TextEditingValue(
        text: newValue.text.substring(0, 1),
        selection: TextSelection.collapsed(offset: 1),
      );
    }
    
    return newValue;
  }
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {

  String _getOTP() {
    return otpControllers.map((controller) => controller.text).join();
  }

  final List<TextEditingController> otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  bool _isVerifying = false;
  String? _errorMessage;
  int _resendCountdown = 60;
  bool _canResend = false;

  // Custom TextInputFormatter for OTP fields
  late List<OTPTextInputFormatter> otpFormatters;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
    
    // Initialize OTP formatters
    otpFormatters = List.generate(
      6,
      (index) => OTPTextInputFormatter(
        index: index,
        controllers: otpControllers,
        focusNodes: focusNodes,
      ),
    );
    
    // Add listeners to move focus to next field only
    for (int i = 0; i < 6; i++) {
      otpControllers[i].addListener(() {
        if (otpControllers[i].text.length == 1 && i < 5) {
          focusNodes[i + 1].requestFocus();
        }
      });
    }
    

  }

  @override
  void dispose() {
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }



  void _startResendCountdown() {
    setState(() {
      _canResend = false;
      _resendCountdown = 30;
    });
    
    Future.delayed(Duration(seconds: 1), () {
      if (mounted) {
        if (_resendCountdown > 0) {
          setState(() {
            _resendCountdown--;
          });
          _startResendCountdown();
        } else {
          setState(() {
            _canResend = true;
          });
        }
      }
    });
  }

  Future<void> _verifyOTP() async {
    String otp = otpControllers.map((controller) => controller.text).join();
    
    if (otp.length != 6) {
      setState(() {
        _errorMessage = "Please enter the complete 6-digit code";
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      if (widget.isRegistration) {
        // For registration, verify the credential and create user document
        print('Starting registration flow for phone: ${widget.phoneNumber}');
        
        final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        final user = userCredential.user;
        
        print('User authenticated with UID: ${user?.uid}');
        
        if (user != null) {
          try {
            print('Creating user document in Firestore...');
            
            // Check if user already exists
            final existingUser = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            
            print('Checking if user exists in Firestore...');
            print('User UID: ${user.uid}');
            print('User exists: ${existingUser.exists}');
            
            if (!existingUser.exists) {
              // Only create if user doesn't exist
              print('Creating new user document...');
              final userData = {
                'phone': widget.phoneNumber,
                'name': widget.phoneNumber, // Can be updated later
                'authMethod': 'phone',
                'isEmailVerified': false,
                'isPhoneVerified': true,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              };
              print('User data to save: $userData');
              
              await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
                userData,
                SetOptions(merge: true)
              );
              print('New user document created successfully');
            } else {
              print('User document already exists, updating phone verification status');
              // Update existing user's phone verification status
              await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                'phone': widget.phoneNumber,
                'isPhoneVerified': true,
                'updatedAt': FieldValue.serverTimestamp(),
              });
              print('User document updated successfully');
            }
            
            // If there's a callback, call it after successful user creation
            if (widget.onVerificationSuccess != null) {
              print('Calling verification success callback');
              setState(() {
                _isVerifying = false;
              });
              
              // Sign out before calling callback since callback handles navigation
              await FirebaseAuth.instance.signOut();
              print('User signed out before calling callback');
              
              // Call the callback to handle navigation
              try {
                widget.onVerificationSuccess!();
              } catch (e) {
                print('Error in verification success callback: $e');
                // If callback fails, fall back to default navigation
                Navigator.pushReplacementNamed(context, '/phone_login');
              }
              return;
            }
            
            // Otherwise, handle navigation here
            // Sign out after successfully creating/updating user document
            await FirebaseAuth.instance.signOut();
            print('User signed out after registration');
            
            setState(() {
              _isVerifying = false;
            });
            
            // Navigate to login page for registration flow
            print('Navigating to login page...');
            Navigator.pushReplacementNamed(context, '/login');
            return;
          } catch (firestoreError) {
            print('Firestore error: $firestoreError');
            // If Firestore fails, sign out and show error
            await FirebaseAuth.instance.signOut();
            throw Exception('Failed to create user account. Please try again.');
          }
        } else {
          throw Exception('User authentication failed');
        }
      } else {
        // For login, sign in with the credential
        print('Starting login flow for phone: ${widget.phoneNumber}');
        
        await FirebaseAuth.instance.signInWithCredential(credential);
        print('User logged in successfully');
        
        setState(() {
          _isVerifying = false;
        });
        
        // Navigate to user selection for login flow
        print('Navigating to user selection page...');
        Navigator.pushReplacementNamed(context, '/user_selection');
        return;
      }
    } catch (e) {
      print('OTP verification error: $e');
      setState(() {
        _isVerifying = false;
        _errorMessage = e.toString().contains('Failed to create user account') 
            ? e.toString().replaceAll('Exception: ', '')
            : "Incorrect code. Please try again";
      });
      
      // Clear all OTP fields on error
      for (var controller in otpControllers) {
        controller.clear();
      }
      focusNodes[0].requestFocus();
    }
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;

    setState(() {
      // Start resending process
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed
          if (widget.onVerificationSuccess != null) {
            widget.onVerificationSuccess!();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _errorMessage = "Failed to resend OTP. Please try again.";
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _errorMessage = null;
          });
          _startResendCountdown();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('OTP resent to ${widget.phoneNumber}'),
              backgroundColor: Colors.green,
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            // Auto retrieval timeout
          });
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to resend OTP. Please try again.";
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    
    // Calculate responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Responsive sizing
    final logoWidth = isMobile ? 120.0 : (isTablet ? 150.0 : 180.0);
    final titleFontSize = isMobile ? 20.0 : (isTablet ? 24.0 : 28.0);
    final instructionFontSize = isMobile ? 14.0 : (isTablet ? 16.0 : 18.0);
    final otpFieldSize = isMobile ? 40.0 : (isTablet ? 50.0 : 60.0);
    final otpFieldMargin = isMobile ? 4.0 : (isTablet ? 8.0 : 12.0);
    final buttonHeight = isMobile ? 50.0 : (isTablet ? 60.0 : 70.0);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            height: screenHeight * 0.38,
            decoration: BoxDecoration(
              color: Color(0xFFE5E9F0),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double maxLogoWidth = 400.0;
                double calculatedLogoWidth = math.min(constraints.maxWidth * 0.4, maxLogoWidth);
                return Transform.translate(
                  offset: Offset(0, -20),
                  child: Center(
                    child: Image.asset(
                      'assets/batrasco-logo.png',
                      width: math.min(logoWidth, calculatedLogoWidth),
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
                margin: EdgeInsets.only(top: screenHeight * 0.24),
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
                    // Back button and title
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.arrow_back, color: Colors.black),
                        ),
                        Expanded(
                          child: Text(
                            "Verify account with OTP",
                            style: GoogleFonts.outfit(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(width: 48), // Balance the back button
                      ],
                    ),
                    
                    SizedBox(height: 20),
                    
                    // Instruction text
                    Center(
                      child: Text(
                        "We've sent 6 code to ${widget.phoneNumber}",
                        style: GoogleFonts.outfit(
                          fontSize: instructionFontSize,
                          color: Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    SizedBox(height: 30),
                    
                    // OTP input fields - Made responsive to prevent overflow
                    Center(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate available width for OTP fields
                          final availableWidth = constraints.maxWidth;
                          final totalFieldWidth = (otpFieldSize * 6) + (otpFieldMargin * 10); // 6 fields + margins
                          
                          // If total width exceeds available width, reduce field size and margins
                          double finalFieldSize = otpFieldSize;
                          double finalMargin = otpFieldMargin;
                          
                          if (totalFieldWidth > availableWidth) {
                            finalMargin = math.max(2.0, (availableWidth - (otpFieldSize * 6)) / 10);
                            if (finalMargin < 2.0) {
                              finalFieldSize = (availableWidth - (2.0 * 10)) / 6;
                              finalMargin = 2.0;
                            }
                          }
                          
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(6, (index) {
                              return Container(
                                margin: EdgeInsets.symmetric(horizontal: finalMargin),
                                width: finalFieldSize,
                                height: finalFieldSize,
                                child: TextField(
                                  controller: otpControllers[index],
                                  focusNode: focusNodes[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  maxLength: 1,
                                  style: GoogleFonts.outfit(
                                    fontSize: math.max(16, finalFieldSize * 0.4),
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: "",
                                    hintText: "",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: _errorMessage != null 
                                            ? Colors.red 
                                            : (otpControllers[index].text.isNotEmpty 
                                                ? Color(0xFF0091AD) 
                                                : Colors.grey.shade300),
                                        width: 2,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: _errorMessage != null 
                                            ? Colors.red 
                                            : Colors.grey.shade300,
                                        width: 2,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: Color(0xFF0091AD),
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                                                     onChanged: (value) {
                                     setState(() {
                                       _errorMessage = null;
                                     });
                                     
                                     // If field becomes empty and it's not the first field, move to previous
                                     if (value.isEmpty && index > 0) {
                                       // Small delay to ensure backspace completes
                                       Future.delayed(Duration(milliseconds: 10), () {
                                         if (mounted && otpControllers[index].text.isEmpty) {
                                           focusNodes[index - 1].requestFocus();
                                         }
                                       });
                                     }
                                   },
                                   onTap: () {
                                     // Just focus the field, don't auto-select text
                                     // User can manually select text if needed
                                   },
                                   onEditingComplete: () {
                                     // Move to next field when editing is complete
                                     if (index < 5) {
                                       focusNodes[index + 1].requestFocus();
                                     }
                                   },
                                   // Custom input formatter to handle backspace
                                   inputFormatters: [
                                     otpFormatters[index],
                                   ],
                                   // Handle backspace key press for better navigation
                                   onSubmitted: (value) {
                                     if (index < 5) {
                                       focusNodes[index + 1].requestFocus();
                                     }
                                   },

                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                    
                    SizedBox(height: 20),
                    
                    // Error message or verification status
                    if (_errorMessage != null)
                      Center(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.outfit(
                            color: Colors.red,
                            fontSize: isMobile ? 12.0 : 14.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else if (_isVerifying)
                      Center(
                        child: Text(
                          "Verifying your OTP...",
                          style: GoogleFonts.outfit(
                            color: Colors.grey,
                            fontSize: isMobile ? 12.0 : 14.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    
                    SizedBox(height: 20),
                    
                    // Resend code option
                    Center(
                      child: GestureDetector(
                        onTap: _canResend ? _resendOTP : null,
                        child: Text(
                          _canResend 
                              ? "Resend code" 
                              : "Resend code in $_resendCountdown seconds",
                          style: GoogleFonts.outfit(
                            color: _canResend ? Color(0xFF0091AD) : Colors.grey,
                            fontSize: isMobile ? 12.0 : 14.0,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 40),
                    
                    // Continue button
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 20.0 : 25.0,
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0091AD),
                          minimumSize: Size(double.infinity, buttonHeight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isVerifying || _getOTP().isEmpty || _getOTP().length != 6 ? null : _verifyOTP,
                        child: _isVerifying
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Continue',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: isMobile ? 18.0 : 20.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ),
                    
                    SizedBox(height: 20),
                    
                    // Terms and privacy policy
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TermsAndConditionsPage(
                                showRegisterPage: () {
                                  // This callback is required by the TermsAndConditionsPage
                                  // but we don't need to use it here
                                },
                              ),
                            ),
                          );
                        },
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.outfit(
                              color: Colors.black54,
                              fontSize: isMobile ? 10.0 : 12.0,
                            ),
                            children: [
                              TextSpan(text: 'By entering your number you agree to our '),
                              TextSpan(
                                text: 'Terms & Privacy Policy',
                                style: GoogleFonts.outfit(
                                  color: Color(0xFF0091AD),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
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
    );
  }
}
