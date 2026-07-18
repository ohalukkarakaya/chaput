import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_colors.dart';
import 'core/i18n/app_localizations.dart';
import 'features/notifications/application/local_notification_service.dart';
import 'features/profile/presentation/utils/tree_model_cache.dart';
import 'features/ads/data/chaput_ad_provider.dart';
import 'app.dart';
import 'core/attribution/chaput_attribution_service.dart';
import 'features/feedback/presentation/widgets/chaput_feedback_form.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final enableNotifications =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  if (enableNotifications) {
    await Firebase.initializeApp();
    await ChaputAttributionService.enableAnalyticsForIos();
    await FirebaseMessaging.instance.requestPermission();
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );
    FirebaseMessaging.onMessage.listen((_) {});
    await LocalNotificationService.instance.init();
    await LocalNotificationService.instance.requestPermissions();
  }

  await ChaputAdProvider.initialize();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(
    ProviderScope(
      child: BetterFeedback(
        feedbackBuilder: chaputFeedbackBuilder,
        localizationsDelegates: [
          const AppLocalizationsDelegate(),
          GlobalFeedbackLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: FeedbackThemeData(
          background: Colors.black.withValues(alpha: 0.58),
          feedbackSheetHeight: 0.38,
          feedbackSheetColor: AppColors.chaputWhite,
          activeFeedbackModeColor: AppColors.chaputBlack,
          dragHandleColor: Colors.black26,
          drawColors: const [
            AppColors.chaputErrorRed,
            AppColors.chaputGolden,
            AppColors.chaputRoyalBlue,
          ],
          bottomSheetDescriptionStyle: const TextStyle(
            color: AppColors.chaputBlack87,
            fontWeight: FontWeight.w600,
          ),
          bottomSheetTextInputStyle: const TextStyle(
            color: AppColors.chaputBlack87,
            fontWeight: FontWeight.w600,
            fontSize: 17,
            height: 1.4,
          ),
        ),
        child: const ChaputApp(),
      ),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    TreeModelCache.instance.warmUpAll();
  });
}
