import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    // App color palette
    final primaryTeal = const Color(0xFF0091AD);
    final lightTeal = const Color(0xFFE0F7FA);

    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    // Responsive sizing
    final appBarFontSize = isMobile
        ? 18.0
        : isTablet
            ? 20.0
            : 24.0;
    final nameFontSize = isMobile
        ? 24.0
        : isTablet
            ? 28.0
            : 32.0;
    final emailFontSize = isMobile
        ? 16.0
        : isTablet
            ? 18.0
            : 20.0;
    final titleFontSize = isMobile
        ? 15.0
        : isTablet
            ? 16.0
            : 18.0;
    final iconSize = isMobile
        ? 22.0
        : isTablet
            ? 24.0
            : 28.0;
    final trailingIconSize = isMobile
        ? 18.0
        : isTablet
            ? 20.0
            : 24.0;
    final avatarRadius = isMobile
        ? 60.0
        : isTablet
            ? 70.0
            : 80.0;

    // Responsive padding and spacing
    final horizontalPadding = isMobile
        ? 16.0
        : isTablet
            ? 20.0
            : 32.0;
    final listItemPadding = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;
    final profileSpacing = isMobile
        ? 24.0
        : isTablet
            ? 32.0
            : 40.0;

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryTeal,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: iconSize),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: appBarFontSize,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  children: [
                    // Profile Header Section
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(profileSpacing),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: avatarRadius,
                            backgroundImage: NetworkImage(
                              photoURL ??
                                  'https://randomuser.me/api/portraits/men/1.jpg',
                            ),
                            backgroundColor: Colors.grey[300],
                          ),
                          SizedBox(height: 16),
                          Text(
                            name ?? 'John Doe',
                            style: GoogleFonts.outfit(
                              fontSize: nameFontSize,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            email ?? 'No email found',
                            style: GoogleFonts.outfit(
                              fontSize: emailFontSize,
                              color: Colors.black54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // Profile Options
                    _ProfileRow(
                      icon: Icons.edit,
                      label: 'Edit Profile',
                      onTap: () async {
                        await Navigator.pushNamed(context, '/edit_profile');
                        _fetchUserData(); // Refresh after editing
                      },
                      isFirstItem: false,
                      iconSize: iconSize,
                      titleFontSize: titleFontSize,
                      trailingIconSize: trailingIconSize,
                      horizontalPadding: horizontalPadding,
                      listItemPadding: listItemPadding,
                      primaryTeal: primaryTeal,
                      lightTeal: lightTeal,
                    ),
                    _ProfileRow(
                      icon: Icons.badge,
                      label: 'Your ID',
                      onTap: () {
                        Navigator.pushNamed(context, '/user_id');
                      },
                      iconSize: iconSize,
                      titleFontSize: titleFontSize,
                      trailingIconSize: trailingIconSize,
                      horizontalPadding: horizontalPadding,
                      listItemPadding: listItemPadding,
                      primaryTeal: primaryTeal,
                      lightTeal: lightTeal,
                    ),
                    _ProfileRow(
                      icon: Icons.settings,
                      label: 'Settings',
                      onTap: () {
                        Navigator.pushNamed(context, '/settings');
                      },
                      iconSize: iconSize,
                      titleFontSize: titleFontSize,
                      trailingIconSize: trailingIconSize,
                      horizontalPadding: horizontalPadding,
                      listItemPadding: listItemPadding,
                      primaryTeal: primaryTeal,
                      lightTeal: lightTeal,
                    ),

                    SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isFirstItem;
  final double iconSize;
  final double titleFontSize;
  final double trailingIconSize;
  final double horizontalPadding;
  final double listItemPadding;
  final Color primaryTeal;
  final Color lightTeal;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isFirstItem = false,
    required this.iconSize,
    required this.titleFontSize,
    required this.trailingIconSize,
    required this.horizontalPadding,
    required this.listItemPadding,
    required this.primaryTeal,
    required this.lightTeal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isFirstItem ? lightTeal : Colors.white,
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: listItemPadding,
        ),
        leading: Icon(
          icon,
          color: primaryTeal,
          size: iconSize,
        ),
        title: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: primaryTeal,
          size: trailingIconSize,
        ),
        onTap: onTap,
      ),
    );
  }
}
