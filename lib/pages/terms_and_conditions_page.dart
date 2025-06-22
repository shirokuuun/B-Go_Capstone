import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsAndConditionsPage extends StatefulWidget {
  final VoidCallback showRegisterPage;
  const TermsAndConditionsPage({Key? key, required this.showRegisterPage}) : super(key: key);

  @override
  State<TermsAndConditionsPage> createState() => _TermsAndConditionsPageState();
}

class _TermsAndConditionsPageState extends State<TermsAndConditionsPage>{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'Terms and Conditions',
            style: GoogleFonts.bebasNeue(
              fontSize: 25,
              color:Colors.white 
              ),
            ),
        ),
        backgroundColor: Color(0xFF1D2B53),
        elevation: 0,
        iconTheme: IconThemeData(
          color: Colors.white
        ),
      ),

      body: Center(
        child: Text('Your terms and conditions go here.'),
      ),
    );
  }
}