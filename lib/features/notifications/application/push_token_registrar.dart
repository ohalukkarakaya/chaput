import 'dart:io';
import 'dart:async';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/device/device_id_service.dart';
import '../../../core/storage/secure_storage_provider.dart';
import '../data/notification_api_provider.dart';
import 'firebase_token_cleanup.dart';

final pushTokenRegistrarProvider = Provider<PushTokenRegistrar>((ref) {
  return PushTokenRegistrar(ref);
});

class PushTokenRegistrar {
  PushTokenRegistrar(this._ref);

  final Ref _ref;
  StreamSubscription<String>? _refreshSub;
  bool _retrying = false;

  Future<void> registerOnce() async {
    if (!await _hasActiveSession()) return;

    final messaging = FirebaseMessaging.instance;
    try {
      final settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
    } catch (_) {
      // Some platforms may not expose notification settings consistently.
    }
    try {
      if (Platform.isIOS) {
        final apns = await messaging.getAPNSToken();
        if (apns == null || apns.isEmpty) {
          _retryLater();
          return;
        }
      }
    } catch (_) {
      _retryLater();
      return;
    }

    String? token;
    try {
      token = await messaging.getToken();
    } catch (_) {
      _retryLater();
      return;
    }
    if (token == null || token.isEmpty) {
      _retryLater();
      return;
    }
    final deviceId = await _ref.read(deviceIdServiceProvider).getOrCreate();
    try {
      await _ref
          .read(notificationApiProvider)
          .upsertPushToken(
            token: token,
            platform: Platform.isIOS ? 'IOS' : 'ANDROID',
            deviceId: deviceId,
            locale: _resolvedLocaleCode(),
          );
    } catch (_) {
      _retryLater();
      return;
    }
    _listenRefresh(messaging, deviceId);
  }

  Future<void> unregisterCurrentDevice({bool serverSide = true}) async {
    final messaging = FirebaseMessaging.instance;
    final deviceId = await _ref.read(deviceIdServiceProvider).getOrCreate();
    String? token;

    await _refreshSub?.cancel();
    _refreshSub = null;
    _retrying = false;

    try {
      token = await messaging.getToken();
    } catch (_) {
      token = null;
    }

    if (serverSide && await _hasActiveSession()) {
      try {
        await _ref
            .read(notificationApiProvider)
            .deletePushToken(token: token, deviceId: deviceId);
      } catch (_) {
        // Server-side unregister is best-effort; local token deletion follows.
      }
    }

    await FirebaseTokenCleanup.deleteLocalMessagingToken();
  }

  void _retryLater() {
    if (_retrying) return;
    _retrying = true;
    Future.delayed(const Duration(seconds: 2), () {
      _retrying = false;
      unawaited(registerOnce());
    });
  }

  void _listenRefresh(FirebaseMessaging messaging, String deviceId) {
    if (_refreshSub != null) return;
    _refreshSub = messaging.onTokenRefresh.listen((token) async {
      if (token.isEmpty) return;
      if (!await _hasActiveSession()) return;
      try {
        await _ref
            .read(notificationApiProvider)
            .upsertPushToken(
              token: token,
              platform: Platform.isIOS ? 'IOS' : 'ANDROID',
              deviceId: deviceId,
              locale: _resolvedLocaleCode(),
            );
      } catch (_) {
        _retryLater();
      }
    });
  }

  Future<bool> _hasActiveSession() async {
    final refresh = await _ref.read(tokenStorageProvider).readRefreshToken();
    return refresh != null && refresh.isNotEmpty;
  }

  String _resolvedLocaleCode() {
    return AppLocalizations.resolve(
      PlatformDispatcher.instance.locale,
    ).languageCode;
  }
}
