import 'package:dio/dio.dart';

import '../../../features/auth/data/auth_api.dart';
import '../../storage/token_storage.dart';
import '../../utils/logger.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.tokenStorage,
    required this.authApi,
    required this.onForceLogout,
  });

  final TokenStorage tokenStorage;
  final AuthApi authApi;
  final Future<void> Function() onForceLogout;

  Future<void>? _refreshFuture;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final access = await tokenStorage.readAccessToken();
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final is401 = err.response?.statusCode == 401;
    final requestOptions = err.requestOptions;
    final path = requestOptions.path;

    if (!is401 ||
        path.contains('/auth/login') ||
        path.contains('/auth/token/refresh')) {
      return handler.next(err);
    }

    try {
      await _refreshTokenOnce();
      final newAccess = await tokenStorage.readAccessToken();

      if (newAccess == null || newAccess.isEmpty) {
        await onForceLogout();
        return handler.next(err);
      }

      final dio = err.requestOptions.extra['dio'] as Dio?;
      final client = dio ?? Dio();

      final response = await _retry(client, requestOptions, newAccess);
      return handler.resolve(response);
    } catch (e, st) {
      Log.e('Refresh failed -> force logout', error: e, st: st);
      await onForceLogout();
      return handler.next(err);
    }
  }

  Future<void> _refreshTokenOnce() async {
    final current = _refreshFuture;
    if (current != null) {
      return current;
    }

    final next = () async {
      final refresh = await tokenStorage.readRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        throw StateError('No refresh token');
      }

      final res = await authApi.refresh(refreshToken: refresh);
      await tokenStorage.saveAccessToken(res.accessToken);
    }();

    _refreshFuture = next.whenComplete(() {
      Future.microtask(() => _refreshFuture = null);
    });
    return _refreshFuture!;
  }

  Future<Response<dynamic>> _retry(
    Dio dio,
    RequestOptions ro,
    String accessToken,
  ) async {
    final base = ro.baseUrl.isNotEmpty ? ro.baseUrl : dio.options.baseUrl;
    if (base.isEmpty) {
      throw StateError('Dio baseUrl boş. retry yapılamaz.');
    }

    final uri = Uri.parse(base)
        .resolve(ro.path)
        .replace(
          queryParameters: ro.queryParameters.isEmpty
              ? null
              : ro.queryParameters.map(
                  (key, value) => MapEntry(key, value?.toString()),
                ),
        );
    final headers = Map<String, dynamic>.from(ro.headers)
      ..remove('content-length')
      ..remove('Content-Length')
      ..['Authorization'] = 'Bearer $accessToken';

    final options = Options(
      method: ro.method,
      headers: headers,
      responseType: ro.responseType,
      contentType: ro.contentType,
      followRedirects: ro.followRedirects,
      receiveTimeout: ro.receiveTimeout,
      sendTimeout: ro.sendTimeout,
      validateStatus: ro.validateStatus,
      extra: Map<String, dynamic>.from(ro.extra)..['dio'] = dio,
    );

    return dio.requestUri<dynamic>(
      uri,
      data: _cloneRequestData(ro.data),
      options: options,
      cancelToken: ro.cancelToken,
      onReceiveProgress: ro.onReceiveProgress,
      onSendProgress: ro.onSendProgress,
    );
  }

  Object? _cloneRequestData(Object? data) {
    if (data == null) {
      return null;
    }
    if (data is FormData) {
      return data.clone();
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is List) {
      return List<dynamic>.from(data);
    }
    return data;
  }
}
