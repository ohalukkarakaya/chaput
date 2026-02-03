import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device/device_id_service.dart';
import '../data/notification_api_provider.dart';

final pushTokenRegistrarProvider = Provider<PushTokenRegistrar>((ref) {
  return PushTokenRegistrar(ref);
});

class PushTokenRegistrar {
  PushTokenRegistrar(this._ref);

  final Ref _ref;
  bool _listening = false;
  bool _retrying = false;

  Future<void> registerOnce() async {
    final messaging = FirebaseMessaging.instance;
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
    if (token == null || token.isEmpty) return;
    final deviceId = await _ref.read(deviceIdServiceProvider).getOrCreate();
    await _ref.read(notificationApiProvider).upsertPushToken(
      token: token,
      platform: Platform.isIOS ? 'IOS' : 'ANDROID',
      deviceId: deviceId,
    );
    _listenRefresh(messaging, deviceId);
  }

  void _retryLater() {
    if (_retrying) return;
    _retrying = true;
    Future.delayed(const Duration(seconds: 2), () {
      _retrying = false;
      registerOnce();
    });
  }

  void _listenRefresh(FirebaseMessaging messaging, String deviceId) {
    if (_listening) return;
    _listening = true;
    messaging.onTokenRefresh.listen((token) async {
      if (token.isEmpty) return;
      await _ref.read(notificationApiProvider).upsertPushToken(
        token: token,
        platform: Platform.isIOS ? 'IOS' : 'ANDROID',
        deviceId: deviceId,
      );
    });
  }
}
