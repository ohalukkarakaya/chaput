import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage_provider.dart';

final tutorialStorageProvider = Provider<TutorialStorage>((ref) {
  return TutorialStorage(ref.read(secureStorageProvider));
});

class TutorialStorage {
  TutorialStorage(this._storage);

  final FlutterSecureStorage _storage;

  String _key(String userId, String feature) => 'tutorial_${feature}_$userId';

  Future<bool> shouldShow(String userId, String feature) async {
    if (userId.isEmpty) return false;
    final v = await _storage.read(key: _key(userId, feature));
    return v != '1';
  }

  Future<void> markShown(String userId, String feature) async {
    if (userId.isEmpty) return;
    await _storage.write(key: _key(userId, feature), value: '1');
  }
}
