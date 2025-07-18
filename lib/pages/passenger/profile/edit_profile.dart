import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
      // Optionally fetch phone from Firestore if not in Auth
      FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
        if (doc.exists) {
          _phoneController.text = doc['phone'] ?? '';
        }
      });
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
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.outfit(
            color: Colors.black,
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
                      backgroundImage: NetworkImage(
                        'https://randomuser.me/api/portraits/men/1.jpg',
                      ),
                      backgroundColor: Colors.grey[300],
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFF00CFFF),
                        child: Icon(Icons.camera_alt, color: Colors.black, size: 16),
                      ),
                    ),
                  ],
                ),
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
                      SizedBox(height: 16),
                      _ProfileTextField(
                        controller: _phoneController,
                        label: 'Phone No.',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        prefix: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text('+63', style: GoogleFonts.outfit()),
                        ),
                      ),
                      SizedBox(height: 16),
                      _ProfileTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock,
                        obscureText: true,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
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
                        // Update Firebase Auth profile
                        await user.updateDisplayName(_nameController.text);
                        if (newEmail != user.email) {
                          try {
                            await user.updateEmail(newEmail);
                          } on FirebaseAuthException catch (e) {
                            String message;
                            switch (e.code) {
                              case 'requires-recent-login':
                                message = 'Please re-authenticate to change your email.';
                                break;
                              case 'invalid-email':
                                message = 'Please enter a valid email address.';
                                break;
                              case 'email-already-in-use':
                                message = 'This email is already in use.';
                                break;
                              default:
                                message = 'Failed to update email. Please try again.';
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                            return;
                          }
                        }
                        // Update Firestore (after Auth update to keep in sync)
                        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                          'name': _nameController.text,
                          'email': newEmail,
                          'phone': newPhone,
                        });
                        // Optionally update password
                        if (_passwordController.text.isNotEmpty) {
                          await user.updatePassword(_passwordController.text);
                        }
                        await user.reload();
                        if (mounted) {
                          Navigator.pop(context); // Go back to profile page
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00CFFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 4,
                    padding: EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                  ),
                  child: Text(
                    'Confirm',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w500),
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
  final Widget? prefix;

  const _ProfileTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.prefix,
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
        prefix: prefix,
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