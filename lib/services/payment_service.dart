import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentService {
  static const String _adminWebsiteUrl =
      'https://b-go-capstone-admin-chi.vercel.app';

  /// Create PayMongo checkout session and launch payment
  static Future<Map<String, dynamic>> launchPaymentPage({
    required String bookingId,
    required double amount,
    required String route,
    required String fromPlace,
    required String toPlace,
    required int quantity,
    required List<String> fareTypes,
    required String userId,
  }) async {
    try {
      print('🚀 PaymentService: Creating PayMongo checkout session...');

      // Check network connectivity first
      if (!await _isNetworkAvailable()) {
        print('⚠️ PaymentService: No network connectivity, using test mode');
        return await _launchFallbackPaymentPage(
          bookingId: bookingId,
          amount: amount,
          route: route,
          fromPlace: fromPlace,
          toPlace: toPlace,
          quantity: quantity,
          fareTypes: fareTypes,
          userId: userId,
        );
      }

      // First, create the PayMongo payment intent via your admin website API
      final checkoutResponse = await http.post(
        Uri.parse('$_adminWebsiteUrl/api/create-payment-intent'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'amount': (amount * 100).round(), // Convert to centavos
          'currency': 'PHP',
          'metadata': {
            'bookingId': bookingId,
            'userId': userId,
            'route': route,
            'fromPlace': fromPlace,
            'toPlace': toPlace,
            'quantity': quantity,
            'fareTypes': fareTypes.join(','),
            'source': 'flutter_app',
          },
        }),
      ).timeout(Duration(seconds: 15)); // Add timeout

      if (checkoutResponse.statusCode == 200) {
        final checkoutData = json.decode(checkoutResponse.body);
        final checkoutUrl = checkoutData['checkoutUrl'];

        if (checkoutUrl == null || checkoutUrl.isEmpty) {
          print(
              '❌ PaymentService: No checkout URL received from admin website');
          return {'success': false, 'error': 'No checkout URL received'};
        }

        print(
            '✅ PaymentService: Checkout session created, launching: $checkoutUrl');

        // Launch the PayMongo checkout URL
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunch(uri.toString())) {
          await launch(
            uri.toString(),
            forceSafariVC: false,
            forceWebView: false,
          );
          print('✅ PaymentService: PayMongo checkout launched successfully');
          return {'success': true, 'url': checkoutUrl};
        } else {
          print('❌ PaymentService: Could not launch checkout URL');
          return {
            'success': false,
            'error': 'Could not launch checkout URL',
            'url': checkoutUrl
          };
        }
      } else if (checkoutResponse.statusCode == 404) {
        // Admin website API not implemented yet - use fallback for testing
        print(
            '⚠️ PaymentService: Admin website API not available (404), using fallback for testing');
        return await _launchFallbackPaymentPage(
          bookingId: bookingId,
          amount: amount,
          route: route,
          fromPlace: fromPlace,
          toPlace: toPlace,
          quantity: quantity,
          fareTypes: fareTypes,
          userId: userId,
        );
      } else {
        print(
            '❌ PaymentService: Failed to create checkout session: ${checkoutResponse.statusCode}');
        print('Response: ${checkoutResponse.body}');

        // Try to parse error message
        try {
          final errorData = json.decode(checkoutResponse.body);
          print('Error details: ${errorData['error']}');
        } catch (e) {
          print('Could not parse error response');
        }

        // Use fallback on API errors
        print('⚠️ PaymentService: Using fallback due to API error');
        return await _launchFallbackPaymentPage(
          bookingId: bookingId,
          amount: amount,
          route: route,
          fromPlace: fromPlace,
          toPlace: toPlace,
          quantity: quantity,
          fareTypes: fareTypes,
          userId: userId,
        );
      }
    } catch (e) {
      print('❌ PaymentService: Error creating checkout session: $e');
      // Try fallback on any error
      return await _launchFallbackPaymentPage(
        bookingId: bookingId,
        amount: amount,
        route: route,
        fromPlace: fromPlace,
        toPlace: toPlace,
        quantity: quantity,
        fareTypes: fareTypes,
        userId: userId,
      );
    }
  }

  /// Fallback payment page for testing when admin website API is not available
  static Future<Map<String, dynamic>> _launchFallbackPaymentPage({
    required String bookingId,
    required double amount,
    required String route,
    required String fromPlace,
    required String toPlace,
    required int quantity,
    required List<String> fareTypes,
    required String userId,
  }) async {
    try {
      print('🔄 PaymentService: Using fallback payment page for testing...');

      // For emulator testing, create a simple HTML payment page
      final paymentUrl = 'data:text/html;charset=utf-8,'
          '<!DOCTYPE html>'
          '<html>'
          '<head>'
          '<title>B-GO Payment - Test Mode</title>'
          '<meta name="viewport" content="width=device-width, initial-scale=1">'
          '<style>'
          'body { font-family: Arial, sans-serif; padding: 20px; background: #f5f5f5; }'
          '.container { max-width: 400px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }'
          '.header { text-align: center; color: #2c3e50; margin-bottom: 20px; }'
          '.info { background: #e8f4f8; padding: 15px; border-radius: 5px; margin: 10px 0; }'
          '.amount { font-size: 24px; font-weight: bold; color: #27ae60; text-align: center; margin: 20px 0; }'
          '.button { background: #3498db; color: white; padding: 15px 30px; border: none; border-radius: 5px; font-size: 16px; cursor: pointer; width: 100%; margin: 10px 0; }'
          '.button:hover { background: #2980b9; }'
          '.success { background: #27ae60; }'
          '.warning { background: #f39c12; }'
          '.error { background: #e74c3c; }'
          '</style>'
          '</head>'
          '<body>'
          '<div class="container">'
          '<div class="header">'
          '<h1>🚌 B-GO Bus</h1>'
          '<h2>Payment Test Mode</h2>'
          '</div>'
          '<div class="info">'
          '<strong>Route:</strong> $route<br>'
          '<strong>From:</strong> $fromPlace<br>'
          '<strong>To:</strong> $toPlace<br>'
          '<strong>Quantity:</strong> $quantity<br>'
          '<strong>Fare Types:</strong> ${fareTypes.join(', ')}<br>'
          '<strong>Booking ID:</strong> $bookingId'
          '</div>'
          '<div class="amount">₱${amount.toStringAsFixed(2)}</div>'
          '<button class="button success" onclick="simulatePayment()">✅ Simulate Successful Payment</button>'
          '<button class="button warning" onclick="simulatePending()">⏳ Simulate Pending Payment</button>'
          '<button class="button error" onclick="simulateFailed()">❌ Simulate Failed Payment</button>'
          '<div id="status" style="margin-top: 20px; padding: 10px; border-radius: 5px; display: none;"></div>'
          '</div>'
          '<script>'
          'function showStatus(message, type) {'
          '  const status = document.getElementById("status");'
          '  status.textContent = message;'
          '  status.className = type;'
          '  status.style.display = "block";'
          '}'
          'function simulatePayment() {'
          '  showStatus("✅ Payment successful! This is a test simulation.", "success");'
          '  setTimeout(() => {'
          '    window.close();'
          '  }, 2000);'
          '}'
          'function simulatePending() {'
          '  showStatus("⏳ Payment is pending. Please wait...", "warning");'
          '}'
          'function simulateFailed() {'
          '  showStatus("❌ Payment failed. Please try again.", "error");'
          '}'
          '</script>'
          '</body>'
          '</html>';

      print('✅ PaymentService: Launching test payment page');

      final uri = Uri.parse(paymentUrl);

      // Try to launch the data URL
      if (await canLaunch(uri.toString())) {
        await launch(
          uri.toString(),
          forceSafariVC: false,
          forceWebView: true,
        );
        print('✅ PaymentService: Test payment page launched successfully');
        return {'success': true, 'url': paymentUrl, 'testMode': true};
      } else {
        print('❌ PaymentService: Could not launch test payment page');
        return {
          'success': false,
          'error': 'Could not launch test payment page',
          'testMode': true
        };
      }
    } catch (e) {
      print('❌ PaymentService: Error launching test payment page: $e');
      return {'success': false, 'error': 'Error launching test payment page: $e'};
    }
  }

  /// Check payment status from the admin website
  static Future<Map<String, dynamic>?> checkPaymentStatus(
      String bookingId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Check network connectivity first
      if (!await _isNetworkAvailable()) {
        print('⚠️ PaymentService: No network connectivity, checking Firestore directly');
        return await _checkPaymentStatusFromFirestore(bookingId);
      }

      // Updated URL to match the new API endpoint structure
      final response = await http.get(
        Uri.parse(
            '$_adminWebsiteUrl/api/payment-status/$bookingId?userId=${user.uid}'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10)); // Add timeout

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ PaymentService: Payment status response: $data');
        return data;
      } else if (response.statusCode == 404) {
        // Admin website API not implemented yet - check Firestore directly
        print(
            '⚠️ PaymentService: Admin website API not available (404), checking Firestore directly');
        return await _checkPaymentStatusFromFirestore(bookingId);
      } else {
        print(
            '❌ PaymentService: Failed to check payment status: ${response.statusCode}');
        print('Response body: ${response.body}');
        // Fallback to Firestore
        return await _checkPaymentStatusFromFirestore(bookingId);
      }
    } catch (e) {
      print('❌ PaymentService: Error checking payment status: $e');
      // Try Firestore as fallback
      return await _checkPaymentStatusFromFirestore(bookingId);
    }
  }

  /// Check if network is available
  static Future<bool> _isNetworkAvailable() async {
    try {
      // Try to reach a reliable endpoint
      final response = await http.get(
        Uri.parse('https://www.google.com'),
      ).timeout(Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('⚠️ PaymentService: Network check failed: $e');
      return false;
    }
  }

  /// Check payment status directly from Firestore as fallback
  static Future<Map<String, dynamic>?> _checkPaymentStatusFromFirestore(
      String bookingId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .doc(bookingId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'status': data['status'] ?? 'pending_payment',
          'paymongoPaymentId': data['paymongoPaymentId'],
          'amount': data['amount'] ?? 0,
          'paidAt': data['paidAt'],
          'error': data['paymentError'],
        };
      } else {
        print('❌ PaymentService: Booking not found in Firestore');
        return null;
      }
    } catch (e) {
      print(
          '❌ PaymentService: Error checking payment status from Firestore: $e');
      return null;
    }
  }

  /// Update booking status in Firestore after successful payment
  static Future<bool> updateBookingStatus({
    required String bookingId,
    required String status,
    String? paymongoPaymentId,
    String? paymongoCheckoutUrl,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (paymongoPaymentId != null) {
        updateData['paymongoPaymentId'] = paymongoPaymentId;
      }

      if (paymongoCheckoutUrl != null) {
        updateData['paymongoCheckoutUrl'] = paymongoCheckoutUrl;
      }

      if (status == 'paid') {
        updateData['paidAt'] = FieldValue.serverTimestamp();
        updateData['boardingStatus'] = 'pending';
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .doc(bookingId)
          .update(updateData);

      print('✅ PaymentService: Booking status updated successfully');
      return true;
    } catch (e) {
      print('❌ PaymentService: Error updating booking status: $e');
      return false;
    }
  }

  /// Handle webhook from PayMongo (to be called from admin website)
  static Future<bool> handlePayMongoWebhook({
    required String bookingId,
    required String paymentStatus,
    required String paymongoPaymentId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final updateData = {
        'paymentStatus': paymentStatus,
        'paymongoPaymentId': paymongoPaymentId,
        'webhookReceivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (additionalData != null) {
        updateData.addAll(additionalData.cast<String, Object>());
      }

      if (paymentStatus == 'paid') {
        updateData['status'] = 'paid';
        updateData['paidAt'] = FieldValue.serverTimestamp();
        updateData['boardingStatus'] = 'pending';
      } else if (paymentStatus == 'failed') {
        updateData['status'] = 'payment_failed';
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .doc(bookingId)
          .update(updateData);

      print('✅ PaymentService: Webhook handled successfully');
      return true;
    } catch (e) {
      print('❌ PaymentService: Error handling webhook: $e');
      return false;
    }
  }

  /// Get booking details for payment
  static Future<Map<String, dynamic>?> getBookingDetails(
      String bookingId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .doc(bookingId)
          .get();

      if (doc.exists) {
        return doc.data();
      } else {
        print('❌ PaymentService: Booking not found');
        return null;
      }
    } catch (e) {
      print('❌ PaymentService: Error getting booking details: $e');
      return null;
    }
  }

  /// Cancel a booking
  static Future<bool> cancelBooking(String bookingId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .doc(bookingId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ PaymentService: Booking cancelled successfully');
      return true;
    } catch (e) {
      print('❌ PaymentService: Error cancelling booking: $e');
      return false;
    }
  }

  /// Simulate payment completion for testing (only use in development)
  static Future<bool> simulatePaymentCompletion(String bookingId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .doc(bookingId)
          .update({
        'status': 'paid',
        'paymentStatus': 'paid',
        'paymongoPaymentId': 'test_payment_${DateTime.now().millisecondsSinceEpoch}',
        'paidAt': FieldValue.serverTimestamp(),
        'boardingStatus': 'pending',
        'paymentMethod': 'test_card',
        'paymentCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'testMode': true,
      });

      print('✅ PaymentService: Payment simulation completed successfully');
      return true;
    } catch (e) {
      print('❌ PaymentService: Error simulating payment completion: $e');
      return false;
    }
  }

  /// Get all bookings for the current user
  static Future<List<Map<String, dynamic>>> getAllBookings({
    String? status,
    int? limit,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .orderBy('createdAt', descending: true);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('❌ PaymentService: Error getting all bookings: $e');
      return [];
    }
  }

  /// Get booking statistics for the current user
  static Future<Map<String, dynamic>> getBookingStatistics() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .get();

      int totalBookings = 0;
      int paidBookings = 0;
      int pendingBookings = 0;
      int cancelledBookings = 0;
      double totalAmount = 0.0;
      double paidAmount = 0.0;

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue; // Skip null data
        final status = data['status'] ?? 'pending_payment';
        final amount = (data['amount'] ?? 0.0).toDouble();

        totalBookings++;
        totalAmount += amount;

        switch (status) {
          case 'paid':
            paidBookings++;
            paidAmount += amount;
            break;
          case 'pending_payment':
            pendingBookings++;
            break;
          case 'cancelled':
          case 'payment_failed':
            cancelledBookings++;
            break;
        }
      }

      return {
        'totalBookings': totalBookings,
        'paidBookings': paidBookings,
        'pendingBookings': pendingBookings,
        'cancelledBookings': cancelledBookings,
        'totalAmount': totalAmount,
        'paidAmount': paidAmount,
        'successRate': totalBookings > 0 ? (paidBookings / totalBookings) * 100 : 0.0,
      };
    } catch (e) {
      print('❌ PaymentService: Error getting booking statistics: $e');
      return {};
    }
  }

  /// Retry failed payment
  static Future<Map<String, dynamic>> retryPayment(String bookingId) async {
    try {
      final bookingDetails = await getBookingDetails(bookingId);
      if (bookingDetails == null) {
        return {'success': false, 'error': 'Booking not found'};
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      // Reset booking status to pending_payment
      await updateBookingStatus(
        bookingId: bookingId,
        status: 'pending_payment',
      );

      // Launch payment page again
      return await launchPaymentPage(
        bookingId: bookingId,
        amount: (bookingDetails['amount'] ?? 0.0).toDouble(),
        route: bookingDetails['route'] ?? '',
        fromPlace: bookingDetails['from'] ?? '',
        toPlace: bookingDetails['to'] ?? '',
        quantity: bookingDetails['quantity'] ?? 1,
        fareTypes: List<String>.from(bookingDetails['fareTypes'] ?? []),
        userId: user.uid,
      );
    } catch (e) {
      print('❌ PaymentService: Error retrying payment: $e');
      return {'success': false, 'error': 'Error retrying payment: $e'};
    }
  }

  /// Validate payment data before processing
  static Map<String, dynamic> validatePaymentData({
    required String bookingId,
    required double amount,
    required String route,
    required String fromPlace,
    required String toPlace,
    required int quantity,
    required List<String> fareTypes,
    required String userId,
  }) {
    final errors = <String>[];

    if (bookingId.isEmpty) {
      errors.add('Booking ID is required');
    }

    if (amount <= 0) {
      errors.add('Amount must be greater than 0');
    }

    if (route.isEmpty) {
      errors.add('Route is required');
    }

    if (fromPlace.isEmpty) {
      errors.add('From place is required');
    }

    if (toPlace.isEmpty) {
      errors.add('To place is required');
    }

    if (quantity <= 0) {
      errors.add('Quantity must be greater than 0');
    }

    if (fareTypes.isEmpty) {
      errors.add('Fare types are required');
    }

    if (userId.isEmpty) {
      errors.add('User ID is required');
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
    };
  }

  /// Get payment history for a specific booking
  static Future<List<Map<String, dynamic>>> getPaymentHistory(String bookingId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('paymentHistory')
          .where('bookingId', isEqualTo: bookingId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => doc.data())
          .toList();
    } catch (e) {
      print('❌ PaymentService: Error getting payment history: $e');
      return [];
    }
  }

  /// Log payment event for debugging and analytics
  static Future<void> logPaymentEvent({
    required String bookingId,
    required String eventType,
    required Map<String, dynamic> data,
    String? error,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('paymentLogs')
          .add({
        'bookingId': bookingId,
        'eventType': eventType,
        'data': data,
        'error': error,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': user.uid,
      });
    } catch (e) {
      print('❌ PaymentService: Error logging payment event: $e');
    }
  }

  /// Check if payment is still valid (not expired)
  static Future<bool> isPaymentValid(String bookingId) async {
    try {
      final bookingDetails = await getBookingDetails(bookingId);
      if (bookingDetails == null) return false;

      final status = bookingDetails['status'];
      final paymentDeadline = bookingDetails['paymentDeadline'] as Timestamp?;

      if (status == 'paid') return true;
      if (status == 'cancelled' || status == 'payment_failed') return false;

      if (paymentDeadline != null) {
        final deadline = paymentDeadline.toDate();
        return DateTime.now().isBefore(deadline);
      }

      return true; // No deadline set, assume valid
    } catch (e) {
      print('❌ PaymentService: Error checking payment validity: $e');
      return false;
    }
  }

  /// Extend payment deadline
  static Future<bool> extendPaymentDeadline(String bookingId, {int minutes = 10}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final newDeadline = DateTime.now().add(Duration(minutes: minutes));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .doc(bookingId)
          .update({
        'paymentDeadline': Timestamp.fromDate(newDeadline),
        'updatedAt': FieldValue.serverTimestamp(),
        'deadlineExtendedAt': FieldValue.serverTimestamp(),
        'deadlineExtensionMinutes': minutes,
      });

      print('✅ PaymentService: Payment deadline extended by $minutes minutes');
      return true;
    } catch (e) {
      print('❌ PaymentService: Error extending payment deadline: $e');
      return false;
    }
  }

  /// Get payment methods available for the user
  static Future<List<Map<String, dynamic>>> getAvailablePaymentMethods() async {
    try {
      // This would typically come from your admin website or PayMongo API
      // For now, return a static list of available payment methods
      return [
        {
          'id': 'gcash',
          'name': 'GCash',
          'description': 'Pay using your GCash account',
          'icon': 'gcash_icon',
          'enabled': true,
        },
        {
          'id': 'grab_pay',
          'name': 'GrabPay',
          'description': 'Pay using your GrabPay wallet',
          'icon': 'grab_pay_icon',
          'enabled': true,
        },
        {
          'id': 'credit_card',
          'name': 'Credit/Debit Card',
          'description': 'Pay using your credit or debit card',
          'icon': 'credit_card_icon',
          'enabled': true,
        },
        {
          'id': 'bank_transfer',
          'name': 'Bank Transfer',
          'description': 'Pay via bank transfer',
          'icon': 'bank_transfer_icon',
          'enabled': false, // Disabled for now
        },
      ];
    } catch (e) {
      print('❌ PaymentService: Error getting payment methods: $e');
      return [];
    }
  }

  /// Send payment reminder notification
  static Future<bool> sendPaymentReminder(String bookingId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final bookingDetails = await getBookingDetails(bookingId);
      if (bookingDetails == null) return false;

      // Add reminder to user's notifications
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add({
        'type': 'payment_reminder',
        'bookingId': bookingId,
        'title': 'Payment Reminder',
        'message': 'Your payment for ${bookingDetails['route']} is still pending. Please complete your payment to secure your booking.',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'priority': 'high',
      });

      // Update booking with reminder timestamp
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .doc(bookingId)
          .update({
        'lastReminderSent': FieldValue.serverTimestamp(),
        'reminderCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ PaymentService: Payment reminder sent successfully');
      return true;
    } catch (e) {
      print('❌ PaymentService: Error sending payment reminder: $e');
      return false;
    }
  }

  /// Get payment analytics for admin dashboard
  static Future<Map<String, dynamic>> getPaymentAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      Query query = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings');

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();

      int totalTransactions = 0;
      int successfulPayments = 0;
      int failedPayments = 0;
      int pendingPayments = 0;
      double totalRevenue = 0.0;
      double averageTransactionValue = 0.0;
      Map<String, int> paymentMethodCounts = {};
      Map<String, double> routeRevenue = {};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue; // Skip null data
        final status = data['status'] ?? 'pending_payment';
        final amount = (data['amount'] ?? 0.0).toDouble();
        final route = data['route'] ?? 'Unknown';
        final paymentMethod = data['paymentMethod'] ?? 'unknown';

        totalTransactions++;
        totalRevenue += amount;

        switch (status) {
          case 'paid':
            successfulPayments++;
            break;
          case 'payment_failed':
            failedPayments++;
            break;
          case 'pending_payment':
            pendingPayments++;
            break;
        }

        // Count payment methods
        paymentMethodCounts[paymentMethod] = (paymentMethodCounts[paymentMethod] ?? 0) + 1;

        // Calculate route revenue
        if (status == 'paid') {
          routeRevenue[route] = (routeRevenue[route] ?? 0.0) + amount;
        }
      }

      averageTransactionValue = totalTransactions > 0 ? totalRevenue / totalTransactions : 0.0;

      return {
        'totalTransactions': totalTransactions,
        'successfulPayments': successfulPayments,
        'failedPayments': failedPayments,
        'pendingPayments': pendingPayments,
        'totalRevenue': totalRevenue,
        'averageTransactionValue': averageTransactionValue,
        'successRate': totalTransactions > 0 ? (successfulPayments / totalTransactions) * 100 : 0.0,
        'paymentMethodCounts': paymentMethodCounts,
        'routeRevenue': routeRevenue,
        'period': {
          'startDate': startDate?.toIso8601String(),
          'endDate': endDate?.toIso8601String(),
        },
      };
    } catch (e) {
      print('❌ PaymentService: Error getting payment analytics: $e');
      return {};
    }
  }

  /// Clean up expired bookings
  static Future<int> cleanupExpiredBookings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0;

      final now = DateTime.now();
      final expiredThreshold = now.subtract(Duration(hours: 24)); // 24 hours ago

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .where('status', isEqualTo: 'pending_payment')
          .where('createdAt', isLessThan: Timestamp.fromDate(expiredThreshold))
          .get();

      int cleanedCount = 0;
      final batch = FirebaseFirestore.instance.batch();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'status': 'expired',
          'expiredAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        cleanedCount++;
      }

      if (cleanedCount > 0) {
        await batch.commit();
        print('✅ PaymentService: Cleaned up $cleanedCount expired bookings');
      }

      return cleanedCount;
    } catch (e) {
      print('❌ PaymentService: Error cleaning up expired bookings: $e');
      return 0;
    }
  }

  /// Get payment status summary for dashboard
  static Future<Map<String, dynamic>> getPaymentStatusSummary() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: 7));
      final monthStart = DateTime(now.year, now.month, 1);

      // Get today's bookings
      final todaySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .get();

      // Get this week's bookings
      final weekSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
          .get();

      // Get this month's bookings
      final monthSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .get();

      return {
        'today': _calculateSummaryFromSnapshot(todaySnapshot),
        'thisWeek': _calculateSummaryFromSnapshot(weekSnapshot),
        'thisMonth': _calculateSummaryFromSnapshot(monthSnapshot),
        'lastUpdated': now.toIso8601String(),
      };
    } catch (e) {
      print('❌ PaymentService: Error getting payment status summary: $e');
      return {};
    }
  }

  /// Helper method to calculate summary from snapshot
  static Map<String, dynamic> _calculateSummaryFromSnapshot(QuerySnapshot snapshot) {
    int total = 0;
    int paid = 0;
    int pending = 0;
    int failed = 0;
    double totalAmount = 0.0;
    double paidAmount = 0.0;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue; // Skip null data
      final status = data['status'] ?? 'pending_payment';
      final amount = (data['amount'] ?? 0.0).toDouble();

      total++;
      totalAmount += amount;

      switch (status) {
        case 'paid':
          paid++;
          paidAmount += amount;
          break;
        case 'pending_payment':
          pending++;
          break;
        case 'payment_failed':
        case 'cancelled':
          failed++;
          break;
      }
    }

    return {
      'total': total,
      'paid': paid,
      'pending': pending,
      'failed': failed,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'successRate': total > 0 ? (paid / total) * 100 : 0.0,
    };
  }
}
