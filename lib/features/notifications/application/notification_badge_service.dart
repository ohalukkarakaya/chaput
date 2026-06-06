import 'package:flutter/services.dart';

import 'local_notification_service.dart';

class NotificationBadgeService {
  NotificationBadgeService._();

  static const MethodChannel _channel = MethodChannel('chaput/notifications');

  static Future<void> resetAppIconBadge() async {
    try {
      await LocalNotificationService.instance.clearDeliveredNotifications();
    } catch (_) {
      // Delivered notification cleanup should not block badge reset.
    }
    try {
      await _channel.invokeMethod<void>('resetBadge');
    } catch (_) {
      // Badge support varies by platform/launcher. Failure should never block app boot.
    }
  }
}
