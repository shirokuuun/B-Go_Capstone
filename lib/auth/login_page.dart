import 'package:b_go/auth/auth_services.dart';
import 'package:b_go/pages/conductor/ticketing/conductor_from.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:b_go/auth/forgotPassword_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:b_go/auth/conductor_login.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback showRegisterPage;
  const LoginPage({Key? key, required this.showRegisterPage}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  //text controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthServices _authServices = AuthServices();

  Future signIn() async {
    try {
      await _authServices.signInWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final firestoreEmail = doc.data()?['email'];
        if (firestoreEmail != user.email) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'email': user.email,
          });
        }
      }

      if (user == null) return;

      // Only clear fields after successful login
      emailController.clear();
      passwordController.clear();

      // Only work with conductors that have uid field (created via admin website)
      final query = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (!mounted) return; // <--- Add this before using context

      if (query.docs.isNotEmpty) {
        final conductorData = query.docs.first.data();
        final route = conductorData['route'] ?? '';
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ConductorFrom(role: 'Conductor', route: route),
          ),
        );
        // Only clear after navigation
        emailController.clear();
        passwordController.clear();
        return;
      } else {
        // Not a conductor, navigate as a normal user
        Navigator.pushReplacementNamed(context, '/user_selection');
        // Only clear after navigation
        emailController.clear();
        passwordController.clear();
        return;
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found for that email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'email-not-verified':
          message = 'Please verify your email address before logging in.';
          break;
        default:
          message = 'Login failed. Please try again.';
      }
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Login Failed"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("OK"),
            )
          ],
        ),
      );
      // Do NOT clear fields on failed login
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.38,
            decoration: BoxDecoration(
              color: Color(0xFFE5E9F0),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                double maxLogoWidth = 400.0; // Adjust this value as needed
                double logoWidth = 150;
                math.min(constraints.maxWidth * 0.4, maxLogoWidth);
                // Use Center to make sure the logo always stays in the middle, even if alignment changes
                return Transform.translate(
                  offset: Offset(0, -20),
                  child: Center(
                    child: Image.asset(
                      'assets/batrasco-logo.png',
                      width: logoWidth,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),

          // --- LOGIN BOX ---
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: Container(
                margin: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.24),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    // --- LOGIN BOX ---
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
                            "Welcome Back!",
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              color: const Color.fromARGB(255, 0, 0, 0),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 40),

                    // Email
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFE5E9F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 20.0),
                          child: TextField(
                            controller: emailController,
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

                    // Password
                    SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFE5E9F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 20.0),
                          child: TextField(
                            controller: passwordController,
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
                    SizedBox(height: 10),

                    // Forgot Password
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ForgotPasswordPage(),
                                ),
                              );
                            },
                            child: Text(
                              'Forgot Password?',
                              style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sign in button
                    SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0091AD),
                            padding: EdgeInsets.all(20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: signIn,
                          child: Text(
                            'Sign In',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),

                    // --- OUTSIDE THE BOX ---

                    // Or divider
                    Row(
                      children: [
                        const Expanded(
                            child: Divider(
                                thickness: 2, color: Color(0xFFE7E7E7))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text("Or",
                              style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500)),
                        ),
                        const Expanded(
                            child: Divider(
                                thickness: 1.5, color: Color(0xFFE7E7E7))),
                      ],
                    ),
                    SizedBox(height: 30),

                    // sign in with Google
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            try {
                              final userCredential =
                                  await _authServices.SignInWithGoogle();
                              if (userCredential == null) return;
                              
                              // Handle successful Google Sign-In
                              if (!mounted) return;
                              
                              final user = userCredential.user;
                              if (user != null) {
                                // Check if user is a conductor
                                String email = user.email!;
                                String username = email.split('@').first;
                                String conductorDocId = username[0].toUpperCase() + username.substring(1);

                                final conductorDoc = await FirebaseFirestore.instance
                                    .collection('conductors')
                                    .doc(conductorDocId)
                                    .get();

                                if (!mounted) return;

                                if (conductorDoc.exists) {
                                  final route = conductorDoc.data()?['route'] ?? '';
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ConductorFrom(role: 'Conductor', route: route),
                                    ),
                                  );
                                } else {
                                  // Not a conductor, navigate as a normal user
                                  Navigator.pushReplacementNamed(context, '/user_selection');
                                }
                              }
                            } catch (e) {
                              if (!mounted) return;
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text("Google Sign-In Failed"),
                                  content: Text(e.toString()),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: Text("OK"),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                          child: Image.asset(
                            'assets/google-icon.png',
                            height: 40,
                            width: 40,
                          ),
                        ),

                        SizedBox(width: 5),

                        // Phone Sign-In Icon
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context,
                                '/phone_login'); 
                          },
                          child: Image.asset(
                            'assets/phone-call.png',
                            height: 40,
                            width: 40,
                          ),
                        ),

                        SizedBox(width: 5),

                        // Conductor Login Icon
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ConductorLogin(),
                              ),
                            );
                          },
                          child: Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: Color(0xFFE5E9F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.directions_bus,
                              color: Color(0xFF0091AD),
                              size: 28,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 25),

                    // Register section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w500,),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4), // Increase tap area
                            minimumSize: Size(0, 0), // Remove min size if needed
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            "Sign Up",
                            style: GoogleFonts.outfit(
                              color: Color(0xFF0091AD),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}