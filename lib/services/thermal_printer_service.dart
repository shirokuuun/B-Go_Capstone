import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ThermalPrinterService {
  static const platform = MethodChannel('com.bgo.printer/print');
  static const String companyTIN = '738-990-391-000NV'; // ✅ BATRASCO TIN

  bool get isConnected => true;

  Future<bool> connectPrinter(String ip, int port) async {
    return true;
  }

  void disconnectPrinter() {}

  String? get savedPrinterIp => null;
  int? get savedPrinterPort => null;

  static Future<void> showPrinterConnectionDialog(
    BuildContext context,
    Function(String ip, int port) onConnect,
  ) async {
    onConnect('', 0);
  }

  Future<bool> printManualTicket({
    required String route,
    required String from,
    required String to,
    required String fromKm,
    required String toKm,
    required String baseFare,
    required int quantity,
    required String totalFare,
    required String discountAmount,
    required List<String>? discountBreakdown,
    required String serialNumber,
    required String plateNumber,
    required String busNumber,
  }) async {
    try {
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd').format(now);
      final formattedTime = DateFormat('HH:mm:ss').format(now);

      String receiptText = _buildReceiptText(
        route: route,
        from: from,
        to: to,
        fromKm: fromKm,
        toKm: toKm,
        baseFare: baseFare,
        quantity: quantity,
        totalFare: totalFare,
        discountAmount: discountAmount,
        discountBreakdown: discountBreakdown,
        formattedDate: formattedDate,
        formattedTime: formattedTime,
        serialNumber: serialNumber,
        plateNumber: plateNumber,
        busNumber: busNumber,
      );

      print('🖨️ Sending to built-in printer...');

      // Load logo image as bytes
      ByteData? logoData;
      try {
        logoData = await rootBundle.load('assets/batrasco-logo.png');
      } catch (e) {
        print('⚠️ Could not load logo: $e');
      }

      // Send to built-in printer via native channel
      final bool result = await platform.invokeMethod('printReceipt', {
        'content': receiptText,
        'logoBytes': logoData?.buffer.asUint8List(),
      });

      if (result) {
        print('✅ Print command sent successfully');
      } else {
        print('⚠️ Print command failed');
      }

      return result;
    } catch (e) {
      print('❌ Error printing: $e');
      print('📄 Receipt content:');
      print(_buildReceiptText(
        route: route,
        from: from,
        to: to,
        fromKm: fromKm,
        toKm: toKm,
        baseFare: baseFare,
        quantity: quantity,
        totalFare: totalFare,
        discountAmount: discountAmount,
        discountBreakdown: discountBreakdown,
        formattedDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        formattedTime: DateFormat('HH:mm:ss').format(DateTime.now()),
        serialNumber: serialNumber,
        plateNumber: plateNumber,
        busNumber: busNumber,
      ));
      return false;
    }
  }

  String _buildReceiptText({
    required String route,
    required String from,
    required String to,
    required String fromKm,
    required String toKm,
    required String baseFare,
    required int quantity,
    required String totalFare,
    required String discountAmount,
    required List<String>? discountBreakdown,
    required String formattedDate,
    required String formattedTime,
    required String serialNumber,
    required String plateNumber,
    required String busNumber,
  }) {
    StringBuffer receipt = StringBuffer();

    // Header with company info
    receipt.writeln('         BATRASCO');
    receipt.writeln('   TIN: $companyTIN');
    receipt.writeln('');
    receipt.writeln('     OFFICIAL RECEIPT');
    receipt.writeln('================================');
    receipt.writeln('Serial#: $serialNumber');
    receipt.writeln('Plate Number: $plateNumber');
    receipt.writeln('Bus Number: $busNumber');
    receipt.writeln('');
    receipt.writeln('Date: $formattedDate');
    receipt.writeln('Time: $formattedTime');
    receipt.writeln('================================');
    receipt.writeln('');
    receipt.writeln('Route: $route');
    receipt.writeln('');
    receipt.writeln('From: $from');
    receipt.writeln('To: $to');
    receipt.writeln('From KM: $fromKm');
    receipt.writeln('To KM: $toKm');
    receipt.writeln('');
    receipt.writeln('Base Fare: $baseFare PHP');
    receipt.writeln('Quantity: $quantity');
    receipt.writeln('');

    if (discountBreakdown != null && discountBreakdown.isNotEmpty) {
      receipt.writeln('Discounts:');
      for (var discount in discountBreakdown) {
        receipt.writeln('  $discount');
      }
      if (discountAmount != '0.00' && discountAmount.isNotEmpty) {
        receipt.writeln('Total Discount: $discountAmount PHP');
      }
      receipt.writeln('');
    }

    receipt.writeln('================================');
    receipt.writeln('      TOTAL AMOUNT');
    receipt.writeln('      $totalFare PHP');
    receipt.writeln('================================');
    receipt.writeln('');
    receipt.writeln('THIS SERVES AS AN OFFICIAL RECEIPT');
    receipt.writeln('KEEP YOUR TICKET FOR INSPECTION');
    receipt.writeln('');
    receipt.writeln('Thank you for riding with us!');
    receipt.writeln('Safe travels!');
    receipt.writeln('');

    return receipt.toString();
  }
}