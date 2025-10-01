import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailController = TextEditingController();

  dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future passwordReset() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text(
              'If your email is registered, you’ll receive a password reset email. Thank you!',
              style: GoogleFonts.outfit(
                fontSize: 16.0,
                color: Colors.grey.shade600,
              ),
            ),
          );
        },
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found for that email.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'missing-email':
          message = 'Please enter your email address.';
          break;
        default:
          message = 'Something went wrong. Please try again later.';
      }
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text(
              message,
              style: GoogleFonts.outfit(
                fontSize: 16.0,
                color: Colors.grey.shade600,
              ),
            ),
          );
        },
      );
    } catch (e) {
      // For any other errors
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: Text('Something went wrong. Please try again later.'),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    // Responsive sizing
    final titleFontSize = isMobile
        ? 20.0
        : isTablet
            ? 26.0
            : 28.0;
    final subtitleFontSize = isMobile
        ? 14.0
        : isTablet
            ? 15.0
            : 16.0;
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
    final appBarFontSize = isMobile
        ? 16.0
        : isTablet
            ? 17.0
            : 18.0;

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
        appBar: AppBar(
          title: Text(
            'Forgot Password',
            style: GoogleFonts.outfit(
                fontSize: appBarFontSize, color: Colors.white),
          ),
          backgroundColor: Color(0xFF0091AD),
          elevation: 0,
          iconTheme: IconThemeData(
            color: Colors.white,
          ),
        ),
        body: Stack(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.38,
              decoration: BoxDecoration(
                color: Color(0xFFE5E9F0),
              ),
              padding: const EdgeInsets.only(left: 10, bottom: 35),
              alignment: Alignment.topLeft,
              child: Center(),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                child: Container(
                  margin: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.20,
                  ),
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: isMobile
                        ? 32.0
                        : isTablet
                            ? 36.0
                            : 40.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Change password text
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enter your email to reset your password',
                              style: GoogleFonts.outfit(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(
                                height: isMobile
                                    ? 8.0
                                    : isTablet
                                        ? 10.0
                                        : 12.0),
                            Center(
                              child: Text(
                                'Make sure to enter the email you used to register',
                                style: GoogleFonts.outfit(
                                  fontSize: subtitleFontSize,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

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
                                  fontSize: hintFontSize,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

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
                            onPressed: passwordReset,
                            child: Text(
                              'Reset Password',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: buttonFontSize,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ));
  }
}
