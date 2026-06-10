import 'package:chaput/features/revenuecat/data/revenue_cat_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RevenueCatProductIds', () {
    test('keeps App Store subscription ids unchanged', () {
      expect(
        RevenueCatProductIds.storeProductIdForPlatform(
          RevenueCatProductIds.plusMonthly,
          TargetPlatform.iOS,
        ),
        RevenueCatProductIds.plusMonthly,
      );
      expect(
        RevenueCatProductIds.storeProductIdForPlatform(
          RevenueCatProductIds.proMonthly,
          TargetPlatform.iOS,
        ),
        RevenueCatProductIds.proMonthly,
      );
      expect(
        RevenueCatProductIds.storeProductIdForPlatform(
          RevenueCatProductIds.proYearly,
          TargetPlatform.iOS,
        ),
        RevenueCatProductIds.proYearly,
      );
    });

    test('maps Play Store subscriptions to RevenueCat base plan ids', () {
      expect(
        RevenueCatProductIds.storeProductIdForPlatform(
          RevenueCatProductIds.plusMonthly,
          TargetPlatform.android,
        ),
        'chaput_plus_month:monthly-autorenewing',
      );
      expect(
        RevenueCatProductIds.storeProductIdForPlatform(
          RevenueCatProductIds.proMonthly,
          TargetPlatform.android,
        ),
        'chaput_pro_month:monthly-autorenewing',
      );
      expect(
        RevenueCatProductIds.storeProductIdForPlatform(
          RevenueCatProductIds.proYearly,
          TargetPlatform.android,
        ),
        'chaput_pro_year:yearly-autorenewing',
      );
    });

    test('keeps consumable ids unchanged on both stores', () {
      for (final productId in RevenueCatProductIds.consumables) {
        expect(
          RevenueCatProductIds.storeProductIdForPlatform(
            productId,
            TargetPlatform.iOS,
          ),
          productId,
        );
        expect(
          RevenueCatProductIds.storeProductIdForPlatform(
            productId,
            TargetPlatform.android,
          ),
          productId,
        );
      }
    });

    test('normalizes Play Store subscription ids back to logical ids', () {
      expect(
        RevenueCatProductIds.logicalProductId(
          'chaput_plus_month:monthly-autorenewing',
        ),
        RevenueCatProductIds.plusMonthly,
      );
      expect(
        RevenueCatProductIds.logicalProductId(
          'chaput_pro_month:monthly-autorenewing',
        ),
        RevenueCatProductIds.proMonthly,
      );
      expect(
        RevenueCatProductIds.logicalProductId(
          'chaput_pro_year:yearly-autorenewing',
        ),
        RevenueCatProductIds.proYearly,
      );
    });
  });
}
