import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:b_go/auth/auth_services.dart';
import 'package:responsive_framework/responsive_framework.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? name;
  String? email;
  String? phone;
  String? photoURL;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Not logged in, redirect to login or user selection
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      });
    } else {
      _fetchUserData();
    }
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        name = doc.data()?['name'] ?? user.displayName ?? 'John Doe';
        email = doc.data()?['email'] ?? user.email ?? 'No email found';
        photoURL = user.photoURL;
        isLoading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Called when returning from EditProfile
    _fetchUserData();
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final isDesktop = ResponsiveBreakpoints.of(context).isDesktop;
    
    // Responsive sizing
    final titleFontSize = isMobile ? 20.0 : isTablet ? 22.0 : 24.0;
    final nameFontSize = isMobile ? 24.0 : isTablet ? 28.0 : 32.0;
    final emailFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    final buttonFontSize = isMobile ? 18.0 : isTablet ? 20.0 : 22.0;
    final logoutFontSize = isMobile ? 20.0 : isTablet ? 22.0 : 24.0;
    final avatarRadius = isMobile ? 54.0 : isTablet ? 64.0 : 74.0;
    final editIconRadius = isMobile ? 16.0 : isTablet ? 20.0 : 24.0;
    final editIconSize = isMobile ? 16.0 : isTablet ? 20.0 : 24.0;
    final logoutAvatarRadius = isMobile ? 20.0 : isTablet ? 24.0 : 28.0;
    final logoutIconSize = isMobile ? 20.0 : isTablet ? 24.0 : 28.0;
    final topSpacing = isMobile ? 24.0 : isTablet ? 32.0 : 40.0;
    final nameSpacing = isMobile ? 16.0 : isTablet ? 20.0 : 24.0;
    final buttonSpacing = isMobile ? 16.0 : isTablet ? 20.0 : 24.0;
    final bottomSpacing = isMobile ? 32.0 : isTablet ? 40.0 : 48.0;
    final buttonPadding = isMobile ? 32.0 : isTablet ? 40.0 : 48.0;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Not logged in, redirect
      Future.microtask(() {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      });
      return SizedBox.shrink(); // Or a loading indicator
    }
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
          'Profile',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: titleFontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  SizedBox(height: topSpacing),
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: avatarRadius,
                        backgroundImage: NetworkImage(
                          photoURL ??
                              'https://randomuser.me/api/portraits/men/1.jpg',
                        ),
                        backgroundColor: Colors.grey[300],
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: CircleAvatar(
                          radius: editIconRadius,
                          backgroundColor: Color(0xFF0091AD),
                          child:
                              Icon(Icons.edit, color: Colors.white, size: editIconSize),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: nameSpacing),
                  Text(
                    name ?? 'John Doe',
                    style: GoogleFonts.outfit(
                      fontSize: nameFontSize,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    email ?? 'No email found',
                    style: GoogleFonts.outfit(
                      fontSize: emailFontSize,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: buttonSpacing),
                  ElevatedButton(
                    onPressed: () async {
                      await Navigator.pushNamed(context, '/edit_profile');
                      _fetchUserData(); // Refresh after editing
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0091AD),
                      foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 4,
                      padding:
                          EdgeInsets.symmetric(horizontal: buttonPadding, vertical: 12),
                    ),
                    child: Text(
                      'Edit Profile',
                      style: GoogleFonts.outfit(
                        fontSize: buttonFontSize,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: bottomSpacing),
                  _ProfileRow(
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () {
                      Navigator.pushNamed(context, '/settings');
                    },
                  ),
                  _ProfileRow(
                    icon: Icons.badge,
                    label: 'Your ID',
                    onTap: () {
                      Navigator.pushNamed(context, '/user_id');
                    },
                  ),
                  Spacer(),
                  Padding(
                    padding: EdgeInsets.only(bottom: bottomSpacing),
                    child: GestureDetector(
                      onTap: () async {
                        final authServices = AuthServices();
                        await authServices.signOut();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                              context, '/login', (route) => false);
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.black,
                            radius: logoutAvatarRadius,
                            child:
                                Icon(Icons.logout, color: Colors.red, size: logoutIconSize),
                          ),
                          SizedBox(width: isMobile ? 8 : 12),
                          Text(
                            'Log Out',
                            style: GoogleFonts.outfit(
                              color: Colors.red,
                              fontSize: logoutFontSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;
    final isDesktop = ResponsiveBreakpoints.of(context).isDesktop;
    
    // Responsive sizing
    final labelFontSize = isMobile ? 16.0 : isTablet ? 18.0 : 20.0;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Color.fromARGB(255, 1, 123, 148),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(
        label,
        style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: labelFontSize),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.black),
      onTap: onTap,
    );
  }
}
