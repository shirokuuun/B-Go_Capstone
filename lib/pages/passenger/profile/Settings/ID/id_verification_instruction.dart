import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:responsive_framework/responsive_framework.dart';

class IDVerificationInstructionPage extends StatefulWidget {
  final VoidCallback? onNext;
  const IDVerificationInstructionPage({Key? key, this.onNext})
      : super(key: key);

  @override
  State<IDVerificationInstructionPage> createState() => _IDVerificationInstructionPageState();
}

class _IDVerificationInstructionPageState extends State<IDVerificationInstructionPage> {
  bool _isChecking = true;
  bool _hasVerifiedID = false;

  @override
  void initState() {
    super.initState();
    _checkExistingID();
  }

  Future<void> _checkExistingID() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isChecking = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('VerifyID')
          .doc('id')
          .get();

      if (doc.exists) {
        final data = doc.data();
        final status = data?['status'];
        
        if (status == 'verified') {
          setState(() {
            _hasVerifiedID = true;
            _isChecking = false;
          });
          
          // Show modal after a short delay to ensure widget is built
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAlreadyVerifiedModal();
          });
        } else {
          setState(() => _isChecking = false);
        }
      } else {
        setState(() => _isChecking = false);
      }
    } catch (e) {
      setState(() => _isChecking = false);
    }
  }

  void _showAlreadyVerifiedModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'ID Already Verified',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'You already have a verified ID. You cannot submit another ID for verification.',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close modal
              Navigator.of(context).pop(); // Go back to previous page
            },
            child: Text('OK', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasVerifiedID) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: const Color(0xFF0091AD),
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'ID Verification Instructions',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: MediaQuery.of(context).size.width * 0.05,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 80,
                ),
                SizedBox(height: 20),
                Text(
                  'Your ID is already verified!',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  'You cannot submit another ID for verification.',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    // Responsive sizing
    final appBarFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final bodyFontSize = isMobile
        ? 14.0
        : isTablet
            ? 16.0
            : 18.0;
    final horizontalPadding = isMobile
        ? 20.0
        : isTablet
            ? 24.0
            : 28.0;
    final verticalPadding = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;
    final cardRadius = 12.0;

    final cyan = const Color(0xFF0091AD);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: cyan,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'ID Verification Instructions',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: appBarFontSize,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    'Take a clear photo of your\nID for verifications',
                    style: GoogleFonts.outfit(
                        fontSize: bodyFontSize, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text('If you have questions, please visit our ',
                            style: GoogleFonts.outfit(fontSize: bodyFontSize),
                            softWrap: true,
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                            textAlign: TextAlign.center),
                      ),
                      Flexible(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/help_center');
                          },
                          child: Text(
                            'Help Center',
                            style: GoogleFonts.outfit(
                              fontSize: bodyFontSize,
                              color: cyan,
                              decoration: TextDecoration.underline,
                            ),
                            softWrap: true,
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            _idSample('Front', isMobile, isTablet),
            SizedBox(height: 12),
            _idSample('Back', isMobile, isTablet),
            SizedBox(height: 24),
            Text('ID Photo Standards:',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w500, fontSize: bodyFontSize),
                textAlign: TextAlign.left,
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.visible),
            SizedBox(height: 6),
            _bullet('Government/school-issued and valid', bodyFontSize),
            _bullet('Photo must be clear, well-lit, and show the entire ID',
                bodyFontSize),
            _bullet('No glare, blur, or obstructions', bodyFontSize),
            _bullet('Both front and back required for Student/PWD/Senior',
                bodyFontSize),
            _bullet('Name and photo must be readable', bodyFontSize),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightGreen[400],
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(cardRadius),
                  ),
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: widget.onNext ?? () {
                  Navigator.pushNamed(context, '/id_verification_picture');
                },
                child: Text('Next', style: GoogleFonts.outfit(fontSize: bodyFontSize)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _idSample(String label, bool isMobile, bool isTablet) {
    final iconSize = isMobile ? 40.0 : isTablet ? 50.0 : 60.0;
    final containerHeight = isMobile ? 120.0 : isTablet ? 140.0 : 160.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w500, fontSize: 16.0)),
        SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: containerHeight,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.badge, size: iconSize, color: Colors.black38),
        ),
      ],
    );
  }

  Widget _bullet(String text, double fontSize) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
      child: Row(
        children: [
          Text('• ', style: GoogleFonts.outfit(fontSize: fontSize)),
          Expanded(
              child: Text(text,
                  style: GoogleFonts.outfit(fontSize: fontSize),
                  textAlign: TextAlign.left,
                  softWrap: true,
                  maxLines: 3,
                  overflow: TextOverflow.visible)),
        ],
      ),
    );
  }
}
