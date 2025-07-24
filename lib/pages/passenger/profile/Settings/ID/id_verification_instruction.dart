import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IDVerificationInstructionPage extends StatelessWidget {
  final VoidCallback? onNext;
  const IDVerificationInstructionPage({Key? key, this.onNext})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
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
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'ID Verification Instructions',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: fontSizeTitle,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: width * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    'Take a clear photo of your\nID for verifications',
                    style: GoogleFonts.outfit(
                        fontSize: fontSizeBody, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: width * 0.02),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text('If you have questions, please visit our ',
                            style: GoogleFonts.outfit(fontSize: fontSizeBody),
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
                              fontSize: fontSizeBody,
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
            SizedBox(height: width * 0.06),
            _idSample('Front', width),
            SizedBox(height: width * 0.03),
            _idSample('Back', width),
            SizedBox(height: width * 0.06),
            Text('ID Photo Standards:',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w500, fontSize: fontSizeBody),
                textAlign: TextAlign.left,
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.visible),
            SizedBox(height: 6),
            _bullet('Government/school-issued and valid', fontSizeBody),
            _bullet('Photo must be clear, well-lit, and show the entire ID',
                fontSizeBody),
            _bullet('No glare, blur, or obstructions', fontSizeBody),
            _bullet('Both front and back required for Student/PWD/Senior',
                fontSizeBody),
            _bullet('Name and photo must be readable', fontSizeBody),
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
                onPressed: onNext ?? () {
                  Navigator.pushNamed(context, '/id_verification_picture');
                },
                child: Text('Next', style: GoogleFonts.outfit(fontSize: fontSizeBody)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _idSample(String label, double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w500, fontSize: width * 0.04)),
        SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: width * 0.22,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.badge, size: width * 0.13, color: Colors.black38),
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
