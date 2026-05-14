import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'revenue_cat_service.dart';

final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  return RevenueCatService.instance;
});

final revenueCatCustomerInfoProvider = StreamProvider<CustomerInfo>((
  ref,
) async* {
  final service = ref.watch(revenueCatServiceProvider);
  final latest = service.latestCustomerInfo;
  if (latest != null) {
    yield latest;
  }
  yield* service.customerInfoUpdates;
});

final revenueCatChaputSubscriptionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(revenueCatServiceProvider);
  final result = await service.hasChaputSubscription();
  return result.isSuccess && result.data == true;
});
