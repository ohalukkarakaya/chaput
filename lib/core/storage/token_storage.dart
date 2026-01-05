import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kUserId = 'user_id';

  final FlutterSecureStorage _storage;
  TokenStorage(this._storage);

  Future<void> saveSession({
    required String userId,
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kUserId, value: userId);
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kRefresh, value: refreshToken);
  }

  Future<String?> readUserId() => _storage.read(key: _kUserId);
  Future<String?> readAccessToken() => _storage.read(key: _kAccess);
  Future<String?> readRefreshToken() => _storage.read(key: _kRefresh);

  Future<void> saveAccessToken(String token) => _storage.write(key: _kAccess, value: token);
  Future<void> saveRefreshToken(String token) => _storage.write(key: _kRefresh, value: token);

  Future<void> clear() async {
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}