import 'dart:async';

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
import 'app.dart';
import 'core/attribution/chaput_attribution_service.dart';
import 'features/feedback/presentation/widgets/chaput_feedback_form.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final enableNotifications =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

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
    // Do not wait on a platform channel before the first frame. If an OEM
    // channel stalls, the native launch screen must still hand over to Flutter.
    unawaited(
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
    );

    if (enableNotifications) {
      unawaited(_initializePostLaunchServices());
    }

    // Tree bytes are small and loading them here does not block the first
    // frame. This keeps the first profile/onboarding tree off the disk path.
    unawaited(TreeModelCache.instance.warmUpAll());
  });
}

Future<void> _initializePostLaunchServices() async {
  try {
    // Firebase and notification plumbing are intentionally initialized after
    // the first frame. A slow or unavailable service must never keep the
    // native splash screen on-screen or block boot authentication.
    await Firebase.initializeApp().timeout(const Duration(seconds: 4));
    await ChaputAttributionService.enableAnalyticsForIos();
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );
    FirebaseMessaging.onMessage.listen((_) {});
    await LocalNotificationService.instance.init();
  } catch (error) {
    debugPrint('Post-launch service initialization failed: $error');
  }
}
