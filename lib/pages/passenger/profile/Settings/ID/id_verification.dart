import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:responsive_framework/responsive_framework.dart';

class IDVerificationReviewPage extends StatefulWidget {
  const IDVerificationReviewPage({Key? key}) : super(key: key);

  @override
  State<IDVerificationReviewPage> createState() =>
      _IDVerificationReviewPageState();
}

class _IDVerificationReviewPageState extends State<IDVerificationReviewPage> {
  File? frontImage;
  File? backImage;
  String? idType;
  bool uploading = false;
  String? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null) {
      frontImage = args['front'] as File?;
      backImage = args['back'] as File?;
      idType = args['idType'] as String?;
      
      // Debug: Print the received arguments
      print('Received arguments: $args');
      print('ID Type received: $idType');
    }
  }

  Future<void> _uploadAndSubmit() async {
    setState(() {
      uploading = true;
      error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');
      final storage = FirebaseStorage.instance;
      final frontRef = storage.ref('users/${user.uid}/VerifyID/front.jpg');
      final backRef = storage.ref('users/${user.uid}/VerifyID/back.jpg');
      await frontRef.putFile(frontImage!);
      await backRef.putFile(backImage!);
      final frontUrl = await frontRef.getDownloadURL();
      final backUrl = await backRef.getDownloadURL();
      bool firestoreSuccess = false;
      try {
        // Debug: Print the idType to console
        print('Saving ID type: $idType');
        
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('VerifyID')
            .doc('id')
            .set({
          'frontUrl': frontUrl,
          'backUrl': backUrl,
          'idType': idType ?? 'Unknown', // Ensure it's not null
          'status': 'pending',
          'createdAt': DateTime.now(),
        });
        firestoreSuccess = true;
      } catch (e) {
        // Firestore write failed, but upload succeeded
        print('Firestore error: $e');
        firestoreSuccess = false;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(firestoreSuccess
                  ? 'ID submitted for verification.'
                  : 'Images uploaded successfully, but verification status not updated.')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() {
        error = 'Failed to upload. Please try again.';
        uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Check your ID',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: appBarFontSize,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - kToolbarHeight - 80,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (idType != null) ...[
                  Text(
                    'ID Type: $idType',
                    style: GoogleFonts.outfit(
                        fontSize: bodyFontSize, fontWeight: FontWeight.w600, color: cyan),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                ],
                Text(
                  'Please make sure there is enough lighting and the ID lettering is clear before continuing',
                  style: GoogleFonts.outfit(
                      fontSize: bodyFontSize, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                _imageCard('Front', frontImage, isMobile, isTablet),
                SizedBox(height: 12),
                _imageCard('Back', backImage, isMobile, isTablet),
                if (error != null) ...[
                  SizedBox(height: 12),
                  Text(error!,
                      style: GoogleFonts.outfit(
                          color: Colors.red, fontSize: bodyFontSize)),
                ],
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(cardRadius),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: uploading ? null : () {
                          // Clear the images and go back to retake photos
                          Navigator.pop(context);
                        },
                        child: Text('Retake',
                            style: GoogleFonts.outfit(fontSize: bodyFontSize)),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(cardRadius),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: uploading ? null : _uploadAndSubmit,
                        child: uploading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Text('Use this photo',
                                style: GoogleFonts.outfit(fontSize: bodyFontSize)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16), // Add bottom padding for scroll safety
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageCard(String label, File? image, bool isMobile, bool isTablet) {
    final imageHeight = isMobile ? 120.0 : isTablet ? 140.0 : 160.0;
    final iconSize = isMobile ? 40.0 : isTablet ? 50.0 : 60.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w500, fontSize: 16.0)),
        SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: imageHeight,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: image == null
              ? Icon(Icons.badge, size: iconSize, color: Colors.black38)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(image, fit: BoxFit.cover),
                ),
        ),
      ],
    );
  }
}
