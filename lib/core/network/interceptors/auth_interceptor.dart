import 'dart:async';
import 'package:dio/dio.dart';

import '../../storage/token_storage.dart';
import '../../../features/auth/data/auth_api.dart';
import '../../utils/logger.dart';

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

  Future<Response<dynamic>> _retry(
      Dio dio,
      RequestOptions ro,
      String accessToken,
      ) async {
    final base = (ro.baseUrl.isNotEmpty) ? ro.baseUrl : dio.options.baseUrl;

    if (base.isEmpty) {
      throw StateError('Dio baseUrl boş. retry yapılamaz.');
    }

    // ✅ ABSOLUTE URI üret (No host specified fix)
    final uri = Uri.parse(base).resolve(ro.path);

    final options = Options(
      method: ro.method,
      headers: Map<String, dynamic>.from(ro.headers)
        ..['Authorization'] = 'Bearer $accessToken',
      responseType: ro.responseType,
      contentType: ro.contentType,
      followRedirects: ro.followRedirects,
      receiveTimeout: ro.receiveTimeout,
      sendTimeout: ro.sendTimeout,
      validateStatus: ro.validateStatus,
    );

    // ✅ requestUri: baseUrl/path birleşimi garanti
    return dio.requestUri<dynamic>(
      uri,
      data: ro.data,
      options: options,
      cancelToken: ro.cancelToken,
      onReceiveProgress: ro.onReceiveProgress,
      onSendProgress: ro.onSendProgress,
    );

  }
}