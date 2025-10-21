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
  Future<bool> _checkIfConductor(String uid) async {
    try {
      print('🔍 Starting Firestore query for conductor check...');
      print('🔍 Checking for UID: $uid');

      final query = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get()
          .timeout(
        const Duration(seconds: 30), // CHANGED: Increased from 10 to 30 seconds
        onTimeout: () {
          print('⏱️ TIMEOUT: Firestore query took too long');
          throw TimeoutException('Query timeout');
        },
      );

      print('✅ Firestore query completed');
      print('📊 Documents found: ${query.docs.length}');

      if (query.docs.isNotEmpty) {
        print('✅ User IS a conductor');
        print('📄 Conductor data: ${query.docs.first.data()}');
      } else {
        print('❌ User is NOT a conductor');
      }

      return query.docs.isNotEmpty;
    } on FirebaseException catch (e) {
      print('❌ FirebaseException: ${e.code} - ${e.message}');
      return false;
    } on TimeoutException catch (e) {
      print('❌ TimeoutException: $e');
      return false;
    } catch (e) {
      print('❌ Unknown error: $e');
      return false;
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

          return FutureBuilder<bool>(
            future: _checkIfConductor(user.uid),
            builder: (context, conductorSnapshot) {
              print(
                  '🔍 Conductor check: ConnectionState = ${conductorSnapshot.connectionState}');

              if (conductorSnapshot.connectionState ==
                  ConnectionState.waiting) {
                print('⏳ Checking if user is conductor...');
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
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                );
              }

              final isConductor = conductorSnapshot.data ?? false;
              print('🔍 Is conductor: $isConductor');

              if (conductorSnapshot.hasError) {
                print('❌ Error in conductor check: ${conductorSnapshot.error}');
              }

              if (isConductor) {
                print(
                    '🚌 User is a conductor - bypassing email verification check');
                print('🚌 Fetching conductor data...');

                // Need to fetch conductor data again to get route and placeCollection
                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('conductors')
                      .where('uid', isEqualTo: user.uid)
                      .limit(1)
                      .get(),
                  builder: (context, dataSnapshot) {
                    if (dataSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Scaffold(
                        backgroundColor: Color(0xFFE5E9F0),
                        body: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF0091AD)),
                          ),
                        ),
                      );
                    }

                    if (dataSnapshot.hasData &&
                        dataSnapshot.data!.docs.isNotEmpty) {
                      final conductorData = dataSnapshot.data!.docs.first.data()
                          as Map<String, dynamic>;
                      final route = conductorData['route'] ?? '';
                      final placeCollection =
                          conductorData['placeCollection'] ?? 'Place';

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
                    }

                    print(
                        '⚠️ No conductor data found, falling back to UserSelection');
                    // Fallback if data fetch fails
                    return UserSelection();
                  },
                );
              } else {
                // CHANGED: Added clear comment that this is ONLY for non-conductors
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
