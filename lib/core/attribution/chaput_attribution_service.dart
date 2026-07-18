import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/dio_provider.dart';

final chaputAttributionServiceProvider = Provider<ChaputAttributionService>(
      (ref) => ChaputAttributionService(ref.watch(dioProvider)),
);

class ChaputVerifiedPurchaseEvent {
  const ChaputVerifiedPurchaseEvent({
    required this.transactionId,
    required this.productId,
    required this.currency,
    required this.value,
  });

  final String? transactionId;
  final String? productId;
  final String? currency;
  final double? value;
}

/// Isolates attribution and analytics failures so they cannot affect user flows.
class ChaputAttributionService {
  ChaputAttributionService(this._dio);

  static const _channel = MethodChannel('chaput/attribution');
  static const _storage = FlutterSecureStorage();
  static const _purchaseReportKeyPrefix = 'attribution_purchase_reported_';

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final Set<String> _reportedPurchaseTransactionIds = <String>{};

  static bool _appleSearchAdsSubmitted = false;

  final Dio _dio;

  /// Firebase Analytics is already initialized by the existing Firebase setup.
  /// Explicitly enable only the iOS collector so its first-open/session events
  /// are not accidentally disabled by an environment-specific plist flag.
  static Future<void> enableAnalyticsForIos() async {
    if (!Platform.isIOS) return;

    try {
      await _analytics.setAnalyticsCollectionEnabled(true);
    } catch (_) {
      // Analytics availability must not block launch.
    }
  }

  Future<void> activateAfterAuthentication() async {
    if (!Platform.isIOS || _appleSearchAdsSubmitted) return;

    // ATT is requested, but its result does not block AdServices attribution.
    await _requestTrackingAuthorization();

    final token = await _appleSearchAdsToken();
    if (token == null || token.isEmpty) return;

    _appleSearchAdsSubmitted = await _submitAppleSearchAdsToken(token);
  }

  Future<void> recordLogin() async {
    await _recordSuccessfulEvent('login');
    unawaited(activateAfterAuthentication());
  }

  Future<void> recordSignUp() async {
    await _recordSuccessfulEvent('signup');
    unawaited(activateAfterAuthentication());
  }

  static Future<void> recordVerifiedPurchase(
      ChaputVerifiedPurchaseEvent purchase,
      ) async {
    final transactionId = _normalizedString(purchase.transactionId);
    final productId = _normalizedString(purchase.productId);

    if (transactionId == null || productId == null) return;
    if (!await _markPurchaseTransactionForReporting(transactionId)) return;

    final currency = _normalizedString(purchase.currency);
    final value = currency == null ? null : purchase.value;

    // Firebase purchase analytics runs on both iOS and Android.
    try {
      await _analytics.logPurchase(
        transactionId: transactionId,
        currency: currency,
        value: value,
        items: <AnalyticsEventItem>[
          AnalyticsEventItem(
            itemId: productId,
            itemName: productId,
            price: value,
            quantity: 1,
          ),
        ],
      );
    } catch (_) {
      // Analytics must never alter billing completion.
    }

    // Meta and TikTok native tracking are currently implemented on iOS.
    if (Platform.isIOS) {
      try {
        await _channel.invokeMethod<void>('trackEvent', {
          'name': 'purchase',
          'transactionId': transactionId,
          'productId': productId,
          if (currency != null) 'currency': currency,
          if (value != null) 'value': value,
        });
      } catch (_) {
        // Attribution must never alter billing completion.
      }
    }
  }

  static Future<void> _recordSuccessfulEvent(String eventName) async {
    if (!Platform.isIOS) return;

    try {
      switch (eventName) {
        case 'login':
          await _analytics.logLogin(loginMethod: 'email');
          break;
        case 'signup':
          await _analytics.logSignUp(signUpMethod: 'email');
          break;
      }

      await _channel.invokeMethod<void>('trackEvent', {
        'name': eventName,
      });
    } catch (_) {
      // Attribution must never alter authentication or billing completion.
    }
  }

  static String? _normalizedString(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static Future<bool> _markPurchaseTransactionForReporting(
      String transactionId,
      ) async {
    if (_reportedPurchaseTransactionIds.contains(transactionId)) {
      return false;
    }

    final encodedTransactionId = base64Url.encode(
      utf8.encode(transactionId),
    );

    final storageKey = '$_purchaseReportKeyPrefix$encodedTransactionId';

    try {
      if (await _storage.read(key: storageKey) == '1') {
        _reportedPurchaseTransactionIds.add(transactionId);
        return false;
      }

      await _storage.write(
        key: storageKey,
        value: '1',
      );

      _reportedPurchaseTransactionIds.add(transactionId);
      return true;
    } catch (_) {
      return _reportedPurchaseTransactionIds.add(transactionId);
    }
  }

  Future<int?> _requestTrackingAuthorization() async {
    try {
      return await _channel.invokeMethod<int>(
        'requestTrackingAuthorization',
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _appleSearchAdsToken() async {
    try {
      return await _channel.invokeMethod<String>(
        'appleSearchAdsToken',
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _submitAppleSearchAdsToken(String token) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _dio.post<void>(
          '/me/attribution/apple-search-ads',
          data: {
            'token': token,
          },
        );

        return true;
      } on DioException catch (error) {
        if (error.response?.statusCode != 404 || attempt == 2) {
          return false;
        }

        await Future<void>.delayed(
          const Duration(seconds: 5),
        );
      } catch (_) {
        return false;
      }
    }

    return false;
  }
}