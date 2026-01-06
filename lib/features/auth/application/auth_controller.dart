import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device/device_id_service.dart';
import '../../../core/storage/secure_storage_provider.dart';
import '../data/auth_api.dart';
import '../domain/models/session.dart';

final authControllerProvider =
AsyncNotifierProvider<AuthController, Session?>(AuthController.new);

class AuthController extends AsyncNotifier<Session?> {
  late final _tokenStorage = ref.read(tokenStorageProvider);
  late final _api = ref.read(authApiProvider);

  @override
  Future<Session?> build() async {
    // ✅ Sadece lokalden session restore
    final userId = await _tokenStorage.readUserId();
    final access = await _tokenStorage.readAccessToken();

    if (userId != null && userId.isNotEmpty && access != null && access.isNotEmpty) {
      return Session(userId: userId, accessToken: access);
    }

    return null;
  }

  /// 1.1 Login – kod iste
  Future<void> requestLoginCode({required String email}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final deviceId = await ref.read(deviceIdServiceProvider).getOrCreate();
      await _api.requestLoginCode(email: email, deviceId: deviceId);

      // Kod istek başarılı: session oluşturmayız, sadece state’i geri eski haline getiririz
      return state.value; // mevcut session (genelde null)
    });
  }

  /// 1.2 Login – kod doğrula (token üretir)
  Future<void> verifyLoginCode({
    required String email,
    required String code,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final deviceId = await ref.read(deviceIdServiceProvider).getOrCreate();

      final res = await _api.verifyLoginCode(
        email: email,
        deviceId: deviceId,
        code: code,
      );

      // ✅ tokens kaydet
      await _tokenStorage.saveAccessToken(res.accessToken);
      await _tokenStorage.saveRefreshToken(res.refreshToken);

      // userId backend’in verify response’unda yok. Şimdilik session userId olmadan yönetilecekse:
      // - Session modelin userId zorunluysa iki seçenek:
      //   A) Session'ı userId nullable yap
      //   B) userId'yi JWT'den decode et (şimdilik istemiyoruz)
      //
      // En hızlı MVP: Session modelini userId nullable yapmanı öneririm.
      // Eğer userId zorunlu kalacaksa, burada placeholder kullanmak zorunda kalırız.
      return Session(userId: 'me', accessToken: res.accessToken);
    });
  }

  /// 1.4 Logout
  Future<void> logout() async {
    final refresh = await _tokenStorage.readRefreshToken();

    // server logout çağrısını dene (refresh yoksa direkt temizle)
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _api.logout(refreshToken: refresh);
      } catch (_) {
        // 401 invalid_refresh_token vs olsa bile lokal temizleyeceğiz
      }
    }

    await _tokenStorage.clear();
    state = const AsyncData(null);
  }
}
