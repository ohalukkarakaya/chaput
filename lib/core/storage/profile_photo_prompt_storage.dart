import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage_provider.dart';

final profilePhotoPromptStorageProvider = Provider<ProfilePhotoPromptStorage>((
  ref,
) {
  return ProfilePhotoPromptStorage(ref.read(secureStorageProvider));
});

class ProfilePhotoPromptStorage {
  ProfilePhotoPromptStorage(this._storage);

  static const reminderInterval = Duration(days: 21);

  final FlutterSecureStorage _storage;

  String _lastShownKey(String userId) =>
      'profile_photo_prompt_last_shown_$userId';
  String _missingSinceKey(String userId) =>
      'profile_photo_prompt_missing_since_$userId';
  String _hadPhotoKey(String userId) =>
      'profile_photo_prompt_had_photo_$userId';

  Future<void> recordPhotoState(
    String userId, {
    required bool hasProfilePhoto,
    DateTime? now,
  }) async {
    if (userId.isEmpty) return;

    if (hasProfilePhoto) {
      await _storage.write(key: _hadPhotoKey(userId), value: '1');
      await _storage.delete(key: _missingSinceKey(userId));
      await _storage.delete(key: _lastShownKey(userId));
      return;
    }

    final hadPhoto = await _storage.read(key: _hadPhotoKey(userId)) == '1';
    if (!hadPhoto) return;

    final missingSince = await _storage.read(key: _missingSinceKey(userId));
    if (missingSince == null || missingSince.isEmpty) {
      await _storage.write(
        key: _missingSinceKey(userId),
        value: (now ?? DateTime.now()).toUtc().toIso8601String(),
      );
    }
  }

  Future<void> markPhotoRemoved(String userId, {DateTime? now}) async {
    if (userId.isEmpty) return;
    await _storage.write(key: _hadPhotoKey(userId), value: '1');
    await _storage.delete(key: _lastShownKey(userId));
    await _storage.write(
      key: _missingSinceKey(userId),
      value: (now ?? DateTime.now()).toUtc().toIso8601String(),
    );
  }

  Future<void> markPhotoUploaded(String userId) {
    return recordPhotoState(userId, hasProfilePhoto: true);
  }

  Future<bool> shouldPrompt(
    String userId, {
    required bool hasProfilePhoto,
    DateTime? now,
  }) async {
    if (userId.isEmpty || hasProfilePhoto) return false;

    final current = (now ?? DateTime.now()).toUtc();
    final lastShown = _parseUtc(
      await _storage.read(key: _lastShownKey(userId)),
    );
    if (lastShown != null) {
      return current.difference(lastShown) >= reminderInterval;
    }

    final hadPhoto = await _storage.read(key: _hadPhotoKey(userId)) == '1';
    if (!hadPhoto) return true;

    final rawMissingSince = await _storage.read(key: _missingSinceKey(userId));
    final missingSince = _parseUtc(rawMissingSince);
    if (missingSince == null) {
      await _storage.write(
        key: _missingSinceKey(userId),
        value: current.toIso8601String(),
      );
      return false;
    }

    return current.difference(missingSince) >= reminderInterval;
  }

  Future<void> markPromptShown(String userId, {DateTime? now}) async {
    if (userId.isEmpty) return;
    final current = (now ?? DateTime.now()).toUtc();
    await _storage.write(
      key: _lastShownKey(userId),
      value: current.toIso8601String(),
    );
  }

  DateTime? _parseUtc(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed : parsed.toUtc();
  }
}
