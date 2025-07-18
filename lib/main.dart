import 'package:b_go/pages/get_started.dart';
import 'package:b_go/pages/login_page.dart';
import 'package:b_go/pages/login_phone_page.dart';
import 'package:b_go/pages/passenger/home_page.dart';
import 'package:b_go/pages/passenger/services/passenger_service.dart';
import 'package:b_go/pages/passenger/profile/edit_profile.dart';
import 'package:b_go/pages/passenger/profile/profile.dart';
import 'package:b_go/pages/passenger/services/pre_ticket.dart';
import 'package:b_go/pages/register_page.dart';
import 'package:b_go/pages/register_phone_page.dart';
import 'package:b_go/pages/user_role/user_selection.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      //home: MainPage(),
      home: GetStartedPage(),
      routes: {
        '/login': (context) =>
            LoginPage(showRegisterPage: () {
              Navigator.pushReplacementNamed(context, '/register');
            }),
        '/register': (context) => RegisterPage(showLoginPage: () {
          Navigator.pushReplacementNamed(context, '/login');
        }),
        '/user_selection': (context) => UserSelection(),
        '/phone_register': (context) => RegisterPhonePage(),
        '/phone_login': (context) => LoginPhonePage(),
        '/home': (context) => HomePage(role: 'Passenger'),
        '/passenger_service': (context) => PassengerService(),
        '/profile': (context) => ProfilePage(),
        '/pre_ticket': (context) => PreTicket(),
        '/edit_profile': (context) => EditProfile(),
      },
    );
  }
}
