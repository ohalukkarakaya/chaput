import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/secure_storage_provider.dart';
import '../../../core/storage/token_storage.dart';
import 'auth_api.dart';
import 'dto/login_verify_response.dart';
import 'dto/refresh_response.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    api: ref.read(authApiProvider),
    tokenStorage: ref.read(tokenStorageProvider),
  );
});

abstract class AuthRepository {
  Future<void> requestLoginCode({
    required String email,
    required String deviceId,
  });

  Future<LoginVerifyResponse> verifyLoginCode({
    required String email,
    required String deviceId,
    required String code,
  });

  Future<void> logout();
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthApi api;
  final TokenStorage tokenStorage;

  AuthRepositoryImpl({
    required this.api,
    required this.tokenStorage,
  });

  @override
  Future<void> requestLoginCode({
    required String email,
    required String deviceId,
  }) {
    return api.requestLoginCode(email: email, deviceId: deviceId);
  }

  @override
  Future<LoginVerifyResponse> verifyLoginCode({
    required String email,
    required String deviceId,
    required String code,
  }) async {
    final res = await api.verifyLoginCode(email: email, deviceId: deviceId, code: code);

    // ✅ tokens kaydet
    await tokenStorage.saveAccessToken(res.accessToken);
    await tokenStorage.saveRefreshToken(res.refreshToken);

    return res;
  }

  @override
  Future<void> logout() async {
    final refresh = await tokenStorage.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      await tokenStorage.clear();
      return;
    }

    try {
      await api.logout(refreshToken: refresh);
    } finally {
      // 200 de olsa, 401 de olsa lokal temizle
      await tokenStorage.clear();
    }
  }

  @override
  Future<RefreshResponse> refresh({required String refreshToken}) {
    return api.refresh(refreshToken: refreshToken);
  }
}
