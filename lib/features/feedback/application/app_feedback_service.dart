import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/dio_provider.dart';
import '../data/app_feedback_api.dart';

final appFeedbackApiProvider = Provider<AppFeedbackApi>((ref) {
  return AppFeedbackApi(ref.read(dioProvider));
});

final appFeedbackServiceProvider = Provider<AppFeedbackService>((ref) {
  return AppFeedbackService(ref.read(appFeedbackApiProvider));
});

class AppFeedbackService {
  AppFeedbackService(this._api);

  final AppFeedbackApi _api;

  Future<void> submit({
    required UserFeedback feedback,
    required String routePath,
    required Locale locale,
    required String triggerSource,
    required Map<String, dynamic> extras,
  }) async {
    final packageInfo = await _safePackageInfo();
    final deviceInfo = await _safeDeviceInfo();

    final payloadExtras = <String, dynamic>{
      ...?feedback.extra,
      ...extras,
      'trigger_source': triggerSource,
    };

    final formData = FormData.fromMap({
      'text': feedback.text.trim(),
      'route_path': routePath,
      'locale': locale.toLanguageTag(),
      'platform': _platformLabel(),
      if (packageInfo != null) 'app_version': packageInfo.version,
      if (packageInfo != null) 'build_number': packageInfo.buildNumber,
      if (deviceInfo.deviceModel != null)
        'device_model': deviceInfo.deviceModel,
      if (deviceInfo.osVersion != null) 'os_version': deviceInfo.osVersion,
      'trigger_source': triggerSource,
      if (payloadExtras.isNotEmpty) 'extra_json': jsonEncode(payloadExtras),
      'screenshot': MultipartFile.fromBytes(
        feedback.screenshot,
        filename: 'feedback.png',
      ),
    });

    await _api.submit(formData);
  }

  Future<PackageInfo?> _safePackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      return null;
    }
  }

  Future<_DeviceContext> _safeDeviceInfo() async {
    try {
      if (kIsWeb) {
        return const _DeviceContext(deviceModel: 'Web', osVersion: null);
      }
      final plugin = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return _DeviceContext(
          deviceModel: '${info.name} ${info.model}'.trim(),
          osVersion: '${info.systemName} ${info.systemVersion}'.trim(),
        );
      }
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return _DeviceContext(
          deviceModel: '${info.manufacturer} ${info.model}'.trim(),
          osVersion: 'Android ${info.version.release}'.trim(),
        );
      }
      return const _DeviceContext(deviceModel: null, osVersion: null);
    } catch (_) {
      return const _DeviceContext(deviceModel: null, osVersion: null);
    }
  }

  String _platformLabel() {
    if (kIsWeb) return 'WEB';
    if (Platform.isIOS) return 'IOS';
    if (Platform.isAndroid) return 'ANDROID';
    return defaultTargetPlatform.name.toUpperCase();
  }
}

class _DeviceContext {
  const _DeviceContext({required this.deviceModel, required this.osVersion});

  final String? deviceModel;
  final String? osVersion;
}
