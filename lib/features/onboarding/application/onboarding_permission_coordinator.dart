import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/ui/widgets/chaput_action_prompt_sheet.dart';
import '../../notifications/application/local_notification_service.dart';

class OnboardingPermissionCoordinator {
  OnboardingPermissionCoordinator._();

  static bool _running = false;
  static bool _evaluatedThisSession = false;

  static Future<void> requestWhenOnboardingIsVisible(
    BuildContext context,
  ) async {
    if (_running || _evaluatedThisSession || !context.mounted) return;
    _running = true;

    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 4));
      if (!context.mounted) return;
      await _requestNotificationsIfNeeded(context);
      _evaluatedThisSession = true;
    } catch (_) {
    } finally {
      _running = false;
    }
  }

  static Future<void> _requestNotificationsIfNeeded(
    BuildContext context,
  ) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;

    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.notDetermined ||
        !context.mounted) {
      return;
    }

    final accepted = await showChaputActionPromptSheet(
      context,
      title: context.t('permissions.notifications_title'),
      body: context.t('permissions.notifications_body'),
      confirmLabel: context.t('permissions.notifications_confirm'),
      cancelLabel: context.t('permissions.not_now'),
    );
    if (!accepted) return;

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (Platform.isAndroid) {
      await LocalNotificationService.instance.requestPermissions();
    }
  }
}
