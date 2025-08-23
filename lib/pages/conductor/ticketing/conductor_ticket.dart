import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:b_go/pages/conductor/ticketing/conductor_from.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ConductorTicket extends StatefulWidget {
  final String route;
  final String ticketDocName;
  final String placeCollection;
  final String date;

  ConductorTicket(
      {Key? key,
      required this.route,
      required this.ticketDocName,
      required this.placeCollection,
      required this.date})
      : super(key: key);

  @override
  State<ConductorTicket> createState() => _ConductorTicketState();
}

class _ConductorTicketState extends State<ConductorTicket> {
  String getRouteLabel(String placeCollection) {
    final route = widget.route;

    if (route == 'Rosario') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - Rosario';
        case 'Place 2':
          return 'Rosario - SM City Lipa';
      }
    } else if (route == 'Batangas') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - Batangas City';
        case 'Place 2':
          return 'Batangas City - SM City Lipa';
      }
    } else if (route == 'Mataas na Kahoy') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - Mataas na Kahoy';
        case 'Place 2':
          return 'Mataas na Kahoy - SM City Lipa';
      }
    } else if (route == 'Mataas Na Kahoy Palengke') {
      switch (placeCollection) {
        case 'Place':
          return 'Lipa Palengke - Mataas na Kahoy';
        case 'Place 2':
          return 'Mataas na Kahoy - Lipa Palengke';
      }
    } else if (route == 'Tiaong') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - Tiaong';
        case 'Place 2':
          return 'Tiaong - SM City Lipa';
      }
    } else if (route == 'San Juan') {
      switch (placeCollection) {
        case 'Place':
          return 'SM City Lipa - San Juan';
        case 'Place 2':
          return 'San Juan - SM City Lipa';
      }
    }

    return 'Unknown Route';
  }

  Map<String, dynamic>? latestTrip;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchLatestTrip();
  }

  void fetchLatestTrip() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      print('🔍 Fetching trip data for:');
      print('Route: ${widget.route}');
      print('Date: ${widget.date}');
      print('TicketDocName: ${widget.ticketDocName}');
      print('PlaceCollection: ${widget.placeCollection}');

      // Try multiple approaches to fetch the trip data
      Map<String, dynamic>? tripData;

      // Approach 1: Try the original RouteService.fetchTrip
      try {
        tripData = await RouteService.fetchTrip(
            widget.route, widget.date, widget.ticketDocName);
        if (tripData != null && tripData.isNotEmpty) {
          print('✅ Found trip data using RouteService.fetchTrip');
        }
      } catch (e) {
        print('⚠️ RouteService.fetchTrip failed: $e');
      }

      // Approach 2: If RouteService failed, try direct Firestore query
      if (tripData == null || tripData.isEmpty) {
        tripData = await fetchTripDirectly();
      }

      // Approach 3: Try fetching from conductor's remittance collection
      if (tripData == null || tripData.isEmpty) {
        tripData = await fetchFromConductorRemittance();
      }

      setState(() {
        latestTrip = tripData;
        isLoading = false;
      });

      if (tripData == null || tripData.isEmpty) {
        setState(() {
          errorMessage = 'No trip data found. This might be a QR scan ticket.';
        });
      }
    } catch (e) {
      print('❌ Error fetching trip: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading ticket data: ${e.toString()}';
      });
    }
  }

  Future<Map<String, dynamic>?> fetchTripDirectly() async {
    try {
      print('🔄 Trying direct Firestore query...');

      // Try fetching from trips collection
      final tripsDoc = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.route)
          .collection('trips')
          .doc(widget.ticketDocName)
          .get();

      if (tripsDoc.exists) {
        print('✅ Found trip data in trips collection');
        return tripsDoc.data();
      }

      // Try fetching from trips with date structure
      final tripsWithDate = await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.route)
          .collection(widget.date)
          .doc(widget.ticketDocName)
          .get();

      if (tripsWithDate.exists) {
        print('✅ Found trip data in trips with date collection');
        return tripsWithDate.data();
      }

      print('⚠️ No trip data found in direct queries');
      return null;
    } catch (e) {
      print('❌ Direct Firestore query failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchFromConductorRemittance() async {
    try {
      print('🔄 Trying to fetch from conductor remittance...');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Get conductor document
      final conductorQuery = await FirebaseFirestore.instance
          .collection('conductors')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (conductorQuery.docs.isEmpty) return null;

      final conductorId = conductorQuery.docs.first.id;
      final formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Try to fetch the latest ticket from remittance
      final ticketsQuery = await FirebaseFirestore.instance
          .collection('conductors')
          .doc(conductorId)
          .collection('remittance')
          .doc(formattedDate)
          .collection('tickets')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (ticketsQuery.docs.isNotEmpty) {
        print('✅ Found ticket data in conductor remittance');
        return ticketsQuery.docs.first.data();
      }

      return null;
    } catch (e) {
      print('❌ Fetch from conductor remittance failed: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: const Color(0xFF0091AD),
            leading: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ConductorFrom(
                        route: widget.route,
                        role: 'conductor',
                      ),
                    ),
                  );
                },
              ),
            ),
            title: Text(
              'Ticketing',
              style: GoogleFonts.outfit(
                fontSize: 25,
                color: Colors.white,
              ),
            ),
          ),
          SliverAppBar(
            automaticallyImplyLeading: false,
            backgroundColor: const Color(0xFF0091AD),
            pinned: true,
            expandedHeight: 80,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007A8F),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        getRouteLabel(widget.placeCollection),
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 30.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConductorFrom(
                                route: widget.route,
                                role: 'conductor',
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.add, color: Colors.white),
                        label: Text(
                          'New Ticket',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0091AD),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24.0, vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Center(
                      child: _buildTicketContent(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketContent() {
    if (isLoading) {
      return Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0091AD)),
          ),
          SizedBox(height: 16),
          Text(
            'Loading ticket data...',
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
        ],
      );
    }

    if (errorMessage != null) {
      return Container(
        width: MediaQuery.of(context).size.width * 0.95,
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.orange.shade200),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.orange.shade600,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              errorMessage!,
              style: GoogleFonts.outfit(
                fontSize: 16,
                color: Colors.orange.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: fetchLatestTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0091AD),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.outfit(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (latestTrip == null || latestTrip!.isEmpty) {
      return Text(
        'No ticket yet.',
        style: GoogleFonts.outfit(
          fontSize: 20,
          color: Colors.black54,
        ),
      );
    }

    return _buildReceiptCard();
  }

  Widget _buildReceiptCard() {
    // Safely extract data with null checks and defaults
    final List<dynamic>? discountBreakdown = latestTrip?['discountBreakdown'];
    final timestamp = latestTrip?['timestamp'];

    String formattedDate = 'N/A';
    String formattedTime = 'N/A';

    if (timestamp != null) {
      try {
        DateTime dateTime;
        if (timestamp is Timestamp) {
          dateTime = timestamp.toDate().add(const Duration(hours: 8));
        } else if (timestamp is DateTime) {
          dateTime = timestamp.add(const Duration(hours: 8));
        } else {
          dateTime = DateTime.now();
        }

        formattedDate = DateFormat('yyyy-MM-dd').format(dateTime);
        formattedTime = TimeOfDay.fromDateTime(dateTime).format(context);
      } catch (e) {
        print('Error formatting timestamp: $e');
      }
    }

    final from = latestTrip?['from']?.toString() ?? 'N/A';
    final to = latestTrip?['to']?.toString() ?? 'N/A';
    final startKm = latestTrip?['startKm']?.toString() ?? 'N/A';
    final endKm = latestTrip?['endKm']?.toString() ?? 'N/A';

    // Handle different fare formats
    String baseFare = 'N/A';
    final fareData = latestTrip?['farePerPassenger'];
    if (fareData != null) {
      if (fareData is List && fareData.isNotEmpty) {
        baseFare = '${fareData.first} PHP';
      } else if (fareData is num) {
        baseFare = '${fareData.toStringAsFixed(2)} PHP';
      } else if (fareData is String) {
        baseFare = '$fareData PHP';
      }
    }

    final quantity = latestTrip?['quantity']?.toString() ?? 'N/A';
    final totalFare = latestTrip?['totalFare']?.toString() ?? 'N/A';
    final discountAmount = latestTrip?['discountAmount']?.toString() ?? '0.00';

    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Receipt',
                style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0091AD))),
            SizedBox(height: 16),
            _buildReceiptRow('Route:', getRouteLabel(widget.placeCollection)),
            _buildReceiptRow('Date:', formattedDate),
            _buildReceiptRow('Time:', formattedTime),
            _buildReceiptRow('From:', from),
            _buildReceiptRow('To:', to),
            _buildReceiptRow('From KM:', startKm),
            _buildReceiptRow('To KM:', endKm),
            _buildReceiptRow('Base Fare', baseFare),
            _buildReceiptRow('Quantity:', quantity),
            _buildReceiptRow('Total Amount:', '$totalFare PHP', isTotal: true),
            SizedBox(height: 16),
            Text('Discounts:',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w500, fontSize: 16)),
            SizedBox(height: 8),
            if (discountBreakdown != null && discountBreakdown.isNotEmpty)
              ...discountBreakdown.map((e) => Padding(
                    padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                    child: Text(e.toString(),
                        style: GoogleFonts.outfit(fontSize: 15)),
                  ))
            else
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Text('No discounts.',
                    style: GoogleFonts.outfit(fontSize: 15)),
              ),
            if (discountAmount != '0.00' && discountAmount != 'N/A') ...[
              SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Text(
                  'Total Discount: $discountAmount PHP',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.green.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
                color: isTotal ? Color(0xFF0091AD) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
