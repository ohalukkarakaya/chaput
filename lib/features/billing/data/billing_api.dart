import 'package:dio/dio.dart';

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

    final res = await _dio.post('/billing/purchase/verify', data: payload);
    final data = res.data;
    if (data is Map<String, dynamic>) {
      if (data['ok'] == true) {
        return BillingVerifyResult.fromJson(data);
      }
      throw Exception(data['error'] ?? 'verify_failed');
    }
    throw Exception('bad_verify_response');
  }
}
