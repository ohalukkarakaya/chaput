import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:upgrader/upgrader.dart';

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

class AppUpdateSnapshot {
  const AppUpdateSnapshot._({
    required this.updateRequired,
    required this.storePublished,
    this.storeUrl,
    this.storeVersion,
    this.storeName,
  });

  const AppUpdateSnapshot.none({
    bool storePublished = false,
    String? storeUrl,
    String? storeVersion,
    String? storeName,
  }) : this._(
         updateRequired: false,
         storePublished: storePublished,
         storeUrl: storeUrl,
         storeVersion: storeVersion,
         storeName: storeName,
       );

  const AppUpdateSnapshot.required({
    required String storeUrl,
    required String storeVersion,
    required String storeName,
  }) : this._(
         updateRequired: true,
         storePublished: true,
         storeUrl: storeUrl,
         storeVersion: storeVersion,
         storeName: storeName,
       );

  final bool updateRequired;
  final bool storePublished;
  final String? storeUrl;
  final String? storeVersion;
  final String? storeName;
}

class AppUpdateService {
  AppUpdateService({Upgrader? upgrader})
    : _upgrader =
          upgrader ??
          Upgrader(debugLogging: false, durationUntilAlertAgain: Duration.zero);

  static const _cacheDuration = Duration(hours: 4);

  final Upgrader _upgrader;
  DateTime? _lastCheckedAt;
  AppUpdateSnapshot _cached = const AppUpdateSnapshot.none();

  Future<AppUpdateSnapshot> checkForUpdate({bool force = false}) async {
    if (kDebugMode) {
      _cached = const AppUpdateSnapshot.none();
      _lastCheckedAt = DateTime.now();
      return _cached;
    }

    final now = DateTime.now();
    if (!force &&
        _lastCheckedAt != null &&
        now.difference(_lastCheckedAt!) < _cacheDuration) {
      return _cached;
    }

    try {
      await _upgrader.initialize();
      await _upgrader.updateVersionInfo();

      final listingUrl = _upgrader.currentAppStoreListingURL;
      final storeVersion = _upgrader.currentAppStoreVersion;
      final hasPublishedListing =
          listingUrl != null &&
          listingUrl.isNotEmpty &&
          storeVersion != null &&
          storeVersion.isNotEmpty;

      if (hasPublishedListing && _upgrader.isUpdateAvailable()) {
        _cached = AppUpdateSnapshot.required(
          storeUrl: listingUrl,
          storeVersion: storeVersion,
          storeName: switch (defaultTargetPlatform) {
            TargetPlatform.iOS => 'App Store',
            TargetPlatform.android => 'Google Play',
            _ => 'store',
          },
        );
      } else {
        _cached = AppUpdateSnapshot.none(
          storePublished: hasPublishedListing,
          storeUrl: hasPublishedListing ? listingUrl : null,
          storeVersion: hasPublishedListing ? storeVersion : null,
          storeName: hasPublishedListing
              ? switch (defaultTargetPlatform) {
                  TargetPlatform.iOS => 'App Store',
                  TargetPlatform.android => 'Google Play',
                  _ => 'store',
                }
              : null,
        );
      }
    } catch (_) {
      _cached = const AppUpdateSnapshot.none();
    }

    _lastCheckedAt = now;
    return _cached;
  }

  Future<void> openStore() async {
    try {
      await _upgrader.sendUserToAppStore();
    } catch (_) {}
  }
}
