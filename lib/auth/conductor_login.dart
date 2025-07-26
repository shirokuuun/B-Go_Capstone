import 'package:flutter/material.dart';
import 'package:b_go/pages/conductor/conductor_home.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:b_go/responsiveness/responsive_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConductorLogin extends StatefulWidget {
  const ConductorLogin({super.key});

  @override
  State<ConductorLogin> createState() => _ConductorLoginState();
}

class _ConductorLoginState extends State<ConductorLogin> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;

  // Map email to Firestore doc ID
  final Map<String, String> _conductorDocIds = {
    'batangas_1@gmail.com': 'Batangas_1',
    'tiaong_1@gmail.com': 'Tiaong_1',
    'kahoy_1@gmail.com': 'Kahoy_1',
    'rosario_1@gmail.com': 'Rosario_1',
    'san_juan_1@gmail.com': 'San_Juan_1'
  };

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      // Use Firebase Auth for sign-in
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      setState(() {
        _errorMessage = null;
      });

      // Get doc ID mapped from email
      final docId = _conductorDocIds[email];
      if (docId == null) {
        setState(() {
          _errorMessage = 'No conductor record found for this email.';
        });
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(docId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final route = data['route'] ?? '';
        final placeCollection = data['placeCollection'] ?? 'Place';

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ConductorHome(
              role: 'Conductor',
              route: route,
              placeCollection: placeCollection,
              selectedIndex: 0,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'No conductor record found for this email.';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Login failed. Please try again.';
      });
    } catch (e) {
      print("Error fetching conductor data: $e");
      setState(() {
        _errorMessage = 'Failed to fetch conductor route.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive responsive = Responsive(context);
    return Scaffold(
      backgroundColor: const Color(0xFFE5E9F0),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 24),
            Center(
              child: Image.asset(
                'assets/batrasco-logo.png',
                width: 150,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                  padding: EdgeInsets.only(
                    top: responsive.height * 0.05,
                    left: responsive.width * 0.07,
                    right: responsive.width * 0.07,
                    bottom: responsive.height * 0.20,
                  ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 20),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              "Login",
                              style: GoogleFonts.outfit(
                                fontSize: 45,
                              ),
                            ),
                            Text(
                              "Welcome Back, Conductor!",
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                color: const Color.fromARGB(255, 0, 0, 0),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Email
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E9F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20.0),
                            child: TextField(
                              controller: _emailController,
                              style: GoogleFonts.outfit(color: Colors.black),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: "Email",
                                hintStyle: GoogleFonts.outfit(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Password
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E9F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20.0),
                            child: TextField(
                              controller: _passwordController,
                              obscureText: true,
                              style: GoogleFonts.outfit(color: Colors.black),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: "Password",
                                hintStyle: GoogleFonts.outfit(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Error message
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D2B53),
                              padding: const EdgeInsets.all(20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              _login();
                            },
                            child: Text(
                              'Login',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}