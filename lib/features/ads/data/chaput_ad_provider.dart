import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../../../core/config/env.dart';

enum ChaputAdNetwork { levelPlay }

extension ChaputAdNetworkWireValue on ChaputAdNetwork {
  String get wireValue => 'LEVELPLAY';
}

/// LevelPlay is the sole ad SDK used by Chaput. A missing or unavailable
/// placement deliberately resolves to no network so the reward flow can use
/// its unavailable-ad credit path without asking a secondary SDK for an ad.
class ChaputAdProvider {
  static Future<void>? _levelPlayInitialization;
  static Completer<bool>? _levelPlayReadiness;
  static bool _levelPlayReady = false;

  static String get _appKey =>
      Platform.isIOS ? Env.iosLevelPlayAppKey : Env.androidLevelPlayAppKey;

  static String get rewardedAdUnitId => Platform.isIOS
      ? Env.iosLevelPlayRewardedAdUnitId
      : Env.androidLevelPlayRewardedAdUnitId;

  static String get nativePlacementName => Platform.isIOS
      ? Env.iosLevelPlayNativePlacementName
      : Env.androidLevelPlayNativePlacementName;

  static bool get isRewardedConfigured =>
      (Platform.isIOS || Platform.isAndroid) &&
      _appKey.trim().isNotEmpty &&
      rewardedAdUnitId.trim().isNotEmpty;

  static bool get isLevelPlayConfigured =>
      (Platform.isIOS || Platform.isAndroid) && _appKey.trim().isNotEmpty;

  /// Native ads use the LevelPlay app key and the dashboard's default
  /// placement when no explicit placement name is configured.
  static bool get supportsNativeAds => isLevelPlayConfigured;

  static Future<void> initialize() async {
    if (!isLevelPlayConfigured) return;
    await _initializeLevelPlay();
  }

  /// Waits for shared SDK initialization without requiring a rewarded
  /// placement. Native placements are independent of rewarded inventory.
  static Future<bool> ensureLevelPlayReady() async {
    if (!isLevelPlayConfigured) return false;

    await _initializeLevelPlay();
    final readiness = _levelPlayReadiness;
    if (readiness == null) return false;

    return readiness.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () => false,
    );
  }

  static Future<ChaputAdNetwork?> resolveNetwork() async {
    if (!isRewardedConfigured) return null;

    final ready = await ensureLevelPlayReady();
    return ready && _levelPlayReady ? ChaputAdNetwork.levelPlay : null;
  }

  static Future<void> _initializeLevelPlay() {
    _levelPlayReadiness ??= Completer<bool>();
    return _levelPlayInitialization ??= _startLevelPlay();
  }

  static Future<void> _startLevelPlay() async {
    try {
      await LevelPlay.setAdaptersDebug(kDebugMode);
      await LevelPlay.init(
        initRequest: LevelPlayInitRequest(appKey: _appKey),
        initListener: _ChaputLevelPlayInitListener(),
      );
    } catch (_) {
      _markLevelPlayUnavailable();
    }
  }

  static void _markLevelPlayReady() {
    _levelPlayReady = true;
    final readiness = _levelPlayReadiness ??= Completer<bool>();
    if (!readiness.isCompleted) {
      readiness.complete(true);
    }
  }

  static void _markLevelPlayUnavailable() {
    _levelPlayReady = false;
    final readiness = _levelPlayReadiness ??= Completer<bool>();
    if (!readiness.isCompleted) {
      readiness.complete(false);
    }
  }
}

class _ChaputLevelPlayInitListener implements LevelPlayInitListener {
  @override
  void onInitFailed(LevelPlayInitError error) {
    ChaputAdProvider._markLevelPlayUnavailable();
  }

  @override
  void onInitSuccess(LevelPlayConfiguration configuration) {
    ChaputAdProvider._markLevelPlayReady();
  }
}
