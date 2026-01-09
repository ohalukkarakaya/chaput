import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../me/data/me_api.dart';
import '../../me/domain/me_models.dart';
import '../../../core/storage/secure_storage_provider.dart';

final meControllerProvider =
AsyncNotifierProvider<MeController, MeResponse?>(MeController.new);

class MeController extends AsyncNotifier<MeResponse?> {
  @override
  Future<MeResponse?> build() async => null;

  /// App açılışında /me ilk istek: başarılıysa state'e yazar.
  /// 400 -> silent retry 1 kez
  /// 401/404 -> hard logout (storage clear)
  Future<MeResponse?> fetchAndStoreMe() async {
    state = const AsyncLoading();

    final api = ref.read(meApiProvider);
    final storage = ref.read(tokenStorageProvider);

    Future<MeResponse> call() => api.getMe();

    try {
      final me = await call();
      state = AsyncData(me);
      return me;
    } on DioException catch (e, st) {
      final code = e.response?.statusCode;

      log('ME: /me error status=$code data=${e.response?.data}', error: e, stackTrace: st);

      // 400 -> silent retry 1 kez
      if (code == 400) {
        try {
          final me = await call();
          state = AsyncData(me);
          return me;
        } catch (e2, st2) {
          log('ME: /me retry failed', error: e2, stackTrace: st2);
        }
      }

      // 401 or 404 -> hard logout
      if (code == 401 || code == 404) {
        await storage.clear();
        state = const AsyncData(null);
        rethrow; // caller decide navigation
      }

      // 500+ vs -> keep null
      state = const AsyncData(null);
      rethrow;
    } catch (e, st) {
      log('ME: unknown error', error: e, stackTrace: st);
      state = const AsyncData(null);
      rethrow;
    }
  }
}