import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'dto/auth_response.dart';
import 'dto/login_request.dart';
import 'dto/refresh_response.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  final dio = ref.watch(authDioProvider); // interceptor'suz dio
  return AuthApi(dio);
});

class AuthApi {
  final Dio _dio;
  AuthApi(this._dio);

  Future<AuthResponse> login({
    required String username,
    required String password,
  }) async {
    final body = LoginRequest(username: username, password: password).toJson();
    final res = await _dio.post<Map<String, dynamic>>('/auth/login', data: body);
    final data = res.data ?? <String, dynamic>{};
    return AuthResponse.fromJson(data);
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