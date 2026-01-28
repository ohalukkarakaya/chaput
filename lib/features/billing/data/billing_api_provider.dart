import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'billing_api.dart';

final billingApiProvider = Provider<BillingApi>((ref) {
  final dio = ref.watch(dioProvider);
  return BillingApi(dio);
});
