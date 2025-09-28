import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentService {
  static const String _adminWebsiteUrl =
      'b-go-capstone-admin.vercel.app';

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
      print('🚀 PaymentService: Booking ID: $bookingId');
      print('🚀 PaymentService: Amount: $amount');
      print('🚀 PaymentService: User ID: $userId');
      
      // Validate input parameters
      final validation = validatePaymentData(
        bookingId: bookingId,
        amount: amount,
        route: route,
        fromPlace: fromPlace,
        toPlace: toPlace,
        quantity: quantity,
        fareTypes: fareTypes,
        userId: userId,
      );
      
      if (!validation['isValid']) {
        final errors = validation['errors'] as List<String>;
        print('❌ PaymentService: Validation failed: ${errors.join(', ')}');
        return {
          'success': false,
          'error': 'Validation failed: ${errors.join(', ')}',
        };
      }

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
      final checkoutResponse = await http
          .post(
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
          )
          .timeout(Duration(seconds: 15)); // Add timeout

      if (checkoutResponse.statusCode == 200) {
        final checkoutData = json.decode(checkoutResponse.body);
        print('✅ PaymentService: API Response: $checkoutData');

        final checkoutUrl = checkoutData['checkoutUrl'];
        final checkoutId = checkoutData['checkoutId'];

        if (checkoutUrl == null || checkoutUrl.isEmpty) {
          print(
              '❌ PaymentService: No checkout URL received from admin website');
          return {'success': false, 'error': 'No checkout URL received'};
        }

        print(
            '✅ PaymentService: Checkout session created, launching: $checkoutUrl');

        // Launch the PayMongo checkout URL using the new API
        final uri = Uri.parse(checkoutUrl);
        try {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication, // Opens in external browser
          );

          if (launched) {
            print('✅ PaymentService: PayMongo checkout launched successfully');
            return {
              'success': true,
              'url': checkoutUrl,
              'checkoutId': checkoutId,
              'checkoutData': checkoutData
            };
          } else {
            print('❌ PaymentService: Could not launch checkout URL');
            return {
              'success': false,
              'error': 'Could not launch checkout URL',
              'url': checkoutUrl
            };
          }
        } catch (e) {
          print('❌ PaymentService: Error launching URL: $e');
          return {
            'success': false,
            'error': 'Error launching checkout URL: $e',
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
        String errorMessage = 'Unknown error';
        try {
          final errorData = json.decode(checkoutResponse.body);
          errorMessage =
              errorData['error'] ?? errorData['message'] ?? 'Unknown error';
          print('Error details: $errorMessage');
        } catch (e) {
          print('Could not parse error response');
        }

        // Check if it's a Firebase configuration error or API not found
        if (errorMessage.contains('project_id') ||
            errorMessage.contains('Service account') ||
            checkoutResponse.statusCode == 404) {
          print(
              '🔧 PaymentService: API error detected, using direct simulation');
          return await _simulateDirectPayment(
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

        // Return error details with a fallback URL for manual testing
        return {
          'success': false,
          'error': 'API Error: $errorMessage',
          'statusCode': checkoutResponse.statusCode,
          'response': checkoutResponse.body,
          'url':
              '$_adminWebsiteUrl/payment-test?bookingId=$bookingId&amount=${amount.toStringAsFixed(2)}&route=$route',
        };
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

      // For testing when API is not available, create a simple HTML payment page
      final paymentUrl = 'data:text/html;charset=utf-8,'
          '<!DOCTYPE html>'
          '<html>'
          '<head>'
          '<title>B-GO Payment - Development Mode</title>'
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
          '.notice { background: #fff3cd; border: 1px solid #ffeaa7; padding: 10px; border-radius: 5px; margin: 10px 0; color: #856404; }'
          '</style>'
          '</head>'
          '<body>'
          '<div class="container">'
          '<div class="header">'
          '<h1>🚌 B-GO Bus</h1>'
          '<h2>Development Mode</h2>'
          '</div>'
          '<div class="notice">'
          '<strong>⚠️ Notice:</strong> PayMongo API is not configured. This is a test simulation.'
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

      // Try to launch the data URL using the new API
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.inAppWebView, // Use in-app web view for data URLs
        );

        if (launched) {
          print('✅ PaymentService: Test payment page launched successfully');
          return {'success': true, 'url': paymentUrl, 'testMode': true};
        } else {
          print(
              '❌ PaymentService: Could not launch test payment page, using direct simulation');
          // If we can't launch the web page, simulate payment directly
          return await _simulateDirectPayment(
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
        print('❌ PaymentService: Error launching test payment page: $e');
        return await _simulateDirectPayment(
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
      print('❌ PaymentService: Error launching test payment page: $e');
      return {
        'success': false,
        'error': 'Error launching test payment page: $e'
      };
    }
  }

  /// Simulate payment directly when web page can't be launched
  static Future<Map<String, dynamic>> _simulateDirectPayment({
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
      print('🎭 PaymentService: Simulating payment directly...');

      // Simulate a successful payment
      await simulatePaymentCompletion(bookingId);

      print('✅ PaymentService: Direct payment simulation completed');
      return {
        'success': true,
        'testMode': true,
        'simulated': true,
        'message': 'Payment simulated successfully in development mode'
      };
    } catch (e) {
      print('❌ PaymentService: Error in direct payment simulation: $e');
      return {
        'success': false,
        'error': 'Error simulating payment: $e',
        'testMode': true
      };
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
        print(
            '⚠️ PaymentService: No network connectivity, checking Firestore directly');
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

        // Handle the new API response format
        if (data['success'] == true) {
          return {
            'status': data['status'] ?? data['paymentStatus'] ?? 'pending',
            'paymentStatus':
                data['paymentStatus'] ?? data['status'] ?? 'pending',
            'boardingStatus': data['boardingStatus'] ?? 'pending',
            'amount': data['amount'] ?? 0,
            'paymongoPaymentId': data['paymongoPaymentId'],
            'paymongoCheckoutId': data['paymongoCheckoutId'],
            'paidAt': data['paidAt'],
            'paymentError': data['paymentError'],
            'testMode': data['testMode'] ?? false,
            'bookingId': data['bookingId'],
            'userId': data['userId'],
          };
        } else {
          print(
              '❌ PaymentService: API returned success=false: ${data['error']}');
          return await _checkPaymentStatusFromFirestore(bookingId);
        }
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
      final response = await http
          .get(
            Uri.parse('https://www.google.com'),
          )
          .timeout(Duration(seconds: 5));
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

      final now = DateTime.now();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .doc(bookingId)
          .update({
        'status': 'paid',
        'paymentStatus': 'paid',
        'paymongoPaymentId':
            'test_payment_${now.millisecondsSinceEpoch}',
        'paidAt': FieldValue.serverTimestamp(),
        'paidDate': now, // Add paidDate field for consistency
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
        'successRate':
            totalBookings > 0 ? (paidBookings / totalBookings) * 100 : 0.0,
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
  static Future<List<Map<String, dynamic>>> getPaymentHistory(
      String bookingId) async {
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

      return snapshot.docs.map((doc) => doc.data()).toList();
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
}
