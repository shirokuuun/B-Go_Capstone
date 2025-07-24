import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class IDVerificationPicturePage extends StatefulWidget {
  const IDVerificationPicturePage({Key? key}) : super(key: key);

  @override
  State<IDVerificationPicturePage> createState() => _IDVerificationPicturePageState();
}

class _IDVerificationPicturePageState extends State<IDVerificationPicturePage> {
  File? _frontImage;
  File? _backImage;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checking = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset _checking when returning to this screen
    setState(() {
      _checking = false;
    });
  }

  Future<void> _pickImage(bool isFront) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked != null) {
      setState(() {
        if (isFront) {
          _frontImage = File(picked.path);
        } else {
          _backImage = File(picked.path);
        }
        _error = null;
      });
    }
  }

  bool _meetsStandards(File? image) {
    // Basic checks: file exists, not too small, can add more later
    if (image == null) return false;
    final bytes = image.lengthSync();
    if (bytes < 20 * 1024) return false; // At least 20KB
    // TODO: Add more checks (brightness, blur, corners) if needed
    return true;
  }

  void _next() {
    setState(() => _checking = true);
    if (!_meetsStandards(_frontImage) || !_meetsStandards(_backImage)) {
      setState(() {
        _error = 'Please ensure both front and back images are clear and meet the standards.';
        _checking = false;
      });
      return;
    }
    Navigator.pushNamed(
      context,
      '/id_verification_review',
      arguments: {
        'front': _frontImage,
        'back': _backImage,
      },
    );
  }

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
          'Take a photo of your ID',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: fontSizeTitle,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: width * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Please make sure there is enough lighting and the ID lettering is clear before continuing',
              style: GoogleFonts.outfit(fontSize: fontSizeBody, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: width * 0.04),
            _imageCard('Front', _frontImage, () => _pickImage(true), width),
            SizedBox(height: width * 0.03),
            _imageCard('Back', _backImage, () => _pickImage(false), width),
            if (_error != null) ...[
              SizedBox(height: 12),
              Text(_error!, style: GoogleFonts.outfit(color: Colors.red, fontSize: fontSizeBody)),
            ],
            Spacer(),
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
                onPressed: (_frontImage != null && _backImage != null && !_checking) ? _next : null,
                child: _checking
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Next', style: GoogleFonts.outfit(fontSize: fontSizeBody)),
              ),
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  setState(() {
                    if (_frontImage == null) {
                      _frontImage = File(picked.path);
                    } else {
                      _backImage = File(picked.path);
                    }
                  });
                }
              },
              child: Text('Upload an Image', style: GoogleFonts.outfit(fontSize: fontSizeBody)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageCard(String label, File? image, VoidCallback onTap, double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: width * 0.04)),
        SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: width * 0.55,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: image == null
                ? Icon(Icons.camera_alt, size: width * 0.13, color: Colors.black38)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(image, fit: BoxFit.cover),
                  ),
          ),
        ),
      ],
    );
  }
}
