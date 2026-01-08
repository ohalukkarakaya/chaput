import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage_provider.dart';

final freshAuthDioProvider = Provider<Dio>((ref) {
  final storage = ref.read(tokenStorageProvider);

  final base = Dio(BaseOptions(
    baseUrl: 'http://localhost:8080',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // refresh için recursive olmayan ayrı dio
  final refreshDio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8080',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  base.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final refresh = await storage.readRefreshToken();
        if (refresh == null || refresh.isEmpty) {
          return handler.next(options);
        }

        try {
          final res = await refreshDio.post<Map<String, dynamic>>(
            '/auth/token/refresh',
            data: {'refresh_token': refresh},
            options: Options(headers: {'Content-Type': 'application/json'}),
          );

          final access = (res.data?['access_token'] ?? '') as String;
          if (access.isNotEmpty) {
            await storage.saveAccessToken(access);
            options.headers['Authorization'] = 'Bearer $access';
          }

          return handler.next(options);
        } catch (_) {
          // refresh patladıysa request’i yine de gönderme yerine:
          // (istersen burada onboarding’e yönlendirme tetiklenebilir)
          return handler.next(options);
        }
      },
    ),
  );

  return base;
});