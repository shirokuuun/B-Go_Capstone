import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:b_go/pages/conductor/conductor_home.dart';
import 'package:b_go/auth/login_page.dart';

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
            backgroundColor: Color(0xFFE5E9F0),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0091AD)),
              ),
            ),
          );
        }
        
        // If user is logged in
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          
          // Check if user is a conductor FIRST before checking email verification
          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('conductors')
                .where('uid', isEqualTo: user.uid)
                .limit(1)
                .get(),
            builder: (context, conductorSnapshot) {
              if (conductorSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFFE5E9F0),
                  body: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0091AD)),
                    ),
                  ),
                );
              }
              
              if (conductorSnapshot.hasError) {
                return Scaffold(
                  backgroundColor: Color(0xFFE5E9F0),
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          'Error loading user data',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                          },
                          child: Text('Return to Login'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              if (conductorSnapshot.hasData && conductorSnapshot.data!.docs.isNotEmpty) {
                // User is a conductor - let them in regardless of email verification
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
                // User is NOT a conductor - now check email verification for regular users
                if (!user.emailVerified && user.providerData.first.providerId == 'password') {
                  // Regular users need email verification
                  return LoginPage(showRegisterPage: showRegisterPage);
                }
                
                // User is a verified regular user, navigate to user selection
                return FutureBuilder(
                  future: Future.delayed(Duration.zero, () {
                    Navigator.pushReplacementNamed(context, '/user_selection');
                  }),
                  builder: (context, _) {
                    return const Scaffold(
                      backgroundColor: Color(0xFFE5E9F0),
                      body: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0091AD)),
                        ),
                      ),
                    );
                  },
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