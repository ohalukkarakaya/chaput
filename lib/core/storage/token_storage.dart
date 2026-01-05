import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kUserId = 'user_id';
  static const _kDeviceId = 'device_id';

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
  }

  Future<String?> readUserId() => _storage.read(key: _kUserId);
  Future<String?> readAccessToken() => _storage.read(key: _kAccess);
  Future<String?> readRefreshToken() => _storage.read(key: _kRefresh);

  Future<void> saveDeviceId(String id) => _storage.write(key: _kDeviceId, value: id);
  Future<String?> readDeviceId() => _storage.read(key: _kDeviceId);

  Future<void> saveAccessToken(String token) => _storage.write(key: _kAccess, value: token);
  Future<void> saveRefreshToken(String token) => _storage.write(key: _kRefresh, value: token);

  Future<void> clear() async {
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}