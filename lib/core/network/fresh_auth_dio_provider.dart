import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage_provider.dart';

final freshAuthDioProvider = Provider<Dio>((ref) {
  final storage = ref.read(tokenStorageProvider);

  final dio = Dio(BaseOptions(
    baseUrl: 'http://192.168.178.81:8080', // sende neyse
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // refresh için ayrı dio (recursive olmasın)
  final refreshDio = Dio(BaseOptions(
    baseUrl: dio.options.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final refresh = await storage.readRefreshToken();
        if (refresh == null || refresh.isEmpty) {
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
            log('[Chaput] ➡️ AUTH header set for ${options.method} ${options.path}');
          } else {
            log('[Chaput] ⚠️ refresh 200 but access_token empty');
          }

          return handler.next(options);
        } catch (e) {
          log('[Chaput] ❌ refresh failed -> sending request without token', error: e);
          return handler.next(options);
        }
      },
    ),
  );

  return dio;
});