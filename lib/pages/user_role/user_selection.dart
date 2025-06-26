import 'package:b_go/pages/home_page.dart';
import 'package:flutter/material.dart';

class UserSelection extends StatefulWidget {
  const UserSelection({super.key});

  @override
  State<UserSelection> createState() => _UserSelectionState();
}

class _UserSelectionState extends State<UserSelection> {
  final List<String> roles = ['Passenger', 'Bus Reservation'];
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Left arrow (only show if not first)
            if (currentIndex > 0)
              IconButton(
                icon: const Icon(Icons.arrow_left, size: 48),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                onPressed: () {
                  setState(() {
                    currentIndex--;
                  });
                },
              )
            else
              const SizedBox(width: 48), // Placeholder for alignment

            // Role selection modal
            GestureDetector(
              onTap: () {
                if (roles[currentIndex] == 'Passenger') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomePage(role: roles[currentIndex]),
                    ),
                  );
                } else if (roles[currentIndex] == 'Bus Reservation') {
                  // TODO: Replace with your actual Bus Reservation page
                  // Navigator.push(context, MaterialPageRoute(builder: (context) => BusReservationPage()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Bus Reservation page coming soon!')),
                  );
                }
              },
              child: Container(
                width: MediaQuery.of(context).size.width * 0.7,
                height: MediaQuery.of(context).size.height * 0.80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  roles[currentIndex],
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Right arrow (only show if not last)
            if (currentIndex < roles.length - 1)
              IconButton(
                icon: const Icon(Icons.arrow_right, size: 48),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                onPressed: () {
                  setState(() {
                    currentIndex++;
                  });
                },
              )
            else
              const SizedBox(width: 48), // Placeholder for alignment
          ],
        ),
      ),
    );
  }
}
