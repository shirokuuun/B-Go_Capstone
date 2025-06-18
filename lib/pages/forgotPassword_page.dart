import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}


class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailController = TextEditingController();

  dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future passwordReset() async {
  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(
      email: emailController.text.trim(),
    );
    // If no error, show this dialog:
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text('If your email is registered, you’ll receive a password reset email. Thank you!'),
        );
      },
    );
  } on FirebaseAuthException catch (e) {
    // If error, show this dialog:
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          content: Text(e.message.toString()),
        );
      },
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFE5E9F0),
        elevation: 0,
      ),
      body:Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
         Text('Enter your email to reset your password',
                 style: GoogleFonts.bebasNeue(
          fontSize: 20,
                 ),
               ),

              SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFE5E9F0),
                    borderRadius: BorderRadius.circular(12)
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20.0),
                    child: TextField(
                      controller: emailController,
                      style: TextStyle(
                        color: const Color.fromARGB(255, 15, 15, 15)
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Email",
                        
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 20),

              MaterialButton(
                onPressed: passwordReset,
                color:  Color(0xFF1D2B53),
                child: Text('Reset Password',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
              ),

      ],)
    );
  }
}