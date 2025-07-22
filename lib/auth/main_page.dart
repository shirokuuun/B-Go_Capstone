import 'package:b_go/auth/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:b_go/auth/auth_page.dart';
import 'package:flutter/material.dart';

class MainPage extends StatelessWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return LoginPage(
              showRegisterPage: () {},
            );
          } else {
            return AuthPage();
          }
        },
      ),
    );
  }
}
