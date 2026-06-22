import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../storage/secure_storage_provider.dart';

final appReviewServiceProvider = Provider<AppReviewService>((ref) {
  return AppReviewService(
    storage: ref.read(secureStorageProvider),
    inAppReview: InAppReview.instance,
  );
});

class AppReviewService {
  AppReviewService({
    required FlutterSecureStorage storage,
    required InAppReview inAppReview,
  }) : _storage = storage,
       _inAppReview = inAppReview;

  static const _openCountPrefix = 'review_open_count_';
  static const _deferCountPrefix = 'review_defer_count_';
  static const _nextPromptPrefix = 'review_next_prompt_';
  static const _completedPrefix = 'review_completed_';

  final FlutterSecureStorage _storage;
  final InAppReview _inAppReview;

  String? _sessionUserId;

  Future<void> recordAppOpenForSession(String userId) async {
    if (userId.isEmpty) return;
    if (_sessionUserId == userId) return;
    _sessionUserId = userId;

    final current = await _readInt(_openCountKey(userId));
    await _storage.write(
      key: _openCountKey(userId),
      value: (current + 1).toString(),
    );
  }

  Future<bool> shouldPrompt(String userId) async {
    if (userId.isEmpty) return false;
    if (await _readBool(_completedKey(userId))) return false;

    final openCount = await _readInt(_openCountKey(userId));
    if (openCount < 3) return false;

    final nextPromptAt = await _readDateTime(_nextPromptKey(userId));
    if (nextPromptAt == null) return true;
    return !DateTime.now().toUtc().isBefore(nextPromptAt);
  }

  Future<void> markLiked(String userId) async {
    if (userId.isEmpty) return;
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      }
    } catch (_) {}
    await _markCompleted(userId);
  }

  Future<void> markAskLater(String userId) async {
    if (userId.isEmpty) return;
    final nextDeferCount = await _readInt(_deferCountKey(userId)) + 1;
    await _storage.write(
      key: _deferCountKey(userId),
      value: nextDeferCount.toString(),
    );

    if (nextDeferCount == 1) {
      await _writeDateTime(
        _nextPromptKey(userId),
        DateTime.now().toUtc().add(const Duration(hours: 72)),
      );
      return;
    }
    if (nextDeferCount == 2) {
      await _writeDateTime(
        _nextPromptKey(userId),
        DateTime.now().toUtc().add(const Duration(days: 21)),
      );
      return;
    }

    await _markCompleted(userId);
  }

  String _openCountKey(String userId) => '$_openCountPrefix$userId';
  String _deferCountKey(String userId) => '$_deferCountPrefix$userId';
  String _nextPromptKey(String userId) => '$_nextPromptPrefix$userId';
  String _completedKey(String userId) => '$_completedPrefix$userId';

  Future<int> _readInt(String key) async {
    final raw = await _storage.read(key: key);
    return int.tryParse(raw ?? '') ?? 0;
  }

  Future<bool> _readBool(String key) async {
    return (await _storage.read(key: key)) == '1';
  }

  Future<DateTime?> _readDateTime(String key) async {
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<void> _writeDateTime(String key, DateTime value) {
    return _storage.write(key: key, value: value.toIso8601String());
  }

  Future<void> _markCompleted(String userId) async {
    await _storage.write(key: _completedKey(userId), value: '1');
    await _storage.delete(key: _nextPromptKey(userId));
  }
}
