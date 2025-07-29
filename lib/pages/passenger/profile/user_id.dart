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
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Your ID',
          style: GoogleFonts.outfit(
            color: Colors.white,
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
    final idType = idData?['idType'] ?? 'Unknown';
    
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: width * 0.07, vertical: width * 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (status == 'pending')
            Column(
              children: [
                Text('Your ID is pending verification.',
                    style: GoogleFonts.outfit(
                        fontSize: fontSizeBody, color: Colors.orange)),
                SizedBox(height: 8),
                Text('ID Type: $idType',
                    style: GoogleFonts.outfit(
                        fontSize: fontSizeBody, color: Colors.black87)),
              ],
            ),
          SizedBox(height: 12),
          if (status == 'rejected')
            Column(
              children: [
                Text('Your ID was rejected. Please resubmit.',
                    style: GoogleFonts.outfit(
                        fontSize: fontSizeBody, color: Colors.red)),
                SizedBox(height: 8),
                Text('ID Type: $idType',
                    style: GoogleFonts.outfit(
                        fontSize: fontSizeBody, color: Colors.black87)),
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
                          fontSize: fontSizeBody, color: Colors.white)),
                ),
              ],
            ),
          if (status == 'verified')
            Column(
              children: [
                Text('Your ID is verified!',
                    style: GoogleFonts.outfit(
                        fontSize: fontSizeBody, color: Colors.green)),
                SizedBox(height: 8),
                Text('ID Type: $idType',
                    style: GoogleFonts.outfit(
                        fontSize: fontSizeBody, color: Colors.black87)),
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
                        fontSize: fontSizeBody * 0.9, color: Colors.green[700]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          SizedBox(height: width * 0.04),
          if (frontUrl != null) _imageCard('Front', frontUrl, width),
          if (backUrl != null) _imageCard('Back', backUrl, width),
        ],
      ),
    );
  }

  Widget _imageCard(String label, String url, double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w500, fontSize: width * 0.04)),
        SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: width * 0.55,
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
