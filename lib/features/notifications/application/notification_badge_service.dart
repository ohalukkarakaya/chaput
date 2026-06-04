import 'package:flutter/services.dart';

class NotificationBadgeService {
  NotificationBadgeService._();

  static const MethodChannel _channel = MethodChannel('chaput/notifications');

  static Future<void> resetAppIconBadge() async {
    try {
      await _channel.invokeMethod<void>('resetBadge');
    } catch (_) {
      // Badge support varies by platform/launcher. Failure should never block app boot.
    }
  }
}
