import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:b_go/auth/auth_services.dart';

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

  // Check if user was registered with phone number
  Future<bool> _isPhoneRegisteredUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final authMethod = doc.data()?['authMethod'];
        return authMethod == 'phone';
      }
    } catch (e) {
      print('Error checking user registration method: $e');
    }
    return false;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile picture updated successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload profile picture: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Email successfully linked to your account! You can now log in using either phone or email.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to link email: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _resendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification email sent again!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification email: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6F6F6),
      appBar: AppBar(
        backgroundColor: Color(0xFF0091AD),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                SizedBox(height: 24),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundImage: _selectedImage != null
                          ? FileImage(_selectedImage!)
                          : (_currentProfileImageUrl != null
                              ? NetworkImage(_currentProfileImageUrl!)
                              : null) as ImageProvider?,
                      backgroundColor: Colors.grey[300],
                      child: _selectedImage == null &&
                              _currentProfileImageUrl == null
                          ? Icon(Icons.person,
                              size: 54, color: Colors.grey[600])
                          : null,
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Color(0xFF0091AD),
                          child: Icon(Icons.camera_alt,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_selectedImage != null) ...[
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _uploadProfileImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0091AD),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    ),
                    child: Text(
                      'Upload Profile Picture',
                      style: GoogleFonts.outfit(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
                SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _ProfileTextField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.person,
                      ),
                      SizedBox(height: 16),
                      _ProfileTextField(
                        controller: _emailController,
                        label: 'E-Mail',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      // Show email verification status
                      if (_emailController.text.isNotEmpty &&
                          FirebaseAuth.instance.currentUser?.email != null &&
                          FirebaseAuth
                                  .instance.currentUser?.email!.isNotEmpty ==
                              true) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: FirebaseAuth
                                        .instance.currentUser?.emailVerified ==
                                    true
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: FirebaseAuth.instance.currentUser
                                          ?.emailVerified ==
                                      true
                                  ? Colors.green.shade200
                                  : Colors.orange.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                FirebaseAuth.instance.currentUser
                                            ?.emailVerified ==
                                        true
                                    ? Icons.verified
                                    : Icons.warning,
                                color: FirebaseAuth.instance.currentUser
                                            ?.emailVerified ==
                                        true
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  FirebaseAuth.instance.currentUser
                                              ?.emailVerified ==
                                          true
                                      ? 'Email verified. You can login using email'
                                      : 'Email not verified. Please check your inbox and verify your email',
                                  style: GoogleFonts.outfit(
                                    color: FirebaseAuth.instance.currentUser
                                                ?.emailVerified ==
                                            true
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8),
                      ],
                      // Show helper text for phone users adding email
                      if (_emailController.text.isNotEmpty &&
                          (FirebaseAuth.instance.currentUser?.email == null ||
                              FirebaseAuth
                                      .instance.currentUser?.email!.isEmpty ==
                                  true)) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.blue.shade700, size: 20),
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
                        SizedBox(height: 8),
                      ],
                      SizedBox(height: 16),
                      _ProfileTextField(
                        controller: _phoneController,
                        label: 'Phone No.',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      SizedBox(height: 16),
                      _ProfileTextField(
                        controller: _passwordController,
                        label: 'Password (required for email login)',
                        icon: Icons.lock,
                        obscureText: true,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
                // Add button to link email with password
                if (_emailController.text.isNotEmpty &&
                    _passwordController.text.isNotEmpty) ...[
                  ElevatedButton(
                    onPressed: () async {
                      await _linkEmailToAccount(_emailController.text.trim(),
                          _passwordController.text);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 4,
                      padding:
                          EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                    ),
                    child: Text(
                      'Link Email for Login',
                      style: GoogleFonts.outfit(
                          fontSize: 16, fontWeight: FontWeight.w500),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(validationError),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 3),
                          ),
                        );
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF00CFFF)),
                                ),
                              );
                            },
                          );

                          // Update Firebase Auth profile first
                          await user.updateDisplayName(_nameController.text);

                          // Check if user is adding email for the first time (phone user)
                          bool isPhoneUser =
                              user.email == null || user.email!.isEmpty;

                          if (isPhoneUser && newEmail.isNotEmpty) {
                            // Phone user is adding email for the first time
                            try {
                              // Create email credential and link it
                              final emailCredential =
                                  EmailAuthProvider.credential(
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
                                'authMethod':
                                    'phone_email', // Indicate both methods are available
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
                                  title: Text('Verify your email', style: GoogleFonts.outfit(fontWeight: FontWeight.w600),),
                                  content: Text(
                                      'A verification link has been sent to $newEmail.\n\nPlease verify your email before you can login using email.\n\nYou can continue using the app with your phone number while waiting for verification.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: Text(
                                        'OK',
                                        style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w600),
                                      ),
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Email linked successfully! Please check your email for verification.'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 3),
                                ),
                              );

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
                                    message =
                                        'This email is already in use by another account';
                                    break;
                                  case 'invalid-email':
                                    message =
                                        'Please enter a valid email address';
                                    break;
                                  case 'weak-password':
                                    message = 'Password is too weak';
                                    break;
                                  default:
                                    message =
                                        e.message ?? 'Failed to link email';
                                }
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(message),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 3),
                                ),
                              );
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
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                              // Don't sign out - let user continue using the app
                              return;
                            } on FirebaseAuthException catch (e) {
                              Navigator.of(context).pop();
                              print(
                                  'FirebaseAuthException: ${e.code} - ${e.message}');
                              if (e.code == 'requires-recent-login') {
                                await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Re-authentication Required'),
                                    content: Text(
                                        'For security reasons, please log in again to change your email.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                                final authServices = AuthServices();
                                await authServices.signOut();
                                if (mounted) {
                                  Navigator.of(context)
                                      .popUntil((route) => route.isFirst);
                                }
                                return;
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Failed to update email: ${e.message}'),
                                    backgroundColor: Colors.red,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Profile updated successfully!'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );

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
                                content: Text(
                                    'For security reasons, please log in again to change your email.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: Text('OK'),
                                  ),
                                ],
                              ),
                            );
                            final authServices = AuthServices();
                            await authServices.signOut();
                            if (mounted) {
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst);
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
                              message =
                                  'Failed to update profile. Please try again.';
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(message),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        } catch (e) {
                          // Close loading dialog
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'An unexpected error occurred. Please try again.'),
                              backgroundColor: Colors.red,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0091AD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 4,
                    padding: EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                  ),
                  child: Text(
                    'Confirm',
                    style: GoogleFonts.outfit(
                        fontSize: 20, fontWeight: FontWeight.w500),
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

class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.black),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      style: GoogleFonts.outfit(fontSize: 16),
    );
  }
}
