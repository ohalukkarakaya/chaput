import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kUserId = 'user_id';
  static const _kDeviceId = 'device_id';
  static const _kHasAuthenticatedBefore = 'has_authenticated_before';

  final FlutterSecureStorage _storage;
  TokenStorage(this._storage);

  Future<void> saveSession({
    required String userId,
    required String accessToken,
    required String refreshToken,
    required String deviceId,
  }) async {
    await _storage.write(key: _kUserId, value: userId);
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kRefresh, value: refreshToken);
    await _storage.write(key: _kDeviceId, value: deviceId);
    await markAuthenticated();
  }

  Future<String?> readUserId() => _storage.read(key: _kUserId);
  Future<String?> readAccessToken() => _storage.read(key: _kAccess);
  Future<String?> readRefreshToken() => _storage.read(key: _kRefresh);
  Future<bool> hasAuthenticatedBefore() async =>
      (await _storage.read(key: _kHasAuthenticatedBefore)) == '1';
  Future<void> markAuthenticated() =>
      _storage.write(key: _kHasAuthenticatedBefore, value: '1');

  Future<void> saveDeviceId(String id) =>
      _storage.write(key: _kDeviceId, value: id);
  Future<String?> readDeviceId() => _storage.read(key: _kDeviceId);

  Future<void> saveUserId(String id) =>
      _storage.write(key: _kUserId, value: id);
  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _kAccess, value: token);
  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _kRefresh, value: token);
    if (token.isNotEmpty) {
      await markAuthenticated();
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}
