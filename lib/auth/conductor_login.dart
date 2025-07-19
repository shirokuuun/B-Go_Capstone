import 'package:flutter/material.dart';
import 'package:b_go/pages/conductor/conductor_home.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // Hardcoded conductor credentials (email:password)
  final Map<String, String> _conductorAccounts = {
    'batangas_1@gmail.com': 'batangas1',
    'tiaong_1@gmail.com': 'tiaong1',
    'kahoy_1@gmail.com': 'mataasnakahoy1',
    'rosario_1@gmail.com': 'rosario1',
  };

  // Map conductor emails to their route names
  final Map<String, String> _conductorRoutes = {
    'batangas_1@gmail.com': 'Batangas',
    'tiaong_1@gmail.com': 'Tiaong',
    'kahoy_1@gmail.com': 'Mataas na Kahoy',
    'rosario_1@gmail.com': 'Rosario',
  };

  void _login() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (_conductorAccounts.containsKey(email) && _conductorAccounts[email] == password) {
      setState(() {
        _errorMessage = null;
      });
      final route = _conductorRoutes[email] ?? '';
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ConductorHome(
            role: 'Conductor',
            route: route,
            selectedIndex: 0,
          ),
        ),
      );
    } else {
      setState(() {
        _errorMessage = 'Invalid email or password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
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
                              "Welcome Back Conductor!",
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