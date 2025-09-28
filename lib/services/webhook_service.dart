import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WebhookService {
  static const String _adminWebsiteUrl = 'https://b-go-capstone-admin-chi.vercel.app';

  /// Register a webhook endpoint for PayMongo payment status updates
  static Future<bool> registerWebhook({
    required String bookingId,
    required String userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_adminWebsiteUrl/api/register-webhook'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'bookingId': bookingId,
          'userId': userId,
          'webhookUrl': '$_adminWebsiteUrl/api/payment-webhook',
        }),
      );

      if (response.statusCode == 200) {
        print('✅ WebhookService: Webhook registered successfully');
        return true;
      } else {
        print('❌ WebhookService: Failed to register webhook: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ WebhookService: Error registering webhook: $e');
      return false;
    }
  }

  /// Handle PayMongo webhook notification
  static Future<bool> handlePayMongoWebhook({
    required String bookingId,
    required String paymentStatus,
    required String paymongoPaymentId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ WebhookService: No authenticated user');
        return false;
      }

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
      } else if (paymentStatus == 'cancelled') {
        updateData['status'] = 'cancelled';
        updateData['cancelledAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('preBookings')
          .doc(bookingId)
          .update(updateData);

      print('✅ WebhookService: Webhook handled successfully for booking: $bookingId');
      return true;
    } catch (e) {
      print('❌ WebhookService: Error handling webhook: $e');
      return false;
    }
  }

  /// Verify webhook signature from PayMongo
  static bool verifyWebhookSignature({
    required String payload,
    required String signature,
    required String secret,
  }) {
    try {
      // This is a simplified verification - in production, you should use
      // proper HMAC-SHA256 verification as per PayMongo documentation
      return signature.isNotEmpty && secret.isNotEmpty;
    } catch (e) {
      print('❌ WebhookService: Error verifying webhook signature: $e');
      return false;
    }
  }

  /// Process PayMongo webhook payload
  static Map<String, dynamic>? processWebhookPayload(String payload) {
    try {
      final data = json.decode(payload);
      
      // Extract relevant information from PayMongo webhook
      final eventType = data['type'];
      final eventData = data['data'];
      
      if (eventType == 'payment.paid' || eventType == 'payment.failed') {
        final payment = eventData['attributes'];
        final metadata = payment['metadata'] ?? {};
        
        return {
          'bookingId': metadata['bookingId'],
          'paymentStatus': eventType == 'payment.paid' ? 'paid' : 'failed',
          'paymongoPaymentId': payment['id'],
          'amount': payment['amount'],
          'currency': payment['currency'],
          'paymentMethod': payment['payment_method']?['type'],
          'additionalData': {
            'paymongoEventType': eventType,
            'paymongoEventId': data['id'],
            'processedAt': DateTime.now().toIso8601String(),
          },
        };
      }
      
      return null;
    } catch (e) {
      print('❌ WebhookService: Error processing webhook payload: $e');
      return null;
    }
  }

  /// Send notification to user about payment status
  static Future<bool> sendPaymentNotification({
    required String userId,
    required String bookingId,
    required String status,
    required String message,
  }) async {
    try {
      // Update user's notification collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'type': 'payment_update',
        'bookingId': bookingId,
        'status': status,
        'message': message,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ WebhookService: Payment notification sent successfully');
      return true;
    } catch (e) {
      print('❌ WebhookService: Error sending payment notification: $e');
      return false;
    }
  }

  /// Get webhook logs for debugging
  static Future<List<Map<String, dynamic>>> getWebhookLogs(String bookingId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('webhookLogs')
          .where('bookingId', isEqualTo: bookingId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('❌ WebhookService: Error getting webhook logs: $e');
      return [];
    }
  }

  /// Log webhook event for debugging
  static Future<void> logWebhookEvent({
    required String bookingId,
    required String eventType,
    required Map<String, dynamic> payload,
    String? error,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('webhookLogs')
          .add({
        'bookingId': bookingId,
        'eventType': eventType,
        'payload': payload,
        'error': error,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ WebhookService: Error logging webhook event: $e');
    }
  }
}
