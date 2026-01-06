import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'dto/auth_response.dart';
import 'dto/login_request.dart';
import 'dto/login_verify_response.dart';
import 'dto/refresh_response.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  final dio = ref.watch(authDioProvider); // interceptor'suz dio
  return AuthApi(dio);
});

class AuthApi {
  final Dio _dio;
  AuthApi(this._dio);

  Future<void> requestLoginCode({
    required String email,
    required String deviceId,
  }) async {
    await _dio.post(
      '/auth/login/request-code',
      data: {
        'email': email,
        'device_id': deviceId,
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
  }

  Future<LoginVerifyResponse> verifyLoginCode({
    required String email,
    required String deviceId,
    required String code,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/login/verify-code',
      data: {
        'email': email,
        'device_id': deviceId,
        'code': code,
      },
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    return LoginVerifyResponse.fromJson(res.data ?? const {});
  }

  Future<void> logout({
    required String refreshToken,
  }) async {
    await _dio.post(
      '/auth/logout',
      data: {'refresh_token': refreshToken},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
  }

  Future<RefreshResponse> refresh({
    required String refreshToken,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/token/refresh',
      data: {'refresh_token': refreshToken},
    );

    final data = res.data ?? <String, dynamic>{};
    return RefreshResponse.fromJson(data);
  }

}