import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatConfig {
  const RevenueCatConfig._();

  static const apiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: '',
  );

  static const iosApiKey = String.fromEnvironment(
    'REVENUECAT_IOS_API_KEY',
    defaultValue: apiKey,
  );

  static const androidApiKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_API_KEY',
    defaultValue: apiKey,
  );

  static const chaputSubscriptionEntitlement = String.fromEnvironment(
    'REVENUECAT_ENTITLEMENT_ID',
    defaultValue: 'chaput_subscription',
  );

  static String apiKeyForPlatform(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.iOS => iosApiKey,
      TargetPlatform.android => androidApiKey,
      _ => apiKey,
    };
  }

  static bool isApiKeyUsable(String apiKey) {
    return apiKey.trim().isNotEmpty;
  }
}

class RevenueCatProductIds {
  const RevenueCatProductIds._();

  static const plusMonthly = 'chaput_plus_month';
  static const proMonthly = 'chaput_pro_month';
  static const proYearly = 'chaput_pro_year';

  static const androidMonthlyBasePlan = 'monthly-autorenewing';
  static const androidYearlyBasePlan = 'yearly-autorenewing';
  static const androidPlusMonthly = '$plusMonthly:$androidMonthlyBasePlan';
  static const androidProMonthly = '$proMonthly:$androidMonthlyBasePlan';
  static const androidProYearly = '$proYearly:$androidYearlyBasePlan';

  static const bind1 = 'chaput_bind_1';
  static const bind5 = 'chaput_bind_5';
  static const bind20 = 'chaput_bind_20';

  static const hidden1 = 'chaput_hidden_1';
  static const hidden5 = 'chaput_hidden_5';
  static const hidden20 = 'chaput_hidden_20';

  static const special1 = 'chaput_special_1';
  static const special5 = 'chaput_special_5';
  static const special20 = 'chaput_special_20';

  static const whisper1 = 'chaput_whisper_1';
  static const whisper10 = 'chaput_whisper_10';
  static const whisper30 = 'chaput_whisper_30';

  static const revive1 = 'chaput_revive_1';

  static const subscriptions = <String>[plusMonthly, proMonthly, proYearly];

  static const consumables = <String>[
    bind1,
    bind5,
    bind20,
    hidden1,
    hidden5,
    hidden20,
    special1,
    special5,
    special20,
    whisper1,
    whisper10,
    whisper30,
    revive1,
  ];

  static const all = <String>[...subscriptions, ...consumables];

  static String logicalProductId(String productId) {
    return switch (productId) {
      androidPlusMonthly => plusMonthly,
      androidProMonthly => proMonthly,
      androidProYearly => proYearly,
      _ => productId,
    };
  }

  static String storeProductIdForPlatform(
    String productId,
    TargetPlatform platform,
  ) {
    final logicalId = logicalProductId(productId);
    if (platform != TargetPlatform.android) return logicalId;

    return switch (logicalId) {
      plusMonthly => androidPlusMonthly,
      proMonthly => androidProMonthly,
      proYearly => androidProYearly,
      _ => logicalId,
    };
  }

  static bool isSubscription(String productId) =>
      subscriptions.contains(logicalProductId(productId));

  static bool isConsumable(String productId) =>
      consumables.contains(logicalProductId(productId));

  static ProductCategory categoryFor(String productId) {
    return isConsumable(productId)
        ? ProductCategory.nonSubscription
        : ProductCategory.subscription;
  }
}
