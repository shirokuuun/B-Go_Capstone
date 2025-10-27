import 'package:b_go/pages/get_started.dart';
import 'package:b_go/auth/login_page.dart';
import 'package:b_go/auth/login_phone_page.dart';
import 'package:b_go/auth/auth_state_handler.dart';
import 'package:b_go/pages/bus_reserve/bus_reserve_pages/bus_home.dart';
import 'package:b_go/pages/passenger/profile/Settings/reservation_confirm.dart';
import 'package:b_go/pages/passenger/home_page.dart';
import 'package:b_go/pages/passenger/profile/Settings/about.dart';
import 'package:b_go/pages/passenger/profile/Settings/ID/id_verification_instruction.dart';
import 'package:b_go/pages/passenger/profile/Settings/ID/id_verification_picture.dart';
import 'package:b_go/pages/passenger/profile/Settings/ID/id_verification.dart';
import 'package:b_go/pages/passenger/profile/user_id.dart';
import 'package:b_go/pages/passenger/profile/Settings/privacy_policy.dart';
import 'package:b_go/pages/passenger/profile/Settings/pre_ticket_qr.dart';
import 'package:b_go/pages/passenger/profile/Settings/settings.dart';
import 'package:b_go/pages/passenger/sidebar/trip_sched.dart';
import 'package:b_go/pages/passenger/services/passenger_service.dart';
import 'package:b_go/pages/passenger/services/pre_book.dart';
import 'package:b_go/pages/passenger/profile/edit_profile.dart';
import 'package:b_go/pages/passenger/profile/profile.dart';
import 'package:b_go/pages/passenger/profile/Settings/faq.dart';
import 'package:b_go/pages/passenger/services/pre_ticket.dart';
import 'package:b_go/auth/register_page.dart';
import 'package:b_go/auth/register_phone_page.dart';
import 'package:b_go/pages/user_role/user_selection.dart';
import 'package:b_go/services/background_geofencing_service.dart';
import 'package:b_go/services/foreground_service_manager.dart';
import 'package:b_go/services/notification_service.dart';
import 'package:b_go/services/realtime_location_service.dart';
import 'package:b_go/services/offline_location_service.dart';
import 'package:b_go/services/background_location_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:b_go/services/expired_reservation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp();

  // Initialize geolocator
  await Geolocator.requestPermission();

  // Start the expired reservation service
  ExpiredReservationService.startService();

  // Initialize background location service
  final backgroundLocationService = BackgroundLocationService();
  await backgroundLocationService.initialize();

  // Check for active location tracking on app startup
  final locationService = RealtimeLocationService();
  await locationService.checkForActiveTracking();

  // Check for active background tracking
  await backgroundLocationService.checkForActiveTracking();

  // Sync any offline locations from previous sessions
  final offlineService = OfflineLocationService();
  await offlineService.syncOfflineLocations();

  // Sync offline locations from background service
  await backgroundLocationService.syncOfflineLocations();

  await BackgroundGeofencingService().initialize();
  await NotificationService().initialize();
  await NotificationService().requestPermissions();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => ResponsiveBreakpoints.builder(
        child: child!,
        breakpoints: [
          const Breakpoint(start: 0, end: 450, name: MOBILE),
          const Breakpoint(start: 451, end: 800, name: TABLET),
          const Breakpoint(start: 801, end: 1920, name: DESKTOP),
          const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
        ],
      ),
      home: const SplashScreen(),
      routes: {
        '/get_started': (context) => const GetStartedPage(),
        '/auth_check': (context) => AuthStateHandler(
              showRegisterPage: () {
                Navigator.pushReplacementNamed(context, '/register');
              },
            ),
        '/login': (context) => LoginPage(
              showRegisterPage: () {
                Navigator.pushReplacementNamed(context, '/register');
              },
            ),
        '/register': (context) => RegisterPage(
              showLoginPage: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
        '/user_selection': (context) => UserSelection(),
        '/phone_register': (context) => RegisterPhonePage(),
        '/phone_login': (context) => LoginPhonePage(),
        '/home': (context) => HomePage(role: 'Passenger'),
        '/passenger_service': (context) => PassengerService(),
        '/profile': (context) => ProfilePage(),
        '/pre_ticket': (context) => PreTicket(),
        '/edit_profile': (context) => EditProfile(),
        '/trip_sched': (context) => TripSchedPage(),
        '/settings': (context) => SettingsPage(),
        '/pre_ticket_qr': (context) => PreTicketQrs(),
        '/help_center': (context) => FAQPage(),
        '/privacy_policy': (context) => PrivacyPolicyPage(),
        '/about': (context) => AboutPage(),
        '/id_verification': (context) => IDVerificationInstructionPage(),
        '/id_verification_picture': (context) => IDVerificationPicturePage(),
        '/id_verification_review': (context) => IDVerificationReviewPage(),
        '/user_id': (context) => UserIDPage(),
        '/bus_home': (context) => BusHome(),
        '/pre_book': (context) => PreBook(),
        '/reservation_confirm': (context) => ReservationConfirm(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    // Small delay for splash effect
    await Future.delayed(const Duration(milliseconds: 500));

    final prefs = await SharedPreferences.getInstance();
    final hasSeenGetStarted = prefs.getBool('has_seen_get_started') ?? false;

    if (!mounted) return;

    if (hasSeenGetStarted) {
      // User has seen get started before, go to auth check
      Navigator.pushReplacementNamed(context, '/auth_check');
    } else {
      // First time user, show get started page
      Navigator.pushReplacementNamed(context, '/get_started');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE5E9F0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/batrasco-logo.png',
              width: 150,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0091AD)),
            ),
          ],
        ),
      ),
    );
  }
}
