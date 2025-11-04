import 'package:flutter/services.dart';

/// Platform channel to communicate with native Android code
class ForegroundServiceManager {
  static const MethodChannel _channel = 
      MethodChannel('com.example.capstone_project/foreground_service');

  /// Start Android foreground service
  static Future<bool> startForegroundService() async {
    try {
      final result = await _channel.invokeMethod('startForegroundService');
      print('✅ Foreground service started: $result');
      return result == true;
    } on PlatformException catch (e) {
      print('❌ Error starting foreground service: ${e.message}');
      return false;
    }
  }

  /// Stop Android foreground service
  static Future<bool> stopForegroundService() async {
    try {
      final result = await _channel.invokeMethod('stopForegroundService');
      print('✅ Foreground service stopped: $result');
      return result == true;
    } on PlatformException catch (e) {
      print('❌ Error stopping foreground service: ${e.message}');
      return false;
    }
  }

  /// Request background location permission (Android 10+)
  static Future<bool> requestBackgroundLocationPermission() async {
    try {
      final result = await _channel.invokeMethod('requestBackgroundLocationPermission');
      print('✅ Background location permission requested: $result');
      return result == true;
    } on PlatformException catch (e) {
      print('❌ Error requesting background location permission: ${e.message}');
      return false;
    }
  }
}