import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

/// Service to show local notifications for passenger drop-offs
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      print('✅ NotificationService: Initialized successfully');
    } catch (e) {
      print('❌ NotificationService: Initialization failed: $e');
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      // For Android 13+ (API 33+), need to request notification permission
      final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        print('📱 Notification permission granted: $granted');
        return granted ?? false;
      }

      // For iOS
      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        print('📱 iOS notification permission granted: $granted');
        return granted ?? false;
      }

      return true;
    } catch (e) {
      print('❌ Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Show passenger drop-off notification
  Future<void> showDropOffNotification({
    required String destination,
    required int passengerCount,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // ✅ FIX: Build message dynamically, not as const
      final passengerText = passengerCount > 1 ? 'passengers' : 'passenger';
      final message = '$passengerCount $passengerText dropped off at $destination';
      
      // ✅ FIX: Remove const and build AndroidNotificationDetails dynamically
      final androidDetails = AndroidNotificationDetails(
        'passenger_dropoff_channel', // Channel ID
        'Passenger Drop-offs', // Channel name
        channelDescription: 'Notifications for passenger drop-offs',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        // Style as big text with dynamic content
        styleInformation: BigTextStyleInformation(
          message,
          contentTitle: '🎯 Passenger Drop-off Detected',
        ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Use timestamp as unique notification ID
      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _notifications.show(
        notificationId,
        '🎯 Passenger Drop-off Detected',
        message,
        notificationDetails,
        payload: 'dropoff:$destination:$passengerCount',
      );

      print('✅ Notification shown: $passengerCount passenger(s) at $destination');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  /// Show boarding notification
  Future<void> showBoardingNotification({
    required String passengerName,
    required String destination,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        'passenger_boarding_channel',
        'Passenger Boarding',
        channelDescription: 'Notifications for passenger boarding',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _notifications.show(
        notificationId,
        '🚌 Passenger Boarded',
        '$passengerName is heading to $destination',
        notificationDetails,
        payload: 'boarding:$passengerName:$destination',
      );

      print('✅ Boarding notification shown for $passengerName');
    } catch (e) {
      print('❌ Error showing boarding notification: $e');
    }
  }

  /// Show general alert notification
  Future<void> showAlert({
    required String title,
    required String message,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        'alerts_channel',
        'Alerts',
        channelDescription: 'Important alerts and messages',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _notifications.show(
        notificationId,
        title,
        message,
        notificationDetails,
        payload: payload,
      );

      print('✅ Alert notification shown: $title');
    } catch (e) {
      print('❌ Error showing alert: $e');
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    
    if (payload != null) {
      print('📱 Notification tapped with payload: $payload');
      
      // Parse payload and handle accordingly
      if (payload.startsWith('dropoff:')) {
        final parts = payload.split(':');
        if (parts.length >= 3) {
          final destination = parts[1];
          final count = parts[2];
          print('📍 User tapped drop-off notification: $count at $destination');
          // You can navigate to a specific screen here
        }
      } else if (payload.startsWith('boarding:')) {
        final parts = payload.split(':');
        if (parts.length >= 3) {
          final name = parts[1];
          final destination = parts[2];
          print('🚌 User tapped boarding notification: $name to $destination');
          // You can navigate to passenger list here
        }
      }
    }
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Get active notifications (Android only)
  Future<List<ActiveNotification>> getActiveNotifications() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      return await androidPlugin.getActiveNotifications();
    }
    
    return [];
  }
}