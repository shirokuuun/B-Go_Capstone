import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:capstone_project/responsiveness/responsive_page.dart';

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
    Responsive responsive = Responsive(context);
    
    return Scaffold(
      appBar: AppBar(
        
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'Forgot Password',
            style: GoogleFonts.bebasNeue(
              fontSize: 25,
              color: Colors.white
            ),
          ),
        ),
        backgroundColor: Color(0xFF1D2B53),
        elevation: 0,
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
      ),
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.38,
            decoration: BoxDecoration(
              color: Color(0xFFE5E9F0),
            ),
            padding: const EdgeInsets.only(left: 10,  bottom: 35),
            alignment: Alignment.topLeft,

            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
                  child: Container(
                    margin: EdgeInsets.only(
                      top: MediaQuery.of(context).size.height * 0.18,
                    ),
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
                      bottom: responsive.height * 0.50,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    // Change password text
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Enter your email to reset your password',
                            style: GoogleFonts.bebasNeue(
                              fontSize: 24,
                            ),
                          ),
                          SizedBox(height: 10),
                          Center(
                            child: Text('Make sure to enter the email you used to register',
                              style: GoogleFonts.bebasNeue(
                              fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 50),
                    
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

              SizedBox(height: 300),

              Center(
                child: MaterialButton(
                  minWidth: 200, 
                  height: 55,   
                  onPressed: passwordReset,
                  color:  Color(0xFF1D2B53),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Reset Password',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 25,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),      
                    ],
                     ),
                  ),
            ),
            ),
      ],)
    );
  }
}