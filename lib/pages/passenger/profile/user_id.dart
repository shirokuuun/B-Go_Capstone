import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    final width = MediaQuery.of(context).size.width;
    final cyan = const Color(0xFF0091AD);
    final fontSizeTitle = width * 0.05;
    final fontSizeBody = width * 0.041;
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
          'Your ID',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: fontSizeTitle,
          ),
        ),
        centerTitle: true,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : idData == null
              ? Center(
                  child: Text('No ID submitted yet.',
                      style: GoogleFonts.outfit(fontSize: fontSizeBody)),
                )
              : _buildIDContent(width, fontSizeBody),
    );
  }

  Widget _buildIDContent(double width, double fontSizeBody) {
    final status = idData?['status'] ?? 'pending';
    final frontUrl = idData?['frontUrl'];
    final backUrl = idData?['backUrl'];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: width * 0.07, vertical: width * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (status == 'pending')
            Text('Your ID is pending verification.',
                style: GoogleFonts.outfit(fontSize: fontSizeBody, color: Colors.orange)),
          if (status == 'rejected')
            Column(
              children: [
                Text('Your ID was rejected. Please resubmit.',
                    style: GoogleFonts.outfit(fontSize: fontSizeBody, color: Colors.red)),
                SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/id_verification_instruction');
                  },
                  child: Text('Resubmit ID', style: GoogleFonts.outfit(fontSize: fontSizeBody)),
                ),
              ],
            ),
          if (status == 'verified')
            Text('Your ID is verified!',
                style: GoogleFonts.outfit(fontSize: fontSizeBody, color: Colors.green)),
          SizedBox(height: width * 0.04),
          if (frontUrl != null)
            _imageCard('Front', frontUrl, width),
          if (backUrl != null)
            _imageCard('Back', backUrl, width),
        ],
      ),
    );
  }

  Widget _imageCard(String label, String url, double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: width * 0.04)),
        SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: width * 0.22,
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
