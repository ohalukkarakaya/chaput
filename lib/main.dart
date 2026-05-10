import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'features/notifications/application/local_notification_service.dart';
import 'features/profile/presentation/utils/tree_model_cache.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final enableNotifications = defaultTargetPlatform != TargetPlatform.android;

  if (enableNotifications) {
    await Firebase.initializeApp();
    await FirebaseMessaging.instance.requestPermission();
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
    FirebaseMessaging.onMessage.listen((_) {});
    await LocalNotificationService.instance.scheduleMissYou();
  }

  await MobileAds.instance.initialize();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const ProviderScope(child: ChaputApp()));

  WidgetsBinding.instance.addPostFrameCallback((_) {
    TreeModelCache.instance.warmUpAll();
  });
}
