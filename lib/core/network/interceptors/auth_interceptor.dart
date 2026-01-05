import 'dart:async';
import 'package:dio/dio.dart';

import '../../storage/token_storage.dart';
import '../../../features/auth/data/auth_api.dart';
import '../../utils/logger.dart';

class AuthInterceptor extends Interceptor {
  final TokenStorage tokenStorage;
  final AuthApi authApi;
  final Future<void> Function() onForceLogout;

  AuthInterceptor({
    required this.tokenStorage,
    required this.authApi,
    required this.onForceLogout,
  });

  Completer<void>? _refreshCompleter;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final access = await tokenStorage.readAccessToken();
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // sadece 401 ise refresh dene
    final is401 = err.response?.statusCode == 401;
    final requestOptions = err.requestOptions;

    // login/refresh endpointlerinde refresh deneme (loop)
    final path = requestOptions.path;
    if (!is401 || path.contains('/auth/login') || path.contains('/auth/refresh')) {
      return handler.next(err);
    }

    try {
      await _refreshTokenOnce();
      final newAccess = await tokenStorage.readAccessToken();

      if (newAccess == null || newAccess.isEmpty) {
        await onForceLogout();
        return handler.next(err);
      }

      // requesti tekrar dene
      final dio = err.requestOptions.extra['dio'] as Dio?;
      final client = dio ?? Dio(); // fallback (normalde extra ile set edeceğiz)

      final cloned = await _retry(client, requestOptions, newAccess);
      return handler.resolve(cloned);
    } catch (e, st) {
      Log.e('Refresh failed -> force logout', error: e, st: st);
      await onForceLogout();
      return handler.next(err);
    }
  }

  Future<void> _refreshTokenOnce() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<void>();
    try {
      final refresh = await tokenStorage.readRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        throw StateError('No refresh token');
      }

      final res = await authApi.refresh(refreshToken: refresh);

      await tokenStorage.saveAccessToken(res.accessToken);

      _refreshCompleter!.complete();
    } catch (e, st) {
      _refreshCompleter!.completeError(e, st);
      rethrow;
    } finally {
      // küçük gecikmeyle null’la (eş zamanlı isteklerde stabil)
      Future.microtask(() => _refreshCompleter = null);
    }
  }

  Future<Response<dynamic>> _retry(Dio dio, RequestOptions requestOptions, String accessToken) async {
    final options = Options(
      method: requestOptions.method,
      headers: Map<String, dynamic>.from(requestOptions.headers)
        ..['Authorization'] = 'Bearer $accessToken',
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      followRedirects: requestOptions.followRedirects,
      receiveTimeout: requestOptions.receiveTimeout,
      sendTimeout: requestOptions.sendTimeout,
      validateStatus: requestOptions.validateStatus,
    );

    return dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }
}