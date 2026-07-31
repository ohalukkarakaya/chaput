import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/network/dio_provider.dart';
import '../data/follow_api.dart';
import 'follow_relationship_override.dart';
import 'follow_state.dart';

final followApiProvider = Provider<FollowApi>((ref) {
  final dio = ref.watch(dioProvider);
  return FollowApi(dio);
});

final followControllerProvider = NotifierProvider.autoDispose
    .family<FollowController, FollowState, String>(FollowController.new);

class FollowController extends Notifier<FollowState> {
  FollowController(this.arg);

  final String arg;

  @override
  FollowState build() {
    final override = ref.watch(
      followRelationshipOverridesProvider.select(
        (overrides) => followRelationshipOverrideFor(overrides, username: arg),
      ),
    );
    return FollowIdle(
      isFollowing: override?.isFollowing,
      requestPending: override?.requestPending,
    );
  }

  Future<void> follow() async {
    state = const FollowLoading();
    try {
      final api = ref.read(followApiProvider);
      final res = await api.follow(arg);

      final nextState = FollowIdle(
        isFollowing: res.followed,
        requestPending: res.requestCreated,
      );
      ref
          .read(followRelationshipOverridesProvider.notifier)
          .setForUser(
            username: arg,
            isFollowing: nextState.isFollowing == true,
            requestPending: nextState.requestPending == true,
          );
      state = nextState;
    } on DioException catch (e) {
      final code = extractFollowErrorCode(e);
      state = FollowError(code);
      throw FollowActionException(code);
    }
  }

  Future<void> unfollow() async {
    state = const FollowLoading();
    try {
      final api = ref.read(followApiProvider);
      await api.unfollow(arg);
      ref
          .read(followRelationshipOverridesProvider.notifier)
          .setForUser(username: arg, isFollowing: false, requestPending: false);
      state = const FollowIdle(isFollowing: false);
    } on DioException catch (e) {
      final code = extractFollowErrorCode(e);
      state = FollowError(code);
      throw FollowActionException(code);
    }
  }
}

class FollowActionException implements Exception {
  const FollowActionException(this.code);

  final String code;

  @override
  String toString() => 'FollowActionException($code)';
}
