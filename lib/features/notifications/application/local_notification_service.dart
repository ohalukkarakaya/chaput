import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/i18n/app_localizations.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static const _kMissYouId = 9001;
  static const _kLastOpenKey = 'last_open_at';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(settings: settings);
    _inited = true;
  }

  Future<void> scheduleMissYou() async {
    await init();
    await _plugin.cancel(id: _kMissYouId);
    final now = DateTime.now();
    await _storage.write(key: _kLastOpenKey, value: now.millisecondsSinceEpoch.toString());
    final scheduled = now.add(const Duration(hours: 24));
    final l10n = await AppLocalizations.load(PlatformDispatcher.instance.locale);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'chaput_local',
        l10n.t('notifications.local_channel_name'),
        channelDescription: l10n.t('notifications.local_channel_desc'),
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    await _plugin.zonedSchedule(
      id: _kMissYouId,
      title: l10n.t('notifications.miss_you_title'),
      body: l10n.t('notifications.miss_you_body'),
      scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
