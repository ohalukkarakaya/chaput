import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/logger.dart';
import '../application/app_feedback_service.dart';
import '../data/app_feedback_api.dart';

void showAppFeedbackSheet(
  BuildContext context,
  WidgetRef ref, {
  required String triggerSource,
  String? routePathOverride,
}) {
  final controller = BetterFeedback.of(context);
  if (controller.isVisible) return;

  final messenger = ScaffoldMessenger.maybeOf(context);
  final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');
  final routePath = _resolveRoutePath(context, routePathOverride);
  if (triggerSource == 'gesture' && _isGestureBlockedRoute(routePath)) {
    return;
  }
  final successText = context.t('feedback.submit_success');
  final failedText = context.t('feedback.submit_failed');
  final mediaQuery = MediaQuery.maybeOf(context);
  final feedbackService = ref.read(appFeedbackServiceProvider);

  controller.show((feedback) async {
    try {
      await feedbackService.submit(
        feedback: feedback,
        routePath: routePath,
        locale: locale,
        triggerSource: triggerSource,
        extras: {
          if (mediaQuery != null) 'screen_width': mediaQuery.size.width,
          if (mediaQuery != null) 'screen_height': mediaQuery.size.height,
          if (mediaQuery != null)
            'device_pixel_ratio': mediaQuery.devicePixelRatio,
          if (mediaQuery != null)
            'text_scale_factor': mediaQuery.textScaler.scale(1),
        },
      );

      controller.hide();

      await Future<void>.delayed(const Duration(milliseconds: 180));

      messenger?.showSnackBar(
        SnackBar(
          content: Text(successText),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, st) {
      Log.e(
        'Feedback UI submit failed on $routePath',
        tag: 'Feedback',
        error: e,
        st: st,
      );
      final failureMessage = switch (e) {
        AppFeedbackSubmitException() when Env.isTest =>
          '$failedText (${e.message})',
        _ => failedText,
      };
      messenger?.showSnackBar(
        SnackBar(
          content: Text(failureMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  });
}

String _resolveRoutePath(BuildContext context, String? routePathOverride) {
  if (routePathOverride != null && routePathOverride.trim().isNotEmpty) {
    return routePathOverride.trim();
  }

  final modalRoute = ModalRoute.of(context);
  final routeName = modalRoute?.settings.name;
  if (routeName != null && routeName.trim().isNotEmpty) {
    return routeName.trim();
  }

  return 'unknown';
}

bool _isGestureBlockedRoute(String routePath) {
  final uri = Uri.tryParse(routePath);
  final path = uri?.path ?? routePath;

  if (path == Routes.boot ||
      path == Routes.onboarding ||
      path == Routes.login ||
      path == Routes.register) {
    return true;
  }

  return path.startsWith('/profile/') ||
      path.startsWith('/u/') ||
      path.startsWith('/me/');
}
