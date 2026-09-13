import 'package:chaput/core/storage/profile_photo_prompt_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('prompts immediately for a user who never uploaded a photo', () async {
    final storage = ProfilePhotoPromptStorage(const FlutterSecureStorage());
    final now = DateTime.utc(2026, 9, 13);

    expect(
      await storage.shouldPrompt('user_1', hasProfilePhoto: false, now: now),
      isTrue,
    );

    await storage.markPromptShown('user_1', now: now);

    expect(
      await storage.shouldPrompt(
        'user_1',
        hasProfilePhoto: false,
        now: now.add(const Duration(days: 20)),
      ),
      isFalse,
    );
    expect(
      await storage.shouldPrompt(
        'user_1',
        hasProfilePhoto: false,
        now: now.add(const Duration(days: 21)),
      ),
      isTrue,
    );
  });

  test('waits three weeks after an uploaded photo is removed', () async {
    final storage = ProfilePhotoPromptStorage(const FlutterSecureStorage());
    final removedAt = DateTime.utc(2026, 9, 13);

    await storage.markPhotoUploaded('user_2');
    await storage.markPhotoRemoved('user_2', now: removedAt);

    expect(
      await storage.shouldPrompt(
        'user_2',
        hasProfilePhoto: false,
        now: removedAt.add(const Duration(days: 20)),
      ),
      isFalse,
    );
    expect(
      await storage.shouldPrompt(
        'user_2',
        hasProfilePhoto: false,
        now: removedAt.add(const Duration(days: 21)),
      ),
      isTrue,
    );
  });

  test('uploading a photo clears prompt cooldown state', () async {
    final storage = ProfilePhotoPromptStorage(const FlutterSecureStorage());
    final now = DateTime.utc(2026, 9, 13);

    await storage.markPromptShown('user_3', now: now);
    await storage.markPhotoUploaded('user_3');

    expect(
      await storage.shouldPrompt(
        'user_3',
        hasProfilePhoto: true,
        now: now.add(const Duration(days: 90)),
      ),
      isFalse,
    );

    await storage.markPhotoRemoved(
      'user_3',
      now: now.add(const Duration(days: 90)),
    );

    expect(
      await storage.shouldPrompt(
        'user_3',
        hasProfilePhoto: false,
        now: now.add(const Duration(days: 90, hours: 1)),
      ),
      isFalse,
    );
  });
}
