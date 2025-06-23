import 'package:b_go/auth/auth_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Signed in successfully: ' + user!.email!),
          MaterialButton(
            onPressed: () async {
              await AuthServices().signOut();
            },
            color: Color(0xFF0091AD),
            child: Text('Sign Out'),
          )
        ],
      )),
    );
  }
}
