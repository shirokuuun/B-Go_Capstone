import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class QRScanPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MobileScanner(
        onDetect: (capture) async {
          final barcode = capture.barcodes.first;
          final qrData = barcode.rawValue;
          if (qrData != null) {
            try {
              final data = parseQRData(qrData);
              await storePreTicketToFirestore(data);
              Navigator.of(context).pop(true);
            } catch (e) {
              Navigator.of(context).pop(false);
            }
          }
        },
      ),
    );
  }
}

Map<String, dynamic> parseQRData(String qrData) {
  return Map<String, dynamic>.from(jsonDecode(qrData));
}

Future<void> storePreTicketToFirestore(Map<String, dynamic> data) async {
  final route = data['route'];
  final tripsCollection = FirebaseFirestore.instance
      .collection('trips')
      .doc(route)
      .collection('trips');

  final snapshot = await tripsCollection.get();
  int maxTripNumber = 0;
  for (var doc in snapshot.docs) {
    final tripName = doc.id;
    final parts = tripName.split(' ');
    if (parts.length == 2 && int.tryParse(parts[1]) != null) {
      final num = int.parse(parts[1]);
      if (num > maxTripNumber) maxTripNumber = num;
    }
  }
  final tripNumber = maxTripNumber + 1;
  final tripDocName = "trip $tripNumber";

  await tripsCollection.doc(tripDocName).set({
    'from': data['from'],
    'to': data['to'],
    'startKm': data['fromKm'],
    'endKm': data['toKm'],
    'totalKm': (data['toKm'] as num) - (data['fromKm'] as num),
    'timestamp': FieldValue.serverTimestamp(),
    'active': true,
    'quantity': data['quantity'],
    'discountAmount': '',
    'farePerPassenger': data['fare'],
    'totalFare': data['amount'],
    'fareTypes': data['fareTypes'],
    'discountBreakdown': data['discountBreakdown'],
  });
}
