import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
          'submittedAt': FieldValue.serverTimestamp(),
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
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final cyan = const Color(0xFF0091AD);
    final paddingH = width * 0.07;
    final fontSizeTitle = width * 0.05;
    final fontSizeBody = width * 0.041;
    final cardRadius = width * 0.03;
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
            fontSize: fontSizeTitle,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: width * 0.04),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: height - MediaQuery.of(context).padding.top - kToolbarHeight - width * 0.08,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (idType != null) ...[
                  Text(
                    'ID Type: $idType',
                    style: GoogleFonts.outfit(
                        fontSize: fontSizeBody, fontWeight: FontWeight.w600, color: cyan),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                ],
                Text(
                  'Please make sure there is enough lighting and the ID lettering is clear before continuing',
                  style: GoogleFonts.outfit(
                      fontSize: fontSizeBody, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: width * 0.04),
                _imageCard('Front', frontImage, width),
                SizedBox(height: width * 0.03),
                _imageCard('Back', backImage, width),
                if (error != null) ...[
                  SizedBox(height: 12),
                  Text(error!,
                      style: GoogleFonts.outfit(
                          color: Colors.red, fontSize: fontSizeBody)),
                ],
                SizedBox(height: width * 0.04),
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
                            style: GoogleFonts.outfit(fontSize: fontSizeBody)),
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
                                style: GoogleFonts.outfit(fontSize: fontSizeBody)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: width * 0.04), // Add bottom padding for scroll safety
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageCard(String label, File? image, double width) {
    final height = MediaQuery.of(context).size.height;
    final imageHeight = height * 0.21; // Responsive height calculation
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w500, fontSize: width * 0.04)),
        SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: imageHeight, // Use responsive height
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: image == null
              ? Icon(Icons.badge, size: width * 0.13, color: Colors.black38)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(image, fit: BoxFit.cover),
                ),
        ),
      ],
    );
  }
}
