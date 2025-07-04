import 'package:b_go/auth/auth_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomePage extends StatefulWidget {
  final String role;
  const HomePage({super.key, required this.role});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;
  late GoogleMapController mapController;

  final LatLng _center =
      const LatLng(13.9407, 121.1529); // Example: Rosario, Batangas

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome"),
        backgroundColor: const Color(0xFF0091AD),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: 14.0,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Signed in as: ${user?.email ?? 'Unknown'}'),
                  const SizedBox(height: 10),
                  MaterialButton(
                    onPressed: () async {
                      await AuthServices().signOut();
                      if (!mounted) return;
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    color: const Color(0xFF0091AD),
                    textColor: Colors.white,
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
