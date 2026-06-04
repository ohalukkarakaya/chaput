import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../storage/secure_storage_provider.dart';
import '../../features/notifications/application/firebase_token_cleanup.dart';

final freshAuthDioProvider = Provider<Dio>((ref) {
  final storage = ref.read(tokenStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: Env.connectTimeout,
      receiveTimeout: Env.receiveTimeout,
    ),
  );

  // refresh için ayrı dio (recursive olmasın)
  final refreshDio = Dio(
    BaseOptions(
      baseUrl: dio.options.baseUrl,
      connectTimeout: Env.connectTimeout,
      receiveTimeout: Env.receiveTimeout,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final refresh = await storage.readRefreshToken();
        if (refresh == null || refresh.isEmpty) {
          final access = await storage.readAccessToken();
          if (access != null && access.isNotEmpty) {
            options.headers = {
              ...options.headers,
              'Authorization': 'Bearer $access',
            };
          }
          return handler.next(options);
        }

        try {
          final r = await refreshDio.post(
            '/auth/token/refresh',
            data: {'refresh_token': refresh},
            options: Options(contentType: Headers.jsonContentType),
          );

          // ✅ robust parse
          String access = '';
          final data = r.data;

          if (data is Map) {
            access = (data['access_token'] ?? '') as String;
          } else if (data is String) {
            // bazı backendlere göre body string olabiliyor
            // burada en azından loglayalım
            access = '';
          }

          log('[Chaput] ✅(AUTH) refresh access len=${access.length}');

          if (access.isNotEmpty) {
            await storage.saveAccessToken(access);

            // ✅ HEADER MERGE: mevcut header’ları ezme
            options.headers = {
              ...options.headers,
              'Authorization': 'Bearer $access',
            };

            // Debug: gerçekten eklenmiş mi?
            log(
              '[Chaput] ➡️ AUTH header set for ${options.method} ${options.path}',
            );
            return handler.next(options);
          }

          log('[Chaput] ⚠️ refresh 200 but access_token empty');
          await FirebaseTokenCleanup.deleteLocalMessagingToken();
          await storage.clear();
          return handler.reject(
            DioException(
              requestOptions: options,
              error: 'refresh_empty_access_token',
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: 401,
                data: {'error': 'invalid_refresh'},
              ),
            ),
          );
        } on DioException catch (e) {
          final code = e.response?.statusCode;
          if (code == 400 || code == 401) {
            await FirebaseTokenCleanup.deleteLocalMessagingToken();
            await storage.clear();
          }
          log('[Chaput] ❌ refresh failed -> rejecting request', error: e);
          return handler.reject(
            DioException(
              requestOptions: options,
              response: e.response,
              error: e.error ?? 'refresh_failed',
              type: e.type,
            ),
          );
        } catch (e) {
          log('[Chaput] ❌ refresh failed -> rejecting request', error: e);
          return handler.reject(
            DioException(
              requestOptions: options,
              error: e,
              type: DioExceptionType.unknown,
            ),
          );
        }
      },
    ),
  );

  return dio;
});
