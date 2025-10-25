import 'dart:async';
import 'package:b_go/pages/bus_reserve/reservation_service.dart';

class ExpiredReservationService {
  static Timer? _timer;
  static bool _isRunning = false;

  /// Start the service to check for expired reservations every hour
  static void startService() {
    if (_isRunning) return;
    
    _isRunning = true;
    _timer = Timer.periodic(Duration(hours: 1), (timer) {
      _checkForExpiredReservations();
    });
    
    print('🕐 ExpiredReservationService started - checking every hour');
  }

  /// Stop the service
  static void stopService() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    print('🛑 ExpiredReservationService stopped');
  }

  /// Check if the service is running
  static bool get isRunning => _isRunning;

  /// Manually trigger a check for expired reservations
  static Future<void> checkNow() async {
    await _checkForExpiredReservations();
  }

  /// Internal method to check for expired reservations
  static Future<void> _checkForExpiredReservations() async {
    try {
      // Cancel expired pending reservations (older than 2 days)
      await ReservationService.cancelExpiredReservations();
      
      // Make buses available again after their reservation date has passed
      await ReservationService.updateExpiredReservations();
    } catch (e) {
      print('❌ Error in ExpiredReservationService: $e');
    }
  }
}
