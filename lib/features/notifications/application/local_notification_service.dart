import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'chaput_local',
        'Local',
        channelDescription: 'Local reminders',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.zonedSchedule(
      id: _kMissYouId,
      title: 'Seni özledik',
      body: 'Chaput seni özledi, geri gel!',
      scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
