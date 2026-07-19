import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/i18n/app_localizations.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static const _kInactiveBaseId = 9000;
  static const _kInactiveScheduleDays = 7;
  static const _kTestReminderMinutes = int.fromEnvironment(
    'CHAPUT_LOCAL_REMINDER_TEST_MINUTES',
    defaultValue: 0,
  );
  static const _kChannelId = 'chaput_local';
  static const _kRemoteChannelId = 'chaput_activity_v2';
  static const _kRemoteSound = 'chaput_push_notification_sound';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<String> _payloads =
      StreamController<String>.broadcast();
  bool _inited = false;
  String? _launchPayload;

  Stream<String> get payloads => _payloads.stream;

  Future<void> init() async {
    if (_inited) return;
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _payloads.add(payload);
        }
      },
    );
    await _ensureRemoteChannel();
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if (launch?.didNotificationLaunchApp == true &&
        payload != null &&
        payload.isNotEmpty) {
      _launchPayload = payload;
    }
    _inited = true;
  }

  Future<void> _ensureRemoteChannel() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final l10n = await AppLocalizations.load(
        PlatformDispatcher.instance.locale,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            AndroidNotificationChannel(
              _kRemoteChannelId,
              l10n.t('notifications.local_channel_name'),
              description: l10n.t('notifications.local_channel_desc'),
              importance: Importance.defaultImportance,
              showBadge: true,
              playSound: true,
              sound: RawResourceAndroidNotificationSound(_kRemoteSound),
            ),
          );
    } catch (_) {
      // Channel creation is best-effort; FCM can still use its default channel.
    }
  }

  String? takeLaunchPayload() {
    final payload = _launchPayload;
    _launchPayload = null;
    return payload;
  }

  Future<void> requestPermissions() async {
    await init();
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (_) {
      // Permission state is best-effort; denied permissions simply mean no local notification.
    }
  }

  Future<void> cancelInactivityReminders() async {
    await init();
    for (var i = 0; i < _kInactiveScheduleDays; i++) {
      await _plugin.cancel(id: _kInactiveBaseId + i);
    }
  }

  Future<void> clearDeliveredNotifications() async {
    await init();
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // Delivered-notification cleanup is best-effort across platforms.
    }
  }

  Future<void> scheduleInactivityReminders({
    required bool hasActiveSession,
    required bool hasAuthenticatedBefore,
  }) async {
    await init();
    await cancelInactivityReminders();

    final kind = hasActiveSession
        ? _InactiveReminderKind.authenticated
        : (!hasAuthenticatedBefore
              ? _InactiveReminderKind.neverLoggedIn
              : null);
    if (kind == null) return;

    final l10n = await AppLocalizations.load(
      PlatformDispatcher.instance.locale,
    );
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _kChannelId,
        l10n.t('notifications.local_channel_name'),
        channelDescription: l10n.t('notifications.local_channel_desc'),
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        largeIcon: const DrawableResourceAndroidBitmap(
          'ic_launcher_foreground',
        ),
        number: 0,
        channelShowBadge: false,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      ),
    );

    final now = DateTime.now();
    for (var day = 1; day <= _kInactiveScheduleDays; day++) {
      final variant = day.isOdd ? 1 : 2;
      final content = _contentFor(l10n, kind, variant);
      final payload = jsonEncode({'source': 'local', 'type': kind.payloadType});
      final delay = _reminderDelay(day);
      await _plugin.zonedSchedule(
        id: _kInactiveBaseId + day - 1,
        title: content.title,
        body: content.body,
        scheduledDate: tz.TZDateTime.from(now.add(delay), tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      if (kDebugMode) {
        debugPrint(
          'LOCAL NOTIF: scheduled ${kind.payloadType} #$day after $delay',
        );
      }
    }
  }

  Duration _reminderDelay(int day) {
    if (kDebugMode && _kTestReminderMinutes > 0) {
      return Duration(minutes: _kTestReminderMinutes * day);
    }
    return Duration(hours: 24 * day);
  }

  ({String title, String body}) _contentFor(
    AppLocalizations l10n,
    _InactiveReminderKind kind,
    int variant,
  ) {
    final prefix = kind == _InactiveReminderKind.authenticated
        ? 'notifications.inactive_user'
        : 'notifications.inactive_guest';
    return (
      title: l10n.t('$prefix.title_$variant'),
      body: l10n.t('$prefix.body_$variant'),
    );
  }
}

enum _InactiveReminderKind {
  neverLoggedIn('local_never_logged_in'),
  authenticated('local_authenticated_inactive');

  const _InactiveReminderKind(this.payloadType);

  final String payloadType;
}
