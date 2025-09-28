import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:responsive_framework/responsive_framework.dart';

class UserIDPage extends StatefulWidget {
  const UserIDPage({Key? key}) : super(key: key);

  @override
  State<UserIDPage> createState() => _UserIDPageState();
}

class _UserIDPageState extends State<UserIDPage> {
  Map<String, dynamic>? idData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchID();
  }

  Future<void> _fetchID() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('VerifyID')
        .doc('id')
        .get();
    setState(() {
      idData = doc.data();
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive breakpoints
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final isTablet = ResponsiveBreakpoints.of(context).isTablet;

    // Responsive sizing
    final appBarFontSize = isMobile
        ? 18.0
        : isTablet
            ? 20.0
            : 24.0;
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
          'Your ID',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: appBarFontSize,
          ),
        ),
        centerTitle: true,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : idData == null
              ? Center(
                  child: Text('No ID submitted yet.',
                      style: GoogleFonts.outfit(fontSize: bodyFontSize)),
                )
              : _buildIDContent(isMobile, isTablet, bodyFontSize, horizontalPadding, verticalPadding),
    );
  }

  Widget _buildIDContent(bool isMobile, bool isTablet, double bodyFontSize, double horizontalPadding, double verticalPadding) {
    final status = idData?['status'] ?? 'pending';
    final frontUrl = idData?['frontUrl'];
    final backUrl = idData?['backUrl'];
    final idType = idData?['idType'] ?? 'Unknown';
    
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: verticalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (status == 'pending')
            Column(
              children: [
                Text('Your ID is pending verification.',
                    style: GoogleFonts.outfit(
                        fontSize: bodyFontSize, color: Colors.orange)),
                SizedBox(height: 8),
                Text('ID Type: $idType',
                    style: GoogleFonts.outfit(
                        fontSize: bodyFontSize, color: Colors.black87)),
              ],
            ),
          SizedBox(height: 12),
          if (status == 'rejected')
            Column(
              children: [
                Text('Your ID was rejected. Please resubmit.',
                    style: GoogleFonts.outfit(
                        fontSize: bodyFontSize, color: Colors.red)),
                SizedBox(height: 8),
                Text('ID Type: $idType',
                    style: GoogleFonts.outfit(
                        fontSize: bodyFontSize, color: Colors.black87)),
                SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/id_verification');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF01A03E),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Resubmit ID',
                      style: GoogleFonts.outfit(
                          fontSize: bodyFontSize, color: Colors.white)),
                ),
              ],
            ),
          if (status == 'verified')
            Column(
              children: [
                Text('Your ID is verified!',
                    style: GoogleFonts.outfit(
                        fontSize: bodyFontSize, color: Colors.green)),
                SizedBox(height: 8),
                Text('ID Type: $idType',
                    style: GoogleFonts.outfit(
                        fontSize: bodyFontSize, color: Colors.black87)),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                    child: Text(
                      'You will automatically receive discounts on pre-ticketing based on your verified ID type.',
                      style: GoogleFonts.outfit(
                          fontSize: bodyFontSize * 0.9, color: Colors.green[700]),
                      textAlign: TextAlign.center,
                    ),
                ),
              ],
            ),
          SizedBox(height: 16),
          if (frontUrl != null) _imageCard('Front', frontUrl, isMobile, isTablet),
          if (backUrl != null) _imageCard('Back', backUrl, isMobile, isTablet),
        ],
      ),
    );
  }

  Widget _imageCard(String label, String url, bool isMobile, bool isTablet) {
    final imageHeight = isMobile ? 200.0 : isTablet ? 250.0 : 300.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w500, fontSize: 16.0)),
        SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: imageHeight,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(url, fit: BoxFit.cover),
          ),
        ),
        SizedBox(height: 12),
      ],
    );
  }
}
