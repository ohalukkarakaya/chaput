import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../chaput/data/chaput_socket.dart';
import '../../../core/deep_links/deep_link_state.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/secure_storage_provider.dart';
import '../../me/application/me_controller.dart';
import '../data/notification_api_provider.dart';
import 'local_notification_service.dart';
import 'notification_badge_service.dart';
import 'notification_count_controller.dart';

class NotificationLifecycleListener extends ConsumerStatefulWidget {
  const NotificationLifecycleListener({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<NotificationLifecycleListener> createState() =>
      _NotificationLifecycleListenerState();
}

class _NotificationLifecycleListenerState
    extends ConsumerState<NotificationLifecycleListener>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _localTapSub;
  StreamSubscription<RemoteMessage>? _remoteTapSub;
  bool _scheduledForBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  Future<void> _boot() async {
    await _handleAppOpened();
    _localTapSub = LocalNotificationService.instance.payloads.listen(
      (payload) => _handleLocalPayload(payload, initial: false),
    );
    final launchPayload = LocalNotificationService.instance.takeLaunchPayload();
    if (launchPayload != null && launchPayload.isNotEmpty) {
      _handleLocalPayload(launchPayload, initial: true);
    }
    try {
      final initialRemote = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialRemote != null) {
        _handleRemoteMessage(initialRemote, initial: true);
      }
      _remoteTapSub = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _handleRemoteMessage(message, initial: false),
      );
    } catch (_) {
      // Firebase may be unavailable on unsupported platforms; notification taps are best-effort.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduledForBackground = false;
      unawaited(_resumeRealtimeConnection());
      unawaited(_handleAppOpened());
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _pauseRealtimeConnection();
      if (_scheduledForBackground) return;
      _scheduledForBackground = true;
      unawaited(_scheduleForBackground());
    }
  }

  void _pauseRealtimeConnection() {
    try {
      ref.read(chaputSocketProvider).suspendForBackground();
    } catch (_) {
      // The realtime connection is best-effort while the app is backgrounded.
    }
  }

  Future<void> _resumeRealtimeConnection() async {
    try {
      final hasValidatedSession =
          ref.read(meControllerProvider).valueOrNull != null;
      if (!hasValidatedSession) return;
      await ref.read(chaputSocketProvider).resumeFromBackground();
    } catch (_) {
      // Reconnect failures are handled by the socket's normal retry path.
    }
  }

  Future<void> _handleAppOpened() async {
    await LocalNotificationService.instance.cancelInactivityReminders();
    await NotificationBadgeService.resetAppIconBadge();
    _resetInAppNotificationCount();

    try {
      final hasValidatedSession =
          ref.read(meControllerProvider).valueOrNull != null;
      if (hasValidatedSession) {
        await ref
            .read(notificationApiProvider)
            .resetBadge(allowUnauthorized: true);
        _resetInAppNotificationCount();
      }
    } catch (_) {
      // Badge reset is best-effort and should not interfere with startup.
    }
  }

  void _resetInAppNotificationCount() {
    try {
      ref.read(notificationCountControllerProvider.notifier).resetToZero();
    } catch (_) {
      // Count state may be unavailable during very early startup.
    }
  }

  Future<void> _scheduleForBackground() async {
    try {
      final storage = ref.read(tokenStorageProvider);
      final refresh = await storage.readRefreshToken();
      final hasActiveSession = refresh != null && refresh.isNotEmpty;
      final hasAuthenticatedBefore = await storage.hasAuthenticatedBefore();
      await LocalNotificationService.instance.scheduleInactivityReminders(
        hasActiveSession: hasActiveSession,
        hasAuthenticatedBefore: hasAuthenticatedBefore,
      );
    } catch (_) {
      // Local reminders are non-critical.
    }
  }

  void _handleLocalPayload(String payload, {required bool initial}) {
    Map<String, dynamic> data;
    try {
      final parsed = jsonDecode(payload);
      if (parsed is! Map) return;
      data = parsed.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      return;
    }

    final type = data['type']?.toString() ?? '';
    final target = switch (type) {
      'local_never_logged_in' => const DeepLinkTarget(
        location: Routes.onboarding,
      ),
      'local_authenticated_inactive' => const DeepLinkTarget(
        location: Routes.home,
      ),
      _ => null,
    };
    if (target == null) return;
    unawaited(_openTarget(target, initial: initial));
  }

  void _handleRemoteMessage(RemoteMessage message, {required bool initial}) {
    final target = _targetFromRemoteData(message.data);
    if (target == null) return;
    unawaited(_openTarget(target, initial: initial));
  }

  DeepLinkTarget? _targetFromRemoteData(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final userId = data['user_id']?.toString() ?? '';
    final actorId = data['actor_id']?.toString() ?? '';
    final threadId = data['thread_id']?.toString() ?? '';
    final messageId = data['message_id']?.toString() ?? '';

    if (type == 'chaput_started' ||
        type == 'chaput_message' ||
        type == 'chaput_revive' ||
        type == 'chaput_message_like') {
      if (userId.isEmpty) return const DeepLinkTarget(location: Routes.home);
      return DeepLinkTarget(
        location: Routes.profilePath(userId),
        extra: {
          if (threadId.isNotEmpty) 'threadId': threadId,
          if (messageId.isNotEmpty) 'messageId': messageId,
        },
      );
    }

    if (type == 'followed' ||
        type == 'follow_request' ||
        type == 'follow_approved') {
      if (actorId.isEmpty) {
        return const DeepLinkTarget(location: Routes.notifications);
      }
      return DeepLinkTarget(location: Routes.profilePath(actorId));
    }

    if (type == 'admin_gift_granted') {
      return const DeepLinkTarget(location: Routes.notifications);
    }

    return null;
  }

  Future<void> _openTarget(
    DeepLinkTarget target, {
    required bool initial,
  }) async {
    if (!await _canOpenTarget(target)) {
      if (!initial) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.router.go(Routes.onboarding);
        });
      }
      return;
    }

    if (initial) {
      ref.read(pendingDeepLinkProvider.notifier).state = target;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.router.go(target.location, extra: target.extra);
    });
  }

  Future<bool> _canOpenTarget(DeepLinkTarget target) async {
    if (!chaputDeepLinkTargetRequiresAuth(target)) return true;
    final refresh = await ref.read(tokenStorageProvider).readRefreshToken();
    final canOpen = refresh != null && refresh.isNotEmpty;
    if (!canOpen) {
      ref.read(pendingDeepLinkProvider.notifier).state = null;
    }
    return canOpen;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localTapSub?.cancel();
    _remoteTapSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
