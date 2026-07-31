import 'package:chaput/features/social/application/follow_controller.dart';
import 'package:chaput/features/social/application/follow_relationship_override.dart';
import 'package:chaput/features/social/application/follow_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('follow relationship overrides', () {
    test('seeds new follow controllers from a pending request override', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(followRelationshipOverridesProvider.notifier)
          .setForUser(
            userId: 'u1',
            username: 'Private_User',
            isFollowing: false,
            requestPending: true,
          );

      final state = container.read(followControllerProvider('private_user'));

      expect(state, isA<FollowIdle>());
      final idle = state as FollowIdle;
      expect(idle.isFollowing, isFalse);
      expect(idle.requestPending, isTrue);
    });

    test('normalizes followed users so pending request is cleared', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(followRelationshipOverridesProvider.notifier)
          .setForUser(
            userId: 'u1',
            username: 'followed_user',
            isFollowing: true,
            requestPending: true,
          );

      final override = followRelationshipOverrideFor(
        container.read(followRelationshipOverridesProvider),
        userId: 'u1',
        username: 'followed_user',
      );

      expect(override?.isFollowing, isTrue);
      expect(override?.requestPending, isFalse);
    });
  });
}
