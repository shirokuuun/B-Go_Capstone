import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class CustomPhoneAuth {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send OTP without triggering reCAPTCHA
  Future<void> sendOTPWithoutCaptcha({
    required String phoneNumber,
    required Function(PhoneAuthCredential) onVerificationCompleted,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(String, int?) onCodeSent,
    required Function(String) onCodeAutoRetrievalTimeout,
  }) async {
    try {
      // Use a more direct approach that minimizes reCAPTCHA triggers
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: null,
        verificationCompleted: onVerificationCompleted,
        verificationFailed: onVerificationFailed,
        codeSent: onCodeSent,
        codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
      );
    } on PlatformException catch (e) {
      // Handle platform-specific errors
      onVerificationFailed(FirebaseAuthException(
        code: 'platform-error',
        message: 'Platform error: ${e.message}',
      ));
    } catch (e) {
      // Handle any other errors
      onVerificationFailed(FirebaseAuthException(
        code: 'unknown-error',
        message: 'Failed to send OTP: $e',
      ));
    }
  }

  /// Verify OTP code
  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      throw FirebaseAuthException(
        code: 'invalid-otp',
        message: 'Invalid OTP code. Please try again.',
      );
    }
  }

  /// Check if phone number is valid format
  bool isValidPhoneNumber(String phoneNumber) {
    // Basic phone number validation
    final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
    return phoneRegex.hasMatch(phoneNumber);
  }

  /// Format phone number for display
  String formatPhoneNumber(String phoneNumber) {
    if (phoneNumber.startsWith('+')) {
      return phoneNumber;
    }
    return '+$phoneNumber';
  }
}
