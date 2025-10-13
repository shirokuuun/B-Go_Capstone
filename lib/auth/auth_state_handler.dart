import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:b_go/pages/conductor/conductor_home.dart';
import 'package:b_go/auth/login_page.dart'; // Import your login page

class AuthStateHandler extends StatelessWidget {
  final VoidCallback showRegisterPage;
  
  const AuthStateHandler({Key? key, required this.showRegisterPage}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // If user is logged in
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          
          // Check if user is a conductor
          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('conductors')
                .where('uid', isEqualTo: user.uid)
                .limit(1)
                .get(),
            builder: (context, conductorSnapshot) {
              if (conductorSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              if (conductorSnapshot.hasData && conductorSnapshot.data!.docs.isNotEmpty) {
                // User is a conductor
                final conductorData = conductorSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                final route = conductorData['route'] ?? '';
                final placeCollection = conductorData['placeCollection'] ?? 'Place';
                
                return ConductorHome(
                  role: 'Conductor',
                  route: route,
                  placeCollection: placeCollection,
                  selectedIndex: 0,
                );
              } else {
                // User is not a conductor, redirect to user selection
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacementNamed(context, '/user_selection');
                });
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
            },
          );
        }
        
        // If user is not logged in, show login page
        return LoginPage(showRegisterPage: showRegisterPage);
      },
    );
  }
}