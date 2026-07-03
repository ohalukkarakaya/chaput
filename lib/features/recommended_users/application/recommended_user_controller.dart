import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../me/application/me_controller.dart';
import '../data/recommended_users_api.dart';
import '../domain/recommended_user.dart';

final recommendedUserControllerProvider =
    AsyncNotifierProvider<RecommendedUserController, List<RecommendedUser>>(
      RecommendedUserController.new,
    );

class RecommendedUserController extends AsyncNotifier<List<RecommendedUser>> {
  @override
  Future<List<RecommendedUser>> build() async {
    return _fetch();
  }

  Future<List<RecommendedUser>> _fetch() async {
    final api = ref.read(recommendedUsersApiProvider);
    final items = await api.getRecommended();
    final me = ref.read(meControllerProvider).valueOrNull?.user;
    if (me == null) {
      return items;
    }

    final meId = me.userId.toLowerCase();
    final meUsername = me.username.toLowerCase();
    return items
        .where((u) {
          final sameId = u.id.toLowerCase() == meId;
          final sameUsername =
              (u.username ?? '').isNotEmpty &&
              u.username!.toLowerCase() == meUsername;
          return !sameId && !sameUsername;
        })
        .toList(growable: false);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}
