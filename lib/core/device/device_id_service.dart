import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../storage/secure_storage_provider.dart';
import '../storage/token_storage.dart';

final deviceIdServiceProvider = Provider<DeviceIdService>((ref) {
  return DeviceIdService(ref.read(tokenStorageProvider));
});

class DeviceIdService {
  static const _uuid = Uuid();
  final TokenStorage _storage;

  DeviceIdService(this._storage);

  Future<String> getOrCreate() async {
    final existing = await _storage.readDeviceId();
    if (existing != null && existing.isNotEmpty) return existing;

    final id = _uuid.v4(); // unique device id
    await _storage.saveDeviceId(id);
    return id;
  }
}