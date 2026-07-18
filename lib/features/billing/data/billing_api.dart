import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../../../core/attribution/chaput_attribution_service.dart';
import '../domain/billing_verify_result.dart';

class BillingApi {
  BillingApi(this._dio);

  final Dio _dio;

  Future<BillingVerifyResult> verifyPurchase({
    required String provider,
    required String productId,
    required String transactionId,
    String? receiptData,
    String? purchaseToken,
    String? devToken,
  }) async {
    final payload = <String, dynamic>{
      'provider': provider,
      'product_id': productId,
      'transaction_id': transactionId,
    };
    if (receiptData != null && receiptData.isNotEmpty) {
      payload['receipt_data'] = receiptData;
    }
    if (purchaseToken != null && purchaseToken.isNotEmpty) {
      payload['purchase_token'] = purchaseToken;
    }
    if (devToken != null && devToken.isNotEmpty) {
      payload['dev_token'] = devToken;
    }

    Response<dynamic> res;
    try {
      res = await _dio.post('/billing/purchase/verify', data: payload);
    } on DioException catch (e, st) {
      final data = e.response?.data;
      final safeError = data is Map
          ? data['error']?.toString()
          : data?.toString();
      developer.log(
        'billing verify failed status=${e.response?.statusCode} provider=$provider product=$productId error=$safeError',
        name: 'ChaputBilling',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
    final data = res.data;
    if (data is Map<String, dynamic>) {
      if (data['ok'] == true) {
        final result = BillingVerifyResult.fromJson(data);
        unawaited(
          ChaputAttributionService.recordVerifiedPurchase(
            ChaputVerifiedPurchaseEvent(
              transactionId: result.transactionId,
              productId: result.productId,
              currency: result.currency,
              value: result.value,
            ),
          ),
        );
        return result;
      }
      throw Exception(data['error'] ?? 'verify_failed');
    }
    throw Exception('bad_verify_response');
  }
}
