import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:b_go/pages/conductor/route_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PreTicket extends StatefulWidget {
  const PreTicket({super.key});

  @override
  State<PreTicket> createState() => _PreTicketState();
}

class _PreTicketState extends State<PreTicket> {
  final List<String> routeChoices = [
    'SM Lipa to Batangas City',
    'SM Lipa to Rosario',
    'SM Lipa to Mataas na Kahoy',
  ];

  // Map dropdown value to Firestore document ID
  final Map<String, String> routeToDocId = {
    'SM Lipa to Batangas City': 'Batangas',
    'SM Lipa to Rosario': 'Rosario',
    'SM Lipa to Mataas na Kahoy': 'Mataas na Kahoy',
  };

  String selectedRoute = 'SM Lipa to Batangas City';
  late Future<List<Map<String, dynamic>>> placesFuture =
      RouteService.fetchPlaces('Batangas');

  @override
  void initState() {
    super.initState();
    // Already initialized above
  }

  void _onRouteChanged(String? newRoute) {
    if (newRoute != null && newRoute != selectedRoute) {
      setState(() {
        selectedRoute = newRoute;
        final docId = routeToDocId[selectedRoute];
        if (docId == null) {
          // Handle the error gracefully, e.g. show a message or use a default
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid route selected.')),
          );
          return;
        }
        placesFuture = RouteService.fetchPlaces(docId);
      });
    }
  }

  void _showToSelectionPage(Map<String, dynamic> fromPlace,
      List<Map<String, dynamic>> allPlaces) async {
    // Only allow To places after the selected From
    int fromIndex = allPlaces.indexOf(fromPlace);
    List<Map<String, dynamic>> toPlaces = allPlaces.sublist(fromIndex + 1);
    if (toPlaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('No valid drop-off locations after selected pick-up.')),
      );
      return;
    }
    final toPlace = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => ToSelectionPage(toPlaces: toPlaces),
      ),
    );
    if (toPlace != null) {
      _showQuantityModal(fromPlace, toPlace);
    }
  }

  void _showQuantityModal(
      Map<String, dynamic> fromPlace, Map<String, dynamic> toPlace) async {
    int? quantity = await showDialog<int>(
      context: context,
      builder: (context) => _QuantitySelectionModal(),
    );
    if (quantity != null && quantity > 0) {
      _showFareTypeModal(fromPlace, toPlace, quantity);
    }
  }

  void _showFareTypeModal(Map<String, dynamic> fromPlace,
      Map<String, dynamic> toPlace, int quantity) async {
    List<String>? fareTypes = await showDialog<List<String>>(
      context: context,
      builder: (context) => _FareTypeSelectionModal(quantity: quantity),
    );
    if (fareTypes != null) {
      _showConfirmationModal(fromPlace, toPlace, quantity, fareTypes);
    }
  }

  void _showConfirmationModal(
      Map<String, dynamic> fromPlace,
      Map<String, dynamic> toPlace,
      int quantity,
      List<String> fareTypes) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmationModal(),
    );
    if (confirmed == true) {
      _showReceiptModal(fromPlace, toPlace, quantity, fareTypes);
    }
  }

  void _showReceiptModal(
      Map<String, dynamic> fromPlace,
      Map<String, dynamic> toPlace,
      int quantity,
      List<String> fareTypes) async {
    await showDialog(
      context: context,
      builder: (context) => _ReceiptModal(
        route: selectedRoute,
        fromPlace: fromPlace,
        toPlace: toPlace,
        quantity: quantity,
        fareTypes: fareTypes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: const Color(0xFF1D2B53),
            leading: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            title: Text(
              'Pre-Ticketing',
              style: GoogleFonts.outfit(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: DropdownButton<String>(
                  value: selectedRoute,
                  dropdownColor: const Color(0xFF1D2B53),
                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.white),
                  iconEnabledColor: Colors.white,
                  underline: Container(),
                  items: routeChoices
                      .map((route) => DropdownMenuItem(
                            value: route,
                            child: Text(route,
                                style: TextStyle(color: Colors.white)),
                          ))
                      .toList(),
                  onChanged: _onRouteChanged,
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: EdgeInsets.only(
                    top: MediaQuery.of(context).size.height * 0.02),
                width: double.infinity,
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
                    horizontal: 16.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        "Select Location:",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: placesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(child: Text('No places found.'));
                        }
                        final myList = snapshot.data!;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 2.2,
                          ),
                          itemCount: myList.length,
                          itemBuilder: (context, index) {
                            final item = myList[index];
                            return ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1D2B53),
                                elevation: 0,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 4),
                              ),
                              onPressed: () =>
                                  _showToSelectionPage(item, myList),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item['name'] ?? '',
                                    style: GoogleFonts.outfit(
                                        fontSize: 14, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (item['km'] != null)
                                    Text(
                                      '${item['km']} km',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.white70),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
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
}

// Quantity Selection Modal
class _QuantitySelectionModal extends StatefulWidget {
  @override
  State<_QuantitySelectionModal> createState() =>
      _QuantitySelectionModalState();
}

class _QuantitySelectionModalState extends State<_QuantitySelectionModal> {
  int quantity = 1;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Select Quantity', style: GoogleFonts.outfit(fontSize: 20)),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.remove),
            onPressed: quantity > 1 ? () => setState(() => quantity--) : null,
          ),
          Text('$quantity', style: GoogleFonts.outfit(fontSize: 20)),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => setState(() => quantity++),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: GoogleFonts.outfit(fontSize: 14)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(quantity),
          child: Text('Confirm', style: GoogleFonts.outfit(fontSize: 14)),
        ),
      ],
    );
  }
}

// Fare Type Selection Modal
class _FareTypeSelectionModal extends StatefulWidget {
  final int quantity;
  const _FareTypeSelectionModal({required this.quantity});
  @override
  State<_FareTypeSelectionModal> createState() =>
      _FareTypeSelectionModalState();
}

class _FareTypeSelectionModalState extends State<_FareTypeSelectionModal> {
  final List<String> fareTypes = ['Regular', 'Student', 'PWD', 'Senior'];
  late List<String> selectedTypes;

  @override
  void initState() {
    super.initState();
    selectedTypes = List.generate(widget.quantity, (index) => 'Regular');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign Fare Type:', style: GoogleFonts.outfit(fontSize: 20)),
      content: SizedBox(
        height: MediaQuery.of(context).size.height *
            0.5, // or a fixed value like 350
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < widget.quantity; i++)
                Row(
                  children: [
                    Text('Passenger ${i + 1}:',
                        style: GoogleFonts.outfit(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    SizedBox(width: 10),
                    DropdownButton<String>(
                      value: selectedTypes[i],
                      items: fareTypes
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type,
                                    style: GoogleFonts.outfit(fontSize: 14)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedTypes[i] = val!;
                        });
                      },
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: GoogleFonts.outfit(fontSize: 14)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(selectedTypes),
          child: Text('Confirm', style: GoogleFonts.outfit(fontSize: 14)),
        ),
      ],
    );
  }
}

// Confirmation Modal
class _ConfirmationModal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Are you sure with the Pre-Ticketing?',
          style: GoogleFonts.outfit(fontSize: 20)),
      content: Text('Do you wish to proceed?',
          style: GoogleFonts.outfit(fontSize: 14)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: GoogleFonts.outfit(fontSize: 14)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Yes', style: GoogleFonts.outfit(fontSize: 14)),
        ),
      ],
    );
  }
}

// Receipt Modal
class _ReceiptModal extends StatelessWidget {
  final String route;
  final Map<String, dynamic> fromPlace;
  final Map<String, dynamic> toPlace;
  final int quantity;
  final List<String> fareTypes;
  _ReceiptModal(
      {required this.route,
      required this.fromPlace,
      required this.toPlace,
      required this.quantity,
      required this.fareTypes});

  double computeFare(num startKm, num endKm) {
    final totalKm = endKm - startKm;
    double fare = 15.0; // Minimum fare for up to 4km
    if (totalKm > 4) {
      fare += (totalKm - 4) * 2.20;
    }
    return fare;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final formattedTime =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final startKm = fromPlace['km'] is num
        ? fromPlace['km']
        : num.tryParse(fromPlace['km'].toString()) ?? 0;
    final endKm = toPlace['km'] is num
        ? toPlace['km']
        : num.tryParse(toPlace['km'].toString()) ?? 0;
    final baseFare = computeFare(startKm, endKm);

    // Prepare discount breakdown and per-passenger fares
    List<String> discountBreakdown = [];
    List<double> passengerFares = [];
    double totalAmount = 0.0;
    for (int i = 0; i < fareTypes.length; i++) {
      final type = fareTypes[i];
      String discountText;
      double passengerFare;
      bool isDiscounted = false;
      if (type.toLowerCase() == 'pwd' ||
          type.toLowerCase() == 'senior' ||
          type.toLowerCase() == 'student') {
        passengerFare = baseFare * 0.8;
        discountText = '20% off';
        isDiscounted = true;
      } else {
        passengerFare = baseFare;
        discountText = 'No discount';
      }
      totalAmount += passengerFare;
      passengerFares.add(passengerFare);
      discountBreakdown.add(
        'Passenger ${i + 1}: $type${isDiscounted ? ' (20% off)' : ' (No discount)'} — ${passengerFare.toStringAsFixed(2)} PHP',
      );
    }

    final qrData = {
      'route': route,
      'date': formattedDate,
      'time': formattedTime,
      'from': fromPlace['name'],
      'to': toPlace['name'],
      'fromKm': fromPlace['km'],
      'toKm': toPlace['km'],
      'fare': baseFare,
      'quantity': quantity,
      'amount': totalAmount,
      'fareTypes': fareTypes,
      'discountBreakdown': discountBreakdown,
      'passengerFares': passengerFares,
    };
    return AlertDialog(
      title: Text('Receipt', style: GoogleFonts.outfit(fontSize: 20)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Route: $route', style: GoogleFonts.outfit(fontSize: 14)),
            Text('Date: $formattedDate',
                style: GoogleFonts.outfit(fontSize: 14)),
            Text('Time: $formattedTime',
                style: GoogleFonts.outfit(fontSize: 14)),
            Text('From: ${fromPlace['name']}',
                style: GoogleFonts.outfit(fontSize: 14)),
            Text('To: ${toPlace['name']}',
                style: GoogleFonts.outfit(fontSize: 14)),
            Text('From KM: ${fromPlace['km']}',
                style: GoogleFonts.outfit(fontSize: 14)),
            Text('To KM: ${toPlace['km']}',
                style: GoogleFonts.outfit(fontSize: 14)),
            Text('Base Fare (Regular): ${baseFare.toStringAsFixed(2)} PHP',
                style: GoogleFonts.outfit(fontSize: 14)),
            Text('Quantity: $quantity',
                style: GoogleFonts.outfit(fontSize: 14)),
            Text('Total Amount: ${totalAmount.toStringAsFixed(2)} PHP',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(height: 16),
            Text('Discounts:',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w500, fontSize: 14)),
            ...discountBreakdown
                .map((e) => Text(e, style: GoogleFonts.outfit(fontSize: 14))),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => QRCodeFullScreenPage(
                  from: fromPlace['name'] ?? '',
                  to: toPlace['name'] ?? '',
                  km: '${fromPlace['km']} - ${toPlace['km']}',
                  fare: baseFare.toStringAsFixed(2),
                  quantity: quantity,
                  qrData: qrData.toString(),
                  discountBreakdown: discountBreakdown,
                  showConfirmButton: true,
                ),
              ),
            );
          },
          child: Text('Show generated QR code',
              style: GoogleFonts.outfit(fontSize: 14)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close', style: GoogleFonts.outfit(fontSize: 14)),
        ),
      ],
    );
  }
}

class ToSelectionPage extends StatelessWidget {
  final List<Map<String, dynamic>> toPlaces;
  const ToSelectionPage({Key? key, required this.toPlaces}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: const Color(0xFF1D2B53),
            leading: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            title: Text(
              'Drop-off',
              style: GoogleFonts.outfit(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            // No actions/dropdown for To page
          ),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: EdgeInsets.only(
                  top: size.height * 0.02,
                  bottom: size.height * 0.08,
                ),
                width: double.infinity,
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
                    horizontal: 16.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        "Select Your Drop-off:",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: toPlaces.length,
                      itemBuilder: (context, index) {
                        final place = toPlaces[index];
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D2B53),
                            elevation: 0,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                          ),
                          onPressed: () => Navigator.of(context).pop(place),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                place['name'] ?? '',
                                style: GoogleFonts.outfit(
                                    fontSize: 14, color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                              if (place['km'] != null)
                                Text(
                                  '${place['km']} km',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.white70),
                                ),
                            ],
                          ),
                        );
                      },
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
}

// Update QRCodeFullScreenPage to accept and show discountBreakdown
class QRCodeFullScreenPage extends StatelessWidget {
  final String from;
  final String to;
  final String km;
  final String fare;
  final int quantity;
  final String qrData;
  final List<String>? discountBreakdown;
  final bool showConfirmButton;

  const QRCodeFullScreenPage({
    Key? key,
    required this.from,
    required this.to,
    required this.km,
    required this.fare,
    required this.quantity,
    required this.qrData,
    this.discountBreakdown,
    this.showConfirmButton = true,
  }) : super(key: key);

  Future<bool> canCreatePreTicket() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final now = DateTime.now().toUtc().add(const Duration(hours: 8)); // PH time
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('preTickets')
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .where('createdAt', isLessThan: endOfDay)
        .get();
    return snapshot.docs.length < 3;
  }

  Future<void> savePreTicket(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final now = DateTime.now(); // Use device local time
    final data = {
      'from': from,
      'to': to,
      'km': km,
      'fare': fare,
      'quantity': quantity,
      'qrData': qrData,
      'discountBreakdown': discountBreakdown,
      'createdAt': now, // Save as local time
    };
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('preTickets')
        .add(data);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final qrSize = size.width * 0.6;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0091AD),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('QR Code',
            style: GoogleFonts.outfit(
                color: const Color.fromARGB(255, 255, 255, 255), fontSize: 16)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: size.height * 0.04),
            Center(
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.all(8),
                child: QrImageView(
                  data: qrData,
                  size: qrSize,
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Show your generated QR code to the conductor',
              style:
                  GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Details:',
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w500, fontSize: 14)),
                      SizedBox(height: 8),
                      Text('From: $from', style: GoogleFonts.outfit(fontSize: 14)),
                      Text('To: $to', style: GoogleFonts.outfit(fontSize: 14)),
                      Text('KM: $km', style: GoogleFonts.outfit(fontSize: 14)),
                      Text('Fare: $fare Pesos',
                          style: GoogleFonts.outfit(fontSize: 14)),
                      Text('Total Passengers: $quantity',
                          style: GoogleFonts.outfit(fontSize: 14)),
                      if (discountBreakdown != null) ...[
                        SizedBox(height: 12),
                        Text('Discounts:',
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w500, fontSize: 14)),
                        ...discountBreakdown!.map((e) =>
                            Text(e, style: GoogleFonts.outfit(fontSize: 14))),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: size.width * 0.35,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(showConfirmButton ? 'Cancel' : 'Close',
                          style: GoogleFonts.outfit(
                              color: Colors.white, fontSize: 17)),
                    ),
                  ),
                  if (showConfirmButton) ...[
                    SizedBox(width: 16),
                    SizedBox(
                      width: size.width * 0.35,
                      height: 48,
                      child: FutureBuilder<bool>(
                        future: canCreatePreTicket(),
                        builder: (context, snapshot) {
                          final canCreate = snapshot.data ?? false;
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightGreen[400],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                            ),
                            onPressed: canCreate
                                ? () async {
                                    await savePreTicket(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Pre-ticket saved!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    Navigator.of(context).pop();
                                  }
                                : null,
                            child: Text('Confirm',
                                style: GoogleFonts.outfit(
                                    color: Colors.white, fontSize: 17)),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
