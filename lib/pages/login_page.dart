import 'package:b_go/auth/auth_services.dart';
import 'package:b_go/pages/conductor/conductor_from.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:b_go/pages/forgotPassword_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
      // Optionally, navigate to another page or show success
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/user_selection');
    } on FirebaseAuthException catch (e) {
      // Show error to user
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Login Failed"),
          content: Text(e.message ?? "Unknown error"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("OK"),
            )
          ],
        ),
      );
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
            padding: const EdgeInsets.only(left: 10, bottom: 35),
            alignment: Alignment.topLeft,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/batrasco-logo.png', // Replace with your logo asset
                  width: 150,

                  fit: BoxFit.cover,
                ),
              ),
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
                            style: GoogleFonts.bebasNeue(
                              fontSize: 55,
                            ),
                          ),
                          Text(
                            "WELCOME BACK!",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.normal,
                              color: Colors.black,
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
                            style: TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: "Email",
                              hintStyle: TextStyle(
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
                            style: TextStyle(color: Colors.black),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: "Password",
                              hintStyle: TextStyle(
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
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
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
                      child: GestureDetector(
                        onTap: signIn,
                        child: Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D2B53),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
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
                              style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600)),
                        ),
                        const Expanded(
                            child: Divider(
                                thickness: 1.5, color: Color(0xFFE7E7E7))),
                      ],
                    ),
                    SizedBox(height: 10),

                    // sign in with Google
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              final userCredential =
                                  await _authServices.SignInWithGoogle();
                              if (userCredential == null) {
                                // User cancelled sign-in, do nothing
                                return;
                              }
                              // if there is an error, it will be caught by the catch block
                            } catch (e) {
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
                                    )
                                  ],
                                ),
                              );
                            }
                          },
                          child: Image.asset(
                            'assets/google-icon.png',
                            height: 24,
                            width: 24,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ConductorFrom(role: 'Conductor'),
                                ));
                          },
                          child: Image.asset(
                            'assets/facebook-icon.png',
                            height: 24,
                            width: 24,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 40),

                    // Register section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: TextStyle(fontSize: 15),
                        ),
                        GestureDetector(
                          onTap: widget.showRegisterPage,
                          child: Text(
                            "Sign Up",
                            style: TextStyle(
                              color: Color(0xFF2397f3),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
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
