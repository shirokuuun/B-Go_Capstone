import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:b_go/auth/auth_services.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  String? _currentProfileImageUrl;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
      _currentProfileImageUrl = user.photoURL;
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .then((doc) {
        if (doc.exists) {
          _phoneController.text = doc['phone'] ?? '';
        }
      });
    }

    _emailController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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

  String? _validateEmailAndPassword() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    bool hasEmail = user.email != null && user.email!.isNotEmpty;

    if (!hasEmail && _emailController.text.trim().isNotEmpty) {
      if (_passwordController.text.trim().isEmpty) {
        return 'Password is required when adding email for login';
      }
      if (_passwordController.text.length < 6) {
        return 'Password must be at least 6 characters long';
      }
    }

    if (hasEmail && _emailController.text.trim() != user.email) {
      if (_passwordController.text.trim().isEmpty) {
        return 'Password is required when changing email';
      }
      if (_passwordController.text.length < 6) {
        return 'Password must be at least 6 characters long';
      }
    }

    return null;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showCustomSnackBar('Failed to pick image: $e', 'error');
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_selectedImage == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00CFFF)),
            ),
          );
        },
      );

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = storageRef.putFile(_selectedImage!);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await user.updatePhotoURL(downloadUrl);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'profileImageUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _currentProfileImageUrl = downloadUrl;
        _selectedImage = null;
      });

      Navigator.of(context).pop();
      _showCustomSnackBar('Profile picture updated successfully!', 'success');
    } catch (e) {
      Navigator.of(context).pop();
      _showCustomSnackBar('Failed to upload profile picture: $e', 'error');
    }
  }

  Future<void> _linkEmailToAccount(String email, String password) async {
    try {
      final emailCredential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      await FirebaseAuth.instance.currentUser!
          .linkWithCredential(emailCredential);

      _showCustomSnackBar('Email successfully linked to your account! You can now log in using either phone or email.', 'success');
    } catch (e) {
      _showCustomSnackBar('Failed to link email: $e', 'error');
    }
  }

  Future<void> _resendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.sendEmailVerification();
        _showCustomSnackBar('Verification email sent again!', 'success');
      } catch (e) {
        _showCustomSnackBar('Failed to send verification email: $e', 'error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryTeal = const Color(0xFF0091AD);
    
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    
    final appBarFontSize = isMobile ? 18.0 : isTablet ? 20.0 : 24.0;
    final sectionFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final titleFontSize = isMobile ? 15.0 : isTablet ? 16.0 : 18.0;
    final iconSize = isMobile ? 22.0 : isTablet ? 24.0 : 28.0;
    final trailingIconSize = isMobile ? 18.0 : isTablet ? 20.0 : 24.0;
    final avatarRadius = isMobile ? 60.0 : isTablet ? 70.0 : 80.0;
    final cameraIconSize = isMobile ? 20.0 : isTablet ? 24.0 : 28.0;
    
    final horizontalPadding = isMobile ? 16.0 : isTablet ? 20.0 : 32.0;
    final profileSpacing = isMobile ? 24.0 : isTablet ? 32.0 : 40.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: iconSize),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: appBarFontSize,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
            child: Column(
              children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(profileSpacing),
                child: Column(
                  children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                          radius: avatarRadius,
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : (_currentProfileImageUrl != null
                              ? NetworkImage(_currentProfileImageUrl!)
                              : null) as ImageProvider?,
                      backgroundColor: Colors.grey[300],
                      child: _selectedImage == null &&
                              _currentProfileImageUrl == null
                          ? Icon(Icons.person,
                                  size: avatarRadius, color: Colors.grey[600])
                          : null,
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                              radius: isMobile ? 20.0 : isTablet ? 24.0 : 28.0,
                              backgroundColor: primaryTeal,
                          child: Icon(Icons.camera_alt,
                                  color: Colors.white, size: cameraIconSize),
                        ),
                      ),
                    ),
                  ],
                ),
                    SizedBox(height: 12),
                if (_selectedImage != null) ...[
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _uploadProfileImage,
                    style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    ),
                    child: Text(
                      'Upload Profile Picture',
                      style: GoogleFonts.outfit(
                              fontSize: titleFontSize, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
                  ],
                ),
              ),
              
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About you',
                      style: GoogleFonts.outfit(
                        fontSize: sectionFontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                          _ProfileField(
                            label: 'Name',
                            value: _nameController.text.isNotEmpty ? _nameController.text : 'Enter your name',
                        icon: Icons.person,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => _EditFieldPage(
                                  title: 'Edit Name',
                                  initialValue: _nameController.text,
                                  icon: Icons.person,
                                  onSave: (value) {
                                    _nameController.text = value;
                                    setState(() {});
                                  },
                                ),
                              ),
                            ),
                            iconSize: iconSize,
                            titleFontSize: titleFontSize,
                            trailingIconSize: trailingIconSize,
                            primaryTeal: primaryTeal,
                          ),
                          _ProfileField(
                        label: 'E-Mail',
                            value: _emailController.text.isNotEmpty ? _emailController.text : 'Enter your email',
                            icon: Icons.email,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => _EditFieldPage(
                                  title: 'Edit Email',
                                  initialValue: _emailController.text,
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                                  onSave: (value) {
                                    _emailController.text = value;
                                    setState(() {});
                                  },
                                ),
                              ),
                            ),
                            iconSize: iconSize,
                            titleFontSize: titleFontSize,
                            trailingIconSize: trailingIconSize,
                            primaryTeal: primaryTeal,
                          ),
                          _ProfileField(
                            label: 'Phone No.',
                            value: _phoneController.text.isNotEmpty ? _phoneController.text : 'Enter your phone number',
                            icon: Icons.phone,
                            onTap: () async {
                              // Navigate to phone editing with OTP
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => _EditPhoneWithOTPPage(
                                    initialPhone: _phoneController.text,
                                    onSave: (value) {
                                      _phoneController.text = value;
                                      setState(() {});
                                    },
                                  ),
                                ),
                              );
                            },
                            iconSize: iconSize,
                            titleFontSize: titleFontSize,
                            trailingIconSize: trailingIconSize,
                            primaryTeal: primaryTeal,
                          ),
                          _ProfileField(
                            label: 'Password',
                            value: '••••••••',
                            icon: Icons.lock,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => _EditPasswordPage(
                                  onSave: (password) {
                                    _passwordController.text = password;
                                    setState(() {});
                                  },
                                ),
                              ),
                            ),
                            iconSize: iconSize,
                            titleFontSize: titleFontSize,
                            trailingIconSize: trailingIconSize,
                            primaryTeal: primaryTeal,
                          ),
                        ],
                      ),
                    ),
                    
                      if (_emailController.text.isNotEmpty &&
                          FirebaseAuth.instance.currentUser?.email != null &&
                        FirebaseAuth.instance.currentUser?.email!.isNotEmpty == true) ...[
                      SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                          color: FirebaseAuth.instance.currentUser?.emailVerified == true
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                            color: FirebaseAuth.instance.currentUser?.emailVerified == true
                                  ? Colors.green.shade200
                                  : Colors.orange.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                              FirebaseAuth.instance.currentUser?.emailVerified == true
                                    ? Icons.verified
                                    : Icons.warning,
                              color: FirebaseAuth.instance.currentUser?.emailVerified == true
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                FirebaseAuth.instance.currentUser?.emailVerified == true
                                      ? 'Email verified. You can login using email'
                                      : 'Email not verified. Please check your inbox and verify your email',
                                  style: GoogleFonts.outfit(
                                  color: FirebaseAuth.instance.currentUser?.emailVerified == true
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    
                      if (_emailController.text.isNotEmpty &&
                          (FirebaseAuth.instance.currentUser?.email == null ||
                            FirebaseAuth.instance.currentUser?.email!.isEmpty == true)) ...[
                      SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Adding email requires a password for login functionality.',
                                  style: GoogleFonts.outfit(
                                    color: Colors.blue.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    
                SizedBox(height: 32),
                    
                    Center(
                      child: Column(
                        children: [
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      String? validationError = _validateEmailAndPassword();
                      if (validationError != null) {
                        _showCustomSnackBar(validationError, 'warning');
                        return;
                      }

                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        try {
                          String newEmail = _emailController.text.trim();

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return Center(
                                child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(primaryTeal),
                                ),
                              );
                            },
                          );

                          await user.updateDisplayName(_nameController.text);

                              bool isPhoneUser = user.email == null || user.email!.isEmpty;

                          if (isPhoneUser && newEmail.isNotEmpty) {
                            try {
                                  final emailCredential = EmailAuthProvider.credential(
                                email: newEmail,
                                password: _passwordController.text,
                              );

                              await user.linkWithCredential(emailCredential);

                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .update({
                                'name': _nameController.text,
                                'email': newEmail,
                                    'authMethod': 'phone_email',
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

                              await user.sendEmailVerification();

                              Navigator.of(context).pop();

                              await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                      title: Text('Verify your email', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                                  content: Text(
                                      'A verification link has been sent to $newEmail.\n\nPlease verify your email before you can login using email.\n\nYou can continue using the app with your phone number while waiting for verification.'),
                                  actions: [
                                    TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: Text('OK', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        _resendVerificationEmail();
                                      },
                                      child: Text('Resend Email'),
                                    ),
                                  ],
                                ),
                              );

                              _showCustomSnackBar('Email linked successfully! Please check your email for verification.', 'success');

                              if (mounted) {
                                Navigator.pop(context);
                              }
                              return;
                            } catch (e) {
                              Navigator.of(context).pop();
                              String message = 'Failed to link email';
                              if (e is FirebaseAuthException) {
                                switch (e.code) {
                                  case 'email-already-in-use':
                                        message = 'This email is already in use by another account';
                                    break;
                                  case 'invalid-email':
                                        message = 'Please enter a valid email address';
                                    break;
                                  case 'weak-password':
                                    message = 'Password is too weak';
                                    break;
                                  default:
                                        message = e.message ?? 'Failed to link email';
                                }
                              }
                              _showCustomSnackBar(message, 'error');
                              return;
                            }
                          }

                          if (newEmail != user.email && newEmail.isNotEmpty) {
                            try {
                              await user.verifyBeforeUpdateEmail(newEmail);
                              Navigator.of(context).pop();
                              await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Verify your new email'),
                                  content: Text(
                                      'A verification link has been sent to $newEmail.\n\nTo complete the change, please:\n1. Open your new email inbox.\n2. Click the verification link.\n3. After verification, you can log in using either your phone number or email address.\n\nNote: You may need to set a password for your email login to work.'),
                                  actions: [
                                    TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                      child: Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            } on FirebaseAuthException catch (e) {
                              Navigator.of(context).pop();
                              if (e.code == 'requires-recent-login') {
                                await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Re-authentication Required'),
                                        content: Text('For security reasons, please log in again to change your email.'),
                                    actions: [
                                      TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                        child: Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                                final authServices = AuthServices();
                                await authServices.signOut();
                                if (mounted) {
                                      Navigator.of(context).popUntil((route) => route.isFirst);
                                }
                                return;
                              } else {
                                _showCustomSnackBar('Failed to update email: ${e.message}', 'error');
                                return;
                              }
                            }
                          }

                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .update({
                            'name': _nameController.text,
                            'email': newEmail,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          if (_passwordController.text.isNotEmpty) {
                            await user.updatePassword(_passwordController.text);
                          }

                          Navigator.of(context).pop();
                          _showCustomSnackBar('Profile updated successfully!', 'success');

                          if (mounted) {
                            Navigator.pop(context);
                          }
                        } on FirebaseAuthException catch (e) {
                          Navigator.of(context).pop();
                          String message;
                          if (e.code == 'requires-recent-login') {
                            await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Re-authentication Required'),
                                    content: Text('For security reasons, please log in again to change your email.'),
                                actions: [
                                  TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                    child: Text('OK'),
                                  ),
                                ],
                              ),
                            );
                            final authServices = AuthServices();
                            await authServices.signOut();
                            if (mounted) {
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                            return;
                          }
                          switch (e.code) {
                            case 'invalid-email':
                              message = 'Please enter a valid email address.';
                              break;
                            case 'email-already-in-use':
                              message = 'This email is already in use.';
                              break;
                            case 'weak-password':
                              message = 'Password is too weak.';
                              break;
                            default:
                                  message = 'Failed to update profile. Please try again.';
                          }
                          _showCustomSnackBar(message, 'error');
                        } catch (e) {
                          Navigator.of(context).pop();
                          _showCustomSnackBar('An unexpected error occurred. Please try again.', 'error');
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                        backgroundColor: primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 4,
                    padding: EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                  ),
                  child: Text(
                              'Save Changes',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                SizedBox(height: 32),
              ],
            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;
  final double titleFontSize;
  final double trailingIconSize;
  final Color primaryTeal;

  const _ProfileField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    required this.iconSize,
    required this.titleFontSize,
    required this.trailingIconSize,
    required this.primaryTeal,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 0),
        child: Row(
          children: [
            Icon(
              icon,
              color: primaryTeal,
              size: iconSize,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: titleFontSize,
                      color: value.contains('Enter') ? Colors.grey[500] : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: primaryTeal,
              size: trailingIconSize,
            ),
          ],
        ),
      ),
    );
  }
}

// NEW: Edit Phone with OTP Page
class _EditPhoneWithOTPPage extends StatefulWidget {
  final String initialPhone;
  final Function(String) onSave;

  const _EditPhoneWithOTPPage({
    required this.initialPhone,
    required this.onSave,
  });

  @override
  State<_EditPhoneWithOTPPage> createState() => _EditPhoneWithOTPPageState();
}

class _EditPhoneWithOTPPageState extends State<_EditPhoneWithOTPPage> {
  late TextEditingController _phoneController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _verificationId;
  bool _showOTPFields = false;
  
  // OTP Controllers
  final List<TextEditingController> otpControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> focusNodes = List.generate(6, (index) => FocusNode());
  
  int _resendCountdown = 30;
  bool _canResend = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhone);
    
    // Add listeners for OTP fields
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
    _phoneController.dispose();
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _showCustomSnackBar(String message, String type) {
    Color backgroundColor;
    IconData icon;
    
    switch (type) {
      case 'success':
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'error':
        backgroundColor = Colors.red;
        icon = Icons.error;
        break;
      default:
        backgroundColor = Colors.grey;
        icon = Icons.info;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(message, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.all(16),
      ),
    );
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

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    String phone = _phoneController.text.trim();
    if (!phone.startsWith('+63')) {
      if (phone.startsWith('0')) {
        phone = '+63' + phone.substring(1);
      } else {
        phone = '+63' + phone;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {},
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to send OTP. Please try again.';
          });
          _showCustomSnackBar('Failed to send OTP: ${e.message}', 'error');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _showOTPFields = true;
            _isLoading = false;
          });
          _startResendCountdown();
          _showCustomSnackBar('OTP sent to $phone', 'success');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
          });
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to send OTP';
      });
      _showCustomSnackBar('Error: $e', 'error');
    }
  }

  Future<void> _verifyOTP() async {
    String otp = otpControllers.map((controller) => controller.text).join();
    
    if (otp.length != 6) {
      setState(() {
        _errorMessage = "Please enter the complete 6-digit code";
      });
      return;
    }

    if (_verificationId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      // Link phone credential to current user
      await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);

      String phone = _phoneController.text.trim();
      if (!phone.startsWith('+63')) {
        if (phone.startsWith('0')) {
          phone = '+63' + phone.substring(1);
        } else {
          phone = '+63' + phone;
        }
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        'phone': phone,
        'isPhoneVerified': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isLoading = false;
      });

      _showCustomSnackBar('Phone number verified successfully!', 'success');
      
      // Call the onSave callback and pop
      widget.onSave(phone);
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Incorrect code. Please try again";
      });
      
      for (var controller in otpControllers) {
        controller.clear();
      }
      focusNodes[0].requestFocus();
    }
  }

  Future<void> _resendOTP() async {
    if (!_canResend) return;
    await _sendOTP();
  }

  @override
  Widget build(BuildContext context) {
    final primaryTeal = const Color(0xFF0091AD);
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    
    final appBarFontSize = isMobile ? 18.0 : isTablet ? 20.0 : 24.0;
    final titleFontSize = isMobile ? 15.0 : isTablet ? 16.0 : 18.0;
    final iconSize = isMobile ? 22.0 : isTablet ? 24.0 : 28.0;
    final horizontalPadding = isMobile ? 16.0 : isTablet ? 20.0 : 32.0;
    final otpFieldSize = isMobile ? 40.0 : isTablet ? 50.0 : 60.0;
    final otpFieldMargin = isMobile ? 4.0 : isTablet ? 8.0 : 12.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: iconSize),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _showOTPFields ? 'Verify Phone Number' : 'Edit Phone Number',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: appBarFontSize,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(horizontalPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_showOTPFields) ...[
                  SizedBox(height: 32),
                  Text(
                    'Enter your new phone number',
                    style: GoogleFonts.outfit(
                      fontSize: titleFontSize + 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'We\'ll send you a verification code',
                    style: GoogleFonts.outfit(
                      fontSize: titleFontSize - 2,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 24),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone, color: primaryTeal),
                      hintText: '+639171234567',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primaryTeal),
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                    style: GoogleFonts.outfit(fontSize: titleFontSize),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Phone number is required';
                      }
                      return null;
                    },
                  ),
                ] else ...[
                  SizedBox(height: 32),
                  Text(
                    'Enter Verification Code',
                    style: GoogleFonts.outfit(
                      fontSize: isMobile ? 20.0 : 24.0,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "We've sent a 6-digit code to ${_phoneController.text}",
                    style: GoogleFonts.outfit(
                      fontSize: isMobile ? 14.0 : 16.0,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 32),
                  
                  // OTP Fields
                  Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final availableWidth = constraints.maxWidth;
                        final totalFieldWidth = (otpFieldSize * 6) + (otpFieldMargin * 10);
                        
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
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: _errorMessage != null 
                                          ? Colors.red 
                                          : (otpControllers[index].text.isNotEmpty 
                                              ? primaryTeal 
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
                                      color: primaryTeal,
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
                                  
                                  if (value.isEmpty && index > 0) {
                                    Future.delayed(Duration(milliseconds: 10), () {
                                      if (mounted && otpControllers[index].text.isEmpty) {
                                        focusNodes[index - 1].requestFocus();
                                      }
                                    });
                                  }
                                },
                                inputFormatters: [
                                  LengthLimitingTextInputFormatter(1),
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
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
                    ),
                  
                  SizedBox(height: 20),
                  
                  Center(
                    child: GestureDetector(
                      onTap: _canResend ? _resendOTP : null,
                      child: Text(
                        _canResend 
                            ? "Resend code" 
                            : "Resend code in $_resendCountdown seconds",
                        style: GoogleFonts.outfit(
                          color: _canResend ? primaryTeal : Colors.grey,
                          fontSize: isMobile ? 12.0 : 14.0,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
                
                SizedBox(height: 40),
                
                Center(
                  child: ElevatedButton(
                    onPressed: _isLoading 
                        ? null 
                        : (_showOTPFields ? _verifyOTP : _sendOTP),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 4,
                      padding: EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                      minimumSize: Size(200, 50),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _showOTPFields ? 'Verify' : 'Send OTP',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditFieldPage extends StatefulWidget {
  final String title;
  final String initialValue;
  final IconData icon;
  final TextInputType? keyboardType;
  final Function(String) onSave;

  const _EditFieldPage({
    required this.title,
    required this.initialValue,
    required this.icon,
    this.keyboardType,
    required this.onSave,
  });

  @override
  State<_EditFieldPage> createState() => _EditFieldPageState();
}

class _EditFieldPageState extends State<_EditFieldPage> {
  late TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryTeal = const Color(0xFF0091AD);
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    
    final appBarFontSize = isMobile ? 18.0 : isTablet ? 20.0 : 24.0;
    final titleFontSize = isMobile ? 15.0 : isTablet ? 16.0 : 18.0;
    final iconSize = isMobile ? 22.0 : isTablet ? 24.0 : 28.0;
    final horizontalPadding = isMobile ? 16.0 : isTablet ? 20.0 : 32.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: iconSize),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: appBarFontSize,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 32),
                TextFormField(
                  controller: _controller,
                  keyboardType: widget.keyboardType,
                  decoration: InputDecoration(
                    labelText: widget.title.replaceAll('Edit ', ''),
                    prefixIcon: Icon(widget.icon, color: primaryTeal),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryTeal),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  style: GoogleFonts.outfit(fontSize: titleFontSize),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'This field is required';
                    }
                    return null;
                  },
                ),
                Spacer(),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.onSave(_controller.text.trim());
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 4,
                      padding: EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                    ),
                    child: Text(
                      'Save',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditPasswordPage extends StatefulWidget {
  final Function(String) onSave;

  const _EditPasswordPage({required this.onSave});

  @override
  State<_EditPasswordPage> createState() => _EditPasswordPageState();
}

class _EditPasswordPageState extends State<_EditPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryTeal = const Color(0xFF0091AD);
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    
    final appBarFontSize = isMobile ? 18.0 : isTablet ? 20.0 : 24.0;
    final titleFontSize = isMobile ? 15.0 : isTablet ? 16.0 : 18.0;
    final iconSize = isMobile ? 22.0 : isTablet ? 24.0 : 28.0;
    final horizontalPadding = isMobile ? 16.0 : isTablet ? 20.0 : 32.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: iconSize),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit Password',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: appBarFontSize,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 32),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock, color: primaryTeal),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: primaryTeal,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryTeal),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  style: GoogleFonts.outfit(fontSize: titleFontSize),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline, color: primaryTeal),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        color: primaryTeal,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryTeal),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  style: GoogleFonts.outfit(fontSize: titleFontSize),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                Spacer(),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.onSave(_passwordController.text.trim());
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 4,
                      padding: EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                    ),
                    child: Text(
                      'Save Password',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}