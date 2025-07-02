import 'package:b_go/pages/get_started.dart';
import 'package:b_go/pages/login_page.dart';
import 'package:b_go/pages/register_page.dart';
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
      },
    );
  }
}
