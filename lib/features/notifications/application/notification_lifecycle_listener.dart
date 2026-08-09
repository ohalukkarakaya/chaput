import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../chaput/data/chaput_socket.dart';
import '../../../chaput/application/chaput_decision_controller.dart';
import '../../../core/app_availability/app_availability_controller.dart';
import '../../../core/deep_links/deep_link_state.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/secure_storage_provider.dart';
import '../../me/application/me_controller.dart';
import '../../profile/application/profile_visit_history_controller.dart';
import '../../profile/domain/profile_preview.dart';
import '../../recommended_users/application/recommended_user_controller.dart';
import '../../social/application/follow_relationship_override.dart';
import '../../user/application/profile_controller.dart';
import '../../user_search/application/user_search_controller.dart';
import '../data/notification_api_provider.dart';
import '../domain/notification_item.dart';
import 'local_notification_service.dart';
import 'notification_badge_service.dart';
import 'notification_count_controller.dart';
import 'notifications_controller.dart';

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

DeepLinkTarget? chaputNotificationTargetFromRemoteData(
  Map<String, dynamic> data,
) {
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

class _NotificationLifecycleListenerState
    extends ConsumerState<NotificationLifecycleListener>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _localTapSub;
  StreamSubscription<RemoteMessage>? _remoteTapSub;
  StreamSubscription<RemoteMessage>? _foregroundRemoteSub;
  StreamSubscription<ChaputSocketEvent>? _socketSub;
  bool _scheduledForBackground = false;
  bool _realtimeBootScheduled = false;
  bool _realtimeBooting = false;
  bool _globalSocketRetained = false;
  bool _remoteMessagingRetryScheduled = false;
  int _remoteMessagingRetryCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boot();
  }

  Future<void> _boot() async {
    await _handleAppOpened();
    _localTapSub ??= LocalNotificationService.instance.payloads.listen(
      _handleLocalPayload,
    );
    final launchPayload = LocalNotificationService.instance.takeLaunchPayload();
    if (launchPayload != null && launchPayload.isNotEmpty) {
      _handleLocalPayload(launchPayload);
    }
    try {
      final firebaseReady = await _ensureFirebaseMessagingReady();
      if (!firebaseReady) {
        _scheduleRemoteMessagingRetry();
        return;
      }
      final initialRemote = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialRemote != null) {
        _handleRemoteMessage(initialRemote);
      }
      _remoteTapSub = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleRemoteMessage,
      );
      _foregroundRemoteSub = FirebaseMessaging.onMessage.listen(
        _handleForegroundRemoteMessage,
      );
      _remoteMessagingRetryCount = 0;
    } catch (_) {
      // Firebase may be unavailable on unsupported platforms; notification taps are best-effort.
      _scheduleRemoteMessagingRetry();
    }
  }

  void _scheduleRemoteMessagingRetry() {
    if (_remoteMessagingRetryScheduled ||
        _remoteTapSub != null ||
        _foregroundRemoteSub != null ||
        _remoteMessagingRetryCount >= 3) {
      return;
    }
    _remoteMessagingRetryCount += 1;
    _remoteMessagingRetryScheduled = true;
    Future<void>.delayed(const Duration(seconds: 2), () {
      _remoteMessagingRetryScheduled = false;
      if (!mounted || _remoteTapSub != null || _foregroundRemoteSub != null) {
        return;
      }
      unawaited(_boot());
    });
  }

  Future<bool> _ensureFirebaseMessagingReady() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp().timeout(const Duration(seconds: 4));
      }
      return true;
    } catch (_) {
      return false;
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
      final hasValidatedSession = ref.read(meControllerProvider).value != null;
      if (!hasValidatedSession) return;
      await _ensureRealtimeSocket();
    } catch (_) {
      // Reconnect failures are handled by the socket's normal retry path.
    }
  }

  void _scheduleRealtimeSocket() {
    if (_realtimeBootScheduled || _realtimeBooting || _socketSub != null) {
      return;
    }
    _realtimeBootScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _realtimeBootScheduled = false;
      if (!mounted) return;
      unawaited(_ensureRealtimeSocket());
    });
  }

  Future<void> _ensureRealtimeSocket() async {
    if (_realtimeBooting || _socketSub != null) return;
    final hasValidatedSession = ref.read(meControllerProvider).value != null;
    if (!hasValidatedSession) return;

    _realtimeBooting = true;
    try {
      final client = ref.read(chaputSocketProvider);
      _socketSub ??= client.events.listen(
        _handleSocketEvent,
        onError: (_, _) {},
      );
      if (!_globalSocketRetained) {
        _globalSocketRetained = true;
        await client.retainGlobalConnection();
      } else {
        await client.resumeFromBackground();
      }
    } finally {
      _realtimeBooting = false;
    }
  }

  void _stopRealtimeSocket() {
    _realtimeBootScheduled = false;
    _socketSub?.cancel();
    _socketSub = null;
    if (!_globalSocketRetained) return;
    _globalSocketRetained = false;
    try {
      ref.read(chaputSocketProvider).releaseGlobalConnection();
    } catch (_) {
      // The socket may already be disposed during app shutdown.
    }
  }

  Future<void> _handleAppOpened() async {
    await LocalNotificationService.instance.cancelInactivityReminders();
    await NotificationBadgeService.resetAppIconBadge();
    try {
      await ref.read(appAvailabilityProvider.notifier).checkNow();
    } catch (_) {}

    try {
      final hasValidatedSession = ref.read(meControllerProvider).value != null;
      if (hasValidatedSession) {
        await ref
            .read(notificationApiProvider)
            .resetBadge(allowUnauthorized: true);
        if (ref.exists(notificationCountControllerProvider)) {
          ref
              .read(notificationCountControllerProvider.notifier)
              .updateFromSocket(0);
        }
      }
    } catch (_) {
      // Badge reset is best-effort and should not interfere with startup.
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

  void _handleLocalPayload(String payload) {
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
    unawaited(_openTarget(target));
  }

  void _handleRemoteMessage(RemoteMessage message) {
    final target = _targetFromRemoteData(message.data);
    if (target == null) return;
    unawaited(_openTarget(target));
  }

  void _handleForegroundRemoteMessage(RemoteMessage message) {
    if (ref.read(meControllerProvider).value == null) return;
    final data = message.data.map((key, value) => MapEntry(key, value));
    _handleNotificationSideEffects(data);
    final unread = _readInt(data['unread_count'] ?? data['badge']);
    if (unread != null) {
      ref
          .read(notificationCountControllerProvider.notifier)
          .updateFromSocket(unread);
    } else {
      unawaited(
        ref.read(notificationCountControllerProvider.notifier).refresh(),
      );
    }
  }

  void _handleSocketEvent(ChaputSocketEvent ev) {
    if (ev.type != 'notif.created') return;
    _handleNotificationCreated(ev.data);
  }

  void _handleNotificationCreated(Map<String, dynamic> data) {
    final notif = _notificationFromRealtimeData(data);
    final meId = ref.read(meControllerProvider).value?.user.userId ?? '';
    if (meId.isEmpty) return;
    if (notif == null || notif.userId.toLowerCase() != meId.toLowerCase()) {
      return;
    }

    if (ref.exists(notificationsControllerProvider)) {
      ref.read(notificationsControllerProvider.notifier).addFromSocket(notif);
      unawaited(
        ref
            .read(notificationsControllerProvider.notifier)
            .ensureActorLoaded(notif.actorId),
      );
    }

    final unread = _readInt(data['unread_count']);
    if (unread != null) {
      ref
          .read(notificationCountControllerProvider.notifier)
          .updateFromSocket(unread);
    } else {
      unawaited(
        ref.read(notificationCountControllerProvider.notifier).refresh(),
      );
    }
    _handleNotificationSideEffects(data, notification: notif);
  }

  AppNotification? _notificationFromRealtimeData(Map<String, dynamic> data) {
    final raw = data['notification'];
    if (raw is Map) {
      return AppNotification.fromJson(
        raw.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    if (data['id'] == null || data['user_id'] == null) return null;
    return AppNotification.fromJson(data);
  }

  void _handleNotificationSideEffects(
    Map<String, dynamic> data, {
    AppNotification? notification,
  }) {
    final type = notification?.type ?? data['type']?.toString() ?? '';
    if (type != 'follow_approved') return;

    final meId = ref.read(meControllerProvider).value?.user.userId ?? '';
    if (meId.isEmpty) return;
    final candidateIds =
        <String>{
          if ((notification?.actorId ?? '').isNotEmpty) notification!.actorId!,
          if ((notification?.profileId ?? '').isNotEmpty)
            notification!.profileId!,
          data['actor_id']?.toString() ?? '',
          data['profile_id']?.toString() ?? '',
          data['approved_by_user_id']?.toString() ?? '',
          data['approver_id']?.toString() ?? '',
        }..removeWhere(
          (id) => id.isEmpty || id.toLowerCase() == meId.toLowerCase(),
        );

    for (final id in candidateIds) {
      _applyFollowApprovedProfile(id);
    }
  }

  void _applyFollowApprovedProfile(String userId) {
    ref
        .read(followRelationshipOverridesProvider.notifier)
        .setForUser(userId: userId, isFollowing: true, requestPending: false);
    if (ref.exists(userSearchControllerProvider)) {
      ref
          .read(userSearchControllerProvider.notifier)
          .updateFollowState(
            userId: userId,
            isFollowing: true,
            requestPending: false,
          );
    }
    if (ref.exists(recommendedUserControllerProvider)) {
      ref
          .read(recommendedUserControllerProvider.notifier)
          .updateFollowState(
            userId: userId,
            isFollowing: true,
            requestPending: false,
          );
    }
    ref
        .read(profileVisitHistoryProvider.notifier)
        .updateFollowState(
          ProfilePreview(
            id: userId,
            username: null,
            fullName: '',
            defaultAvatar: '',
            profilePhotoKey: null,
            profilePhotoUrl: null,
            isPublic: false,
            isFollowing: true,
          ),
        );
    final providerKeys = <String>{userId, userId.toLowerCase()};
    for (final key in providerKeys) {
      if (ref.exists(profileControllerProvider(key))) {
        ref.invalidate(profileControllerProvider(key));
      }
      if (ref.exists(chaputDecisionControllerProvider(key))) {
        ref.invalidate(chaputDecisionControllerProvider(key));
      }
    }
  }

  int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  DeepLinkTarget? _targetFromRemoteData(Map<String, dynamic> data) {
    return chaputNotificationTargetFromRemoteData(data);
  }

  Future<void> _openTarget(DeepLinkTarget target) async {
    if (!chaputDeepLinkTargetRequiresAuth(target)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.router.go(target.location, extra: target.extra);
      });
      return;
    }

    ref.read(pendingDeepLinkProvider.notifier).state = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.router.go(Routes.boot);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localTapSub?.cancel();
    _remoteTapSub?.cancel();
    _foregroundRemoteSub?.cancel();
    _stopRealtimeSocket();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasValidatedSession = ref.watch(
      meControllerProvider.select((value) => value.value != null),
    );
    if (hasValidatedSession) {
      _scheduleRealtimeSocket();
    } else {
      _stopRealtimeSocket();
    }
    return widget.child;
  }
}
