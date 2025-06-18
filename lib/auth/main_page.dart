import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_project/auth/auth_page.dart';
import 'package:capstone_project/pages/home_page.dart';
import 'package:capstone_project/pages/login_page.dart';
import 'package:flutter/material.dart';

class MainPage extends StatelessWidget{
  const MainPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot){
        if(snapshot.hasData){
          return HomePage();
        }else{
          return AuthPage();
        }
      },
      ),
    );
  }
}