import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:b_go/pages/conductor/conductor_home.dart';
import 'package:b_go/auth/login_page.dart';
import 'package:b_go/pages/user_role/user_selection.dart';
import 'dart:async';

class AuthStateHandler extends StatefulWidget {
  final VoidCallback showRegisterPage;

  const AuthStateHandler({Key? key, required this.showRegisterPage})
      : super(key: key);

  @override
  State<AuthStateHandler> createState() => _AuthStateHandlerState();
}

class _AuthStateHandlerState extends State<AuthStateHandler> {
  // OPTIMIZED: Direct document lookup instead of .where() query
  Future<Map<String, dynamic>?> _getUserData(String uid) async {
    try {
      print('🔍 Fetching user data for UID: $uid');

      final query = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get()
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏱️ TIMEOUT: User data fetch took too long');
          throw TimeoutException('User data timeout');
        },
      );

      print('✅ Firestore query completed');
      print('📊 Documents found: ${query.docs.length}');

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data() as Map<String, dynamic>;
        final userRole = data['userRole'] ?? '';
        print('✅ User document found');
        print('👤 User role: $userRole');
        print('📄 User data: $data');
        return data;
      } else {
        print('❌ No user document found');
        return null;
      }
    } on FirebaseException catch (e) {
      print('❌ FirebaseException: ${e.code} - ${e.message}');
      return null;
    } on TimeoutException catch (e) {
      print('❌ TimeoutException: $e');
      return null;
    } catch (e) {
      print('❌ Unknown error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🔍 AuthStateHandler: Building...');

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print(
            '🔍 AuthStateHandler: ConnectionState = ${snapshot.connectionState}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          print('⏳ AuthStateHandler: Waiting for auth state...');
          return const Scaffold(
            backgroundColor: Color(0xFFE5E9F0),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0091AD)),
              ),
            ),
          );
        }

        print('🔍 AuthStateHandler: Has data = ${snapshot.hasData}');

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          print('✅ User is logged in: ${user.uid}');
          print('📧 Email verified: ${user.emailVerified}');

          return FutureBuilder<Map<String, dynamic>?>(
            future: _getUserData(user.uid),
            builder: (context, userDataSnapshot) {
              print(
                  '🔍 User data check: ConnectionState = ${userDataSnapshot.connectionState}');

              if (userDataSnapshot.connectionState == ConnectionState.waiting) {
                print('⏳ Fetching user data...');
                return Scaffold(
                  backgroundColor: const Color(0xFFE5E9F0),
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF0091AD)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Loading...',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (userDataSnapshot.hasError) {
                print('❌ Error fetching user data: ${userDataSnapshot.error}');
              }

              final userData = userDataSnapshot.data;
              final userRole = userData?['userRole'] ?? '';
              final isConductor = userRole == 'conductor';

              print('🔍 User role: $userRole');
              print('🔍 Is conductor: $isConductor');

              if (isConductor && userData != null) {
                print(
                    '🚌 User is a conductor - bypassing email verification check');

                // Extract conductor data
                final route = userData['route'] ?? '';
                final placeCollection = userData['placeCollection'] ?? 'Place';

                print('✅ Conductor data loaded successfully');
                print('📍 Route: $route');
                print('📍 Place Collection: $placeCollection');
                print('🎯 Navigating to ConductorHome');

                return ConductorHome(
                  role: 'Conductor',
                  route: route,
                  placeCollection: placeCollection,
                  selectedIndex: 0,
                );
              } else {
                // Regular user (not a conductor)
                print('👤 User is NOT a conductor');

                // ONLY check email verification for regular users (not conductors)
                if (!user.emailVerified &&
                    user.providerData.isNotEmpty &&
                    user.providerData.first.providerId == 'password') {
                  print(
                      '⚠️ Regular user email not verified, showing LoginPage');
                  return LoginPage(showRegisterPage: widget.showRegisterPage);
                }

                print('✅ Proceeding to UserSelection');
                return UserSelection();
              }
            },
          );
        }

        print('❌ No user logged in, showing LoginPage');
        return LoginPage(showRegisterPage: widget.showRegisterPage);
      },
    );
  }
}
