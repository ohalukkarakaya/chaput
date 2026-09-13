import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';

final accountApiProvider = Provider<AccountApi>((ref) {
  final dio = ref.read(dioProvider);
  return AccountApi(dio);
});

class AccountApi {
  final Dio _dio;
  AccountApi(this._dio);

  Future<void> freezeMe() async {
    final r = await _dio.post('/me/account/freeze');
    final data = r.data;
    if (data is Map && data['ok'] == true) return;
    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
    );
  }

  Future<void> unfreezeMe() async {
    final r = await _dio.post('/me/account/unfreeze');
    final data = r.data;
    if (data is Map && data['ok'] == true) return;
    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
    );
  }

  Future<void> deleteMeHard({required String reason}) async {
    final Response<dynamic> r;
    try {
      r = await _dio.delete('/me/account', data: {'reason': reason});
    } on DioException catch (e) {
      final data = e.response?.data;
      if (e.response?.statusCode == 404 ||
          (data is Map && data['error'] == 'user_not_found')) {
        return;
      }
      rethrow;
    }
    final status = r.statusCode ?? 0;
    if (status >= 200 && status < 300) return;
    final data = r.data;
    if (data is Map && data['ok'] == true) return;
    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
    );
  }

  Future<bool> restorePurchases() async {
    final r = await _dio.post('/me/purchases/restore');
    final data = r.data;
    if (data is Map && data['ok'] == true) {
      return data['restored'] == true;
    }
    throw DioException(
      requestOptions: r.requestOptions,
      response: r,
      type: DioExceptionType.badResponse,
    );
  }
}
