import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:b_go/auth/auth_services.dart';
import 'package:responsive_framework/responsive_framework.dart';

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
      // Optionally fetch phone from Firestore if not in Auth
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

    // Add listener to email controller to trigger rebuild when text changes
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



  // Validate email and password for phone users
  String? _validateEmailAndPassword() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    // Check if user has email (was registered with email)
    bool hasEmail = user.email != null && user.email!.isNotEmpty;

    // If user doesn't have email (phone user) and wants to add email
    if (!hasEmail && _emailController.text.trim().isNotEmpty) {
      // Must provide password for email login
      if (_passwordController.text.trim().isEmpty) {
        return 'Password is required when adding email for login';
      }

      // Validate password strength
      if (_passwordController.text.length < 6) {
        return 'Password must be at least 6 characters long';
      }
    }

    // If user has email and wants to change it
    if (hasEmail && _emailController.text.trim() != user.email) {
      // Must provide password for email change
      if (_passwordController.text.trim().isEmpty) {
        return 'Password is required when changing email';
      }

      // Validate password strength
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
        maxWidth: 512, // Size restriction
        maxHeight: 512,
        imageQuality: 80, // Compress image
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
      // Show loading indicator
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

      // Upload image to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = storageRef.putFile(_selectedImage!);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update user profile with new photo URL
      await user.updatePhotoURL(downloadUrl);

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'profileImageUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local state
      setState(() {
        _currentProfileImageUrl = downloadUrl;
        _selectedImage = null; // Clear selected image after upload
      });

      // Close loading dialog
      Navigator.of(context).pop();

      _showCustomSnackBar('Profile picture updated successfully!', 'success');
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      _showCustomSnackBar('Failed to upload profile picture: $e', 'error');
    }
  }

  Future<void> _linkEmailToAccount(String email, String password) async {
    try {
      // Create email credential
      final emailCredential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      // Link the email credential to the current user
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
    // App color palette
    final primaryTeal = const Color(0xFF0091AD);
    
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    
    // Responsive sizing
    final appBarFontSize = isMobile ? 18.0 : isTablet ? 20.0 : 24.0;
    final sectionFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final titleFontSize = isMobile ? 15.0 : isTablet ? 16.0 : 18.0;
    final iconSize = isMobile ? 22.0 : isTablet ? 24.0 : 28.0;
    final trailingIconSize = isMobile ? 18.0 : isTablet ? 20.0 : 24.0;
    final avatarRadius = isMobile ? 60.0 : isTablet ? 70.0 : 80.0;
    final cameraIconSize = isMobile ? 20.0 : isTablet ? 24.0 : 28.0;
    
    // Responsive padding and spacing
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
              // Profile Picture Section
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
              
              // About You Section
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
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => _EditFieldPage(
                                  title: 'Edit Phone Number',
                                  initialValue: _phoneController.text,
                                  icon: Icons.phone,
                                  keyboardType: TextInputType.phone,
                                  onSave: (value) {
                                    _phoneController.text = value;
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
                    
                    // Email verification status
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
                    
                    // Helper text for phone users adding email
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
                    
                    // Action buttons
                    Center(
                      child: Column(
                        children: [
                          // Only show "Link Email for Login" button if user has no email or email is not verified
                          if (_emailController.text.isNotEmpty && 
                              _passwordController.text.isNotEmpty &&
                              (FirebaseAuth.instance.currentUser?.email == null ||
                               FirebaseAuth.instance.currentUser?.email!.isEmpty == true ||
                               FirebaseAuth.instance.currentUser?.emailVerified == false)) ...[
                            ElevatedButton(
                              onPressed: () async {
                                await _linkEmailToAccount(_emailController.text.trim(), _passwordController.text);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                elevation: 4,
                                padding: EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                              ),
                              child: Text(
                                'Link Email for Login',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ),
                            SizedBox(height: 16),
                          ],
                          
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      // Additional validation for email and password
                      String? validationError = _validateEmailAndPassword();
                      if (validationError != null) {
                        _showCustomSnackBar(validationError, 'warning');
                        return;
                      }

                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        try {
                          String newEmail = _emailController.text.trim();
                          String newPhone = _phoneController.text.trim();
                          // Ensure phone starts with +63
                          if (!newPhone.startsWith('+63')) {
                            if (newPhone.startsWith('0')) {
                              newPhone = '+63' + newPhone.substring(1);
                            } else {
                              newPhone = '+63' + newPhone;
                            }
                          }

                          // Show loading indicator
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

                          // Update Firebase Auth profile first
                          await user.updateDisplayName(_nameController.text);

                          // Check if user is adding email for the first time (phone user)
                              bool isPhoneUser = user.email == null || user.email!.isEmpty;

                          if (isPhoneUser && newEmail.isNotEmpty) {
                            // Phone user is adding email for the first time
                            try {
                              // Create email credential and link it
                                  final emailCredential = EmailAuthProvider.credential(
                                email: newEmail,
                                password: _passwordController.text,
                              );

                              // Link the email credential to the current user
                              await user.linkWithCredential(emailCredential);

                              // Update Firestore
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .update({
                                'name': _nameController.text,
                                'email': newEmail,
                                'phone': newPhone,
                                    'authMethod': 'phone_email', // Indicate both methods are available
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

                              // Send verification email
                              await user.sendEmailVerification();

                              // Close loading dialog
                              Navigator.of(context).pop();

                              // Show verification dialog
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

                              // Show success message
                              _showCustomSnackBar('Email linked successfully! Please check your email for verification.', 'success');

                              // Navigate back to profile page
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

                          // If email changed, use verifyBeforeUpdateEmail for secure update
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
                              // Don't sign out - let user continue using the app
                              return;
                            } on FirebaseAuthException catch (e) {
                              Navigator.of(context).pop();
                                  print('FirebaseAuthException: ${e.code} - ${e.message}');
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

                          // Update Firestore with all user data
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .update({
                            'name': _nameController.text,
                            'email': newEmail,
                            'phone': newPhone,
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                          // Update password if provided
                          if (_passwordController.text.isNotEmpty) {
                            await user.updatePassword(_passwordController.text);
                          }

                          // Close loading dialog
                          Navigator.of(context).pop();

                          // Show success message
                          _showCustomSnackBar('Profile updated successfully!', 'success');

                          // Navigate back to profile page
                          if (mounted) {
                            Navigator.pop(context);
                          }
                        } on FirebaseAuthException catch (e) {
                          // Close loading dialog
                          Navigator.of(context).pop();
                          String message;
                          if (e.code == 'requires-recent-login') {
                            // Prompt user to reauthenticate and log out
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
                          // Close loading dialog
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
    
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    
    // Responsive sizing
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
    
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    
    // Responsive sizing
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
