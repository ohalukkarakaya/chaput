import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../me/data/me_api.dart';
import '../../me/domain/me_models.dart';
import '../../notifications/application/firebase_token_cleanup.dart';
import '../../revenuecat/data/revenue_cat_service.dart';
import '../../../core/deep_links/deep_link_state.dart';
import '../../../core/storage/secure_storage_provider.dart';

final meControllerProvider = AsyncNotifierProvider<MeController, MeResponse?>(
  MeController.new,
);

class MeController extends AsyncNotifier<MeResponse?> {
  @override
  Future<MeResponse?> build() async => null;

  /// App açılışında /me ilk istek: başarılıysa state'e yazar.
  /// 400 -> silent retry 1 kez
  /// 401/404 -> hard logout (storage clear)
  Future<MeResponse?> fetchAndStoreMe() async {
    final previous = state.value;
    state = const AsyncLoading();

    final api = ref.read(meApiProvider);
    final storage = ref.read(tokenStorageProvider);

    Future<MeResponse> call() => api.getMe();

    try {
      final me = await call();
      await _syncRevenueCatUser(me);
      state = AsyncData(me);
      return me;
    } on DioException catch (e, st) {
      final code = e.response?.statusCode;

      log(
        'ME: /me error status=$code data=${e.response?.data}',
        error: e,
        stackTrace: st,
      );

      // 400 -> silent retry 1 kez
      if (code == 400) {
        try {
          final me = await call();
          await _syncRevenueCatUser(me);
          state = AsyncData(me);
          return me;
        } catch (e2, st2) {
          log('ME: /me retry failed', error: e2, stackTrace: st2);
        }
      }

      // 401 or 404 -> hard logout
      if (code == 401 || code == 404) {
        await RevenueCatService.instance.logOut();
        await FirebaseTokenCleanup.deleteLocalMessagingToken();
        await storage.clear();
        ref.read(pendingDeepLinkProvider.notifier).state = null;
        state = const AsyncData(null);
        rethrow; // caller decide navigation
      }

      // 500+, network, temporary backend errors -> keep last known /me.
      state = AsyncData(previous);
      rethrow;
    } catch (e, st) {
      log('ME: unknown error', error: e, stackTrace: st);
      state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> _syncRevenueCatUser(MeResponse me) async {
    final userId = me.user.userId.trim();
    if (userId.isEmpty) return;

    final storage = ref.read(tokenStorageProvider);
    await storage.saveUserId(userId);

    final result = await RevenueCatService.instance.logInWithBackendUserId(
      userId,
      email: me.user.email,
      displayName: me.user.fullName,
      username: me.user.username,
    );
    if (!result.isSuccess) {
      log(
        'RevenueCat user sync failed status=${result.status} message=${result.message}',
        error: result.exception,
      );
    }
  }
}
