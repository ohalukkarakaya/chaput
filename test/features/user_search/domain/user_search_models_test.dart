import 'package:chaput/features/user_search/domain/user_search_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserSearchItem.fromJson', () {
    test('reads pending follow request from viewer state aliases', () {
      final user = UserSearchItem.fromJson({
        'id': 'u1',
        'username': 'private_user',
        'full_name': 'Private User',
        'default_avatar': '',
        'is_public': false,
        'viewer_state': {'i_requested_follow': true},
      });

      expect(user.requestPending, isTrue);
      expect(user.isFollowing, isFalse);
    });

    test('following overrides pending request flags', () {
      final user = UserSearchItem.fromJson({
        'id': 'u2',
        'username': 'followed_user',
        'full_name': 'Followed User',
        'default_avatar': '',
        'is_public': true,
        'request_pending': true,
        'viewer_state': {'is_following': true, 'i_requested_follow': true},
      });

      expect(user.isFollowing, isTrue);
      expect(user.requestPending, isFalse);
    });
  });
}
