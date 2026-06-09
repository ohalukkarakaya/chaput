import 'package:chaput/features/notifications/application/notification_lifecycle_listener.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chaputNotificationTargetFromRemoteData', () {
    test(
      'opens recipient profile with thread and message for chaput messages',
      () {
        final target = chaputNotificationTargetFromRemoteData({
          'type': 'chaput_message',
          'user_id': 'USER123',
          'thread_id': 'THREAD456',
          'message_id': 'MESSAGE789',
        });

        expect(target?.location, '/profile/USER123');
        expect(target?.extra, {
          'threadId': 'THREAD456',
          'messageId': 'MESSAGE789',
        });
      },
    );

    test('falls back to home when chaput target has no recipient', () {
      final target = chaputNotificationTargetFromRemoteData({
        'type': 'chaput_started',
      });

      expect(target?.location, '/home');
      expect(target?.extra, isNull);
    });

    test('opens actor profile for follow notifications', () {
      final target = chaputNotificationTargetFromRemoteData({
        'type': 'followed',
        'actor_id': 'ACTOR123',
      });

      expect(target?.location, '/profile/ACTOR123');
      expect(target?.extra, isNull);
    });

    test('opens notifications when follow actor is missing', () {
      final target = chaputNotificationTargetFromRemoteData({
        'type': 'follow_request',
      });

      expect(target?.location, '/notifications');
      expect(target?.extra, isNull);
    });

    test('opens notifications for gift notifications', () {
      final target = chaputNotificationTargetFromRemoteData({
        'type': 'admin_gift_granted',
      });

      expect(target?.location, '/notifications');
      expect(target?.extra, isNull);
    });
  });
}
