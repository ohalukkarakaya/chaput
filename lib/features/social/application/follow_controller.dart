import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/network/dio_provider.dart';
import '../data/follow_api.dart';
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
    return const FollowIdle();
  }

  Future<void> follow() async {
    state = const FollowLoading();
    try {
      final api = ref.read(followApiProvider);
      final res = await api.follow(arg);

      state = FollowIdle(
        isFollowing: res.followed,
        requestPending: res.requestCreated,
      );
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
