import 'package:chaput/features/social/application/follow_relationship_override.dart';
import 'package:chaput/features/user_search/application/user_search_controller.dart';
import 'package:chaput/features/user_search/data/user_search_api.dart';
import 'package:chaput/features/user_search/domain/user_search_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'applies local pending follow request over stale discover results',
    () async {
      final container = ProviderContainer(
        overrides: [
          userSearchApiProvider.overrideWithValue(
            _FakeUserSearchApi(
              discoverResponse: UserSearchResponse(
                ok: true,
                items: [
                  UserSearchItem(
                    id: 'u1',
                    fullName: 'Private User',
                    username: 'private_user',
                    defaultAvatar: '',
                    profilePhotoKey: null,
                    isPublic: false,
                  ),
                ],
                nextCursor: null,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(followRelationshipOverridesProvider.notifier)
          .setForUser(
            userId: 'u1',
            username: 'private_user',
            isFollowing: false,
            requestPending: true,
          );

      await container
          .read(userSearchControllerProvider.notifier)
          .loadDiscoverFirstPage();

      final item = container.read(userSearchControllerProvider).items.single;
      expect(item.isFollowing, isFalse);
      expect(item.requestPending, isTrue);
    },
  );
}

class _FakeUserSearchApi extends UserSearchApi {
  _FakeUserSearchApi({required this.discoverResponse}) : super(Dio());

  final UserSearchResponse discoverResponse;

  @override
  Future<UserSearchResponse> discover({
    required int limit,
    String? cursor,
  }) async {
    return discoverResponse;
  }
}
