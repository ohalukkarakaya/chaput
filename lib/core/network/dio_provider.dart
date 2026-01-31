import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../utils/logger.dart';
import '../storage/secure_storage_provider.dart';
import '../../features/auth/data/auth_api.dart';
import 'interceptors/auth_interceptor.dart';

Dio _buildBaseDio() {
  return Dio(BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: Env.connectTimeout,
    receiveTimeout: Env.receiveTimeout,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));
}

/// Auth işleri için (login/refresh) interceptor'suz Dio.
/// Böylece circular dependency olmaz.
final authDioProvider = Provider<Dio>((ref) {
  final dio = _buildBaseDio();

  if (Env.logNetwork) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        Log.d('➡️(AUTH) ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        Log.d('✅(AUTH) ${response.statusCode} ${response.requestOptions.uri}');
        handler.next(response);
      },
      onError: (e, handler) {
        Log.e('❌(AUTH) ${e.response?.statusCode} ${e.requestOptions.uri}', error: e, st: e.stackTrace);
        handler.next(e);
      },
    ));
  }

  return dio;
});

/// Uygulamanın ana Dio'su (Authorization header + 401 refresh + retry)
final dioProvider = Provider<Dio>((ref) {
  final dio = _buildBaseDio();

  if (Env.logNetwork) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.extra['dio'] = dio;
        Log.d('➡️ ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        Log.d('✅ ${response.statusCode} ${response.requestOptions.uri}');
        handler.next(response);
      },
      onError: (e, handler) {
        Log.e('❌ ${e.response?.statusCode} ${e.requestOptions.uri}', error: e, st: e.stackTrace);
        handler.next(e);
      },
    ));
  }

  // IMPORTANT: authApiProvider -> authDioProvider kullandığı için döngü yok.
  final authApi = ref.read(authApiProvider);

  dio.interceptors.add(AuthInterceptor(
    tokenStorage: ref.read(tokenStorageProvider),
    authApi: authApi,
    onForceLogout: () async {
      await ref.read(tokenStorageProvider).clear();
    },
  ));

  return dio;
});
