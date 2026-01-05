import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage_provider.dart';
import '../data/auth_api.dart';
import '../data/auth_repository_impl.dart';
import '../domain/models/session.dart';

final authControllerProvider =
AsyncNotifierProvider<AuthController, Session?>(AuthController.new);

class AuthController extends AsyncNotifier<Session?> {
  late final _tokenStorage = ref.read(tokenStorageProvider);
  late final _repo = AuthRepositoryImpl(ref.read(authApiProvider));

  @override
  Future<Session?> build() async {
    final userId = await _tokenStorage.readUserId();
    final access = await _tokenStorage.readAccessToken();
    final refresh = await _tokenStorage.readRefreshToken();

    // Eğer access yoksa ama refresh varsa, burada refresh deneyebilirsin (opsiyonel).
    if (userId != null && access != null && access.isNotEmpty) {
      return Session(userId: userId, accessToken: access);
    }

    // refresh varsa, session restore dene:
    if (refresh != null && refresh.isNotEmpty) {
      try {
        final refreshed = await _repo.refresh(refreshToken: refresh);
        // userId storage’da varsa koru
        if (userId != null && userId.isNotEmpty) {
          await _tokenStorage.saveAccessToken(refreshed.accessToken);
          if (refreshed.refreshToken != null && refreshed.refreshToken!.isNotEmpty) {
            await _tokenStorage.saveRefreshToken(refreshed.refreshToken!);
          }
          return Session(userId: userId, accessToken: refreshed.accessToken);
        }
      } catch (_) {
        // ignore -> fallthrough
      }
    }

    return null;
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final res = await _repo.login(username: username, password: password);

      await _tokenStorage.saveSession(
        userId: res.userId,
        accessToken: res.accessToken,
        refreshToken: res.refreshToken,
      );

      return Session(userId: res.userId, accessToken: res.accessToken);
    });
  }

  Future<void> logout() async {
    await _tokenStorage.clear();
    state = const AsyncData(null);
  }
}