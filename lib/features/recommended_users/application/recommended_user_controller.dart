import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../me/application/me_controller.dart';
import '../data/recommended_users_api.dart';
import '../domain/recommended_user.dart';

final recommendedUserControllerProvider =
    AsyncNotifierProvider<RecommendedUserController, RecommendedUser?>(
      RecommendedUserController.new,
    );

class RecommendedUserController extends AsyncNotifier<RecommendedUser?> {
  @override
  Future<RecommendedUser?> build() async {
    // Home açılınca otomatik çek
    return _fetch();
  }

  Future<RecommendedUser?> _fetch() async {
    final api = ref.read(recommendedUsersApiProvider);
    final u = await api.getRecommended();
    final me = ref.read(meControllerProvider).valueOrNull?.user;
    if (u != null && me != null) {
      final sameId = u.id.toLowerCase() == me.userId.toLowerCase();
      final sameUsername =
          (u.username ?? '').isNotEmpty &&
          u.username!.toLowerCase() == me.username.toLowerCase();
      if (sameId || sameUsername) {
        return null;
      }
    }
    return u;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}
