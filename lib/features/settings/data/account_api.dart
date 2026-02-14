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

  Future<void> deleteMeHard() async {
    final r = await _dio.delete('/me/account');
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
