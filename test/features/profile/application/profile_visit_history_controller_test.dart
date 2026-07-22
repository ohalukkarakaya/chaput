import 'package:chaput/features/profile/application/profile_visit_history_controller.dart';
import 'package:chaput/features/profile/domain/profile_preview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProfilePreview _preview({
  required String id,
  bool isFollowing = false,
  bool requestPending = false,
}) {
  return ProfilePreview(
    id: id,
    username: 'user_$id',
    fullName: 'User $id',
    defaultAvatar: '',
    profilePhotoKey: null,
    profilePhotoUrl: null,
    isPublic: true,
    isFollowing: isFollowing,
    requestPending: requestPending,
  );
}

void main() {
  test('updates follow state for a previously visited profile', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(profileVisitHistoryProvider.notifier)
        .record(_preview(id: 'u1'));
    container
        .read(profileVisitHistoryProvider.notifier)
        .updateFollowState(_preview(id: 'u1', isFollowing: true));

    final item = container.read(profileVisitHistoryProvider).single;
    expect(item.id, 'u1');
    expect(item.isFollowing, isTrue);
    expect(item.requestPending, isFalse);
  });

  test('updates pending request state for a previously visited profile', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(profileVisitHistoryProvider.notifier)
        .record(_preview(id: 'u1'));
    container
        .read(profileVisitHistoryProvider.notifier)
        .updateFollowState(_preview(id: 'u1', requestPending: true));

    final item = container.read(profileVisitHistoryProvider).single;
    expect(item.isFollowing, isFalse);
    expect(item.requestPending, isTrue);
  });
}
