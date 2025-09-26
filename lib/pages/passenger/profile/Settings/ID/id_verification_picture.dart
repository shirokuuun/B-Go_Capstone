import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:responsive_framework/responsive_framework.dart';

class IDVerificationPicturePage extends StatefulWidget {
  const IDVerificationPicturePage({Key? key}) : super(key: key);

  @override
  State<IDVerificationPicturePage> createState() => _IDVerificationPicturePageState();
}

class _IDVerificationPicturePageState extends State<IDVerificationPicturePage> {
  File? _frontImage;
  File? _backImage;
  bool _checking = false;
  String? _selectedIDType;

  final List<String> _idTypes = ['Senior Citizen', 'Student', 'PWD'];

  @override
  void initState() {
    super.initState();
    _checking = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset state when returning to this screen
    setState(() {
      _checking = false;
      // Clear images when returning from review page
      _frontImage = null;
      _backImage = null;
      _selectedIDType = null;
    });
  }

  Future<void> _pickImage(bool isFront) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked != null) {
      final file = File(picked.path);
      
      // Simplified validation based on front/back requirements
      final validationResult = await _validateIDImage(file, isFront);
      if (validationResult.isValid) {
        setState(() {
          if (isFront) {
            _frontImage = file;
          } else {
            _backImage = file;
          }
        });
      } else {
        // Show error dialog only
        _showValidationErrorDialog(validationResult.errorMessage ?? 'Invalid image');
      }
    }
  }

  Future<ImageValidationResult> _validateIDImage(File imageFile, bool isFront) async {
    try {
      // Very basic file size check
      final bytes = await imageFile.length();
      if (bytes < 5 * 1024) { // Very low minimum - just 5KB
        return ImageValidationResult(
          isValid: false,
          errorMessage: 'Image file is too small. Please ensure the image is clear.',
        );
      }

      // Load image for analysis
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      // Very flexible aspect ratio - accept almost any reasonable ratio
      final aspectRatio = image.width / image.height;
      if (aspectRatio < 0.5 || aspectRatio > 4.0) { // Very wide range
        return ImageValidationResult(
          isValid: false,
          errorMessage: 'Image dimensions seem unusual. Please ensure you are capturing the full ID card.',
        );
      }

      // Very flexible image dimensions
      if (image.width < 100 || image.height < 100) { // Very low minimum
        return ImageValidationResult(
          isValid: false,
          errorMessage: 'Image resolution is too low. Please capture a clearer image.',
        );
      }

      // Different validation for front vs back
      if (isFront) {
        // For front: check for potential face-like features (very basic)
        final hasFaceLikeFeatures = await _checkForFaceLikeFeatures(image);
        if (!hasFaceLikeFeatures) {
          return ImageValidationResult(
            isValid: false,
            errorMessage: 'Front image should contain a photo/face. Please ensure you are capturing the front side of your ID.',
          );
        }
      } else {
        // For back: check for text content (very lenient)
        final hasTextContent = await _checkForTextContent(image);
        if (!hasTextContent) {
          return ImageValidationResult(
            isValid: false,
            errorMessage: 'Back image should contain text information. Please ensure you are capturing the back side of your ID.',
          );
        }
      }

      return ImageValidationResult(isValid: true, errorMessage: null);
    } catch (e) {
      return ImageValidationResult(
        isValid: false,
        errorMessage: 'Error processing image. Please try again.',
      );
    }
  }

  Future<bool> _checkForFaceLikeFeatures(ui.Image image) async {
    // Very basic face-like feature detection
    // This is a simplified check - in a real app, you might use face detection APIs
    
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return false;

    final bytes = byteData.buffer.asUint8List();
    int skinTonePixels = 0;
    int totalPixels = 0;

    for (int i = 0; i < bytes.length; i += 4) {
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      
      // Very basic skin tone detection (very lenient)
      if (r > g && r > b && r > 100 && g > 50 && b > 50) {
        skinTonePixels++;
      }
      totalPixels++;
    }

    // Very low threshold - just 2% of pixels need to show skin-like colors
    return (skinTonePixels / totalPixels) > 0.02;
  }

  Future<bool> _checkForTextContent(ui.Image image) async {
    // Very lenient text content detection
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return false;

    final bytes = byteData.buffer.asUint8List();
    int textLikePixels = 0;
    int totalPixels = 0;

    for (int i = 0; i < bytes.length; i += 4) {
      final r = bytes[i];
      final g = bytes[i + 1];
      final b = bytes[i + 2];
      
      // Very lenient contrast detection
      final brightness = (r + g + b) / 3;
      final contrast = (r - g).abs() + (g - b).abs() + (b - r).abs();
      
      if (contrast > 20 && (brightness < 150 || brightness > 150)) { // Very lenient
        textLikePixels++;
      }
      totalPixels++;
    }

    // Very low threshold - just 3% of pixels need to show text-like characteristics
    return (textLikePixels / totalPixels) > 0.03;
  }

  void _showValidationErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invalid Image', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        content: Text(message, style: GoogleFonts.outfit()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
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
    
    // Add a timeout to prevent stuck loading state
    Future.delayed(Duration(milliseconds: 100), () {
      if (!mounted) return;
      
      if (!_meetsStandards(_frontImage) || !_meetsStandards(_backImage)) {
        setState(() {
          _checking = false;
        });
        _showValidationErrorDialog('Please ensure both front and back images are clear and meet the standards.');
        return;
      }
      if (_selectedIDType == null) {
        setState(() {
          _checking = false;
        });
        _showValidationErrorDialog('Please select an ID type.');
        return;
      }
      
      // Reset checking state before navigation
      setState(() {
        _checking = false;
      });
      
      Navigator.pushNamed(
        context,
        '/id_verification_review',
        arguments: {
          'front': _frontImage,
          'back': _backImage,
          'idType': _selectedIDType,
        },
      );
    });
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
          'Take a photo of your ID',
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
                Text(
                  'Please make sure there is enough lighting and the ID lettering is clear before continuing',
                  style: GoogleFonts.outfit(fontSize: bodyFontSize, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                _imageCard('Front', _frontImage, () => _pickImage(true), isMobile, isTablet),
                SizedBox(height: 12),
                _imageCard('Back', _backImage, () => _pickImage(false), isMobile, isTablet),
                SizedBox(height: 16),
                _buildIDTypeDropdown(isMobile, isTablet, bodyFontSize),
                SizedBox(height: 16),
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
                    onPressed: (_frontImage != null && _backImage != null && _selectedIDType != null && !_checking) ? _next : null,
                    child: _checking
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('Next', style: GoogleFonts.outfit(fontSize: bodyFontSize)),
                  ),
                ),
                SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    // Show dialog to choose which side to upload
                    final String? selectedSide = await showDialog<String>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text(
                            'Upload Image',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                          ),
                          content: Text(
                            'Which side of your ID would you like to upload?',
                            style: GoogleFonts.outfit(),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop('front'),
                              child: Text(
                                'Front',
                                style: GoogleFonts.outfit(color: Color(0xFF0091AD)),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop('back'),
                              child: Text(
                                'Back',
                                style: GoogleFonts.outfit(color: Color(0xFF0091AD)),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(null),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.outfit(color: Colors.red),
                              ),
                            ),
                          ],
                        );
                      },
                    );

                    if (selectedSide != null) {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(source: ImageSource.gallery);
                      if (picked != null) {
                        final file = File(picked.path);
                        final isFront = selectedSide == 'front';
                        final validationResult = await _validateIDImage(file, isFront);
                        if (validationResult.isValid) {
                          setState(() {
                            if (isFront) {
                              _frontImage = file;
                            } else {
                              _backImage = file;
                            }
                          });
                        } else {
                          _showValidationErrorDialog(validationResult.errorMessage ?? 'Invalid image');
                        }
                      }
                    }
                  },
                  child: Text('Upload an Image', style: GoogleFonts.outfit(fontSize: bodyFontSize, color: Color(0xFF0091AD))),
                ),
                SizedBox(height: 16), // Add bottom padding for scroll safety
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIDTypeDropdown(bool isMobile, bool isTablet, double bodyFontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ID Type:',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w500,
            fontSize: 16.0,
          ),
        ),
        SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedIDType,
              hint: Text(
                'Select ID Type',
                style: GoogleFonts.outfit(
                  fontSize: bodyFontSize,
                  color: Colors.grey[600],
                ),
              ),
              isExpanded: true,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              items: _idTypes.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(
                    type,
                    style: GoogleFonts.outfit(fontSize: bodyFontSize),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedIDType = newValue;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _imageCard(String label, File? image, VoidCallback onTap, bool isMobile, bool isTablet) {
    final imageHeight = isMobile ? 160.0 : isTablet ? 140.0 : 160.0;
    final iconSize = isMobile ? 40.0 : isTablet ? 50.0 : 60.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 16.0)),
        SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            height: imageHeight,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: image == null
                ? Icon(Icons.camera_alt, size: iconSize, color: Colors.black38)
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

class ImageValidationResult {
  final bool isValid;
  final String? errorMessage;

  ImageValidationResult({
    required this.isValid,
    this.errorMessage,
  });
}
