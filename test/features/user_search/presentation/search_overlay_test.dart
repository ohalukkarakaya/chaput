import 'package:chaput/features/profile/domain/profile_preview.dart';
import 'package:chaput/features/user_search/presentation/search_overlay.dart';
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
  group('mergeDiscoverProfileState', () {
    test('keeps local history following state over stale discover state', () {
      final merged = mergeDiscoverProfileState(
        _preview(id: 'u1'),
        _preview(id: 'u1', isFollowing: true),
      );

      expect(merged.isFollowing, isTrue);
      expect(merged.requestPending, isFalse);
    });

    test('keeps local history request state over stale discover state', () {
      final merged = mergeDiscoverProfileState(
        _preview(id: 'u1'),
        _preview(id: 'u1', requestPending: true),
      );

      expect(merged.isFollowing, isFalse);
      expect(merged.requestPending, isTrue);
    });
  });
}
