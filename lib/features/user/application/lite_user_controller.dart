import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/user_api_provider.dart';
import '../domain/lite_user.dart';

final liteUserControllerProvider =
StateNotifierProvider.family<LiteUserController, AsyncValue<LiteUser?>, String>(
      (ref, userId) => LiteUserController(ref, userId),
);

class LiteUserController extends StateNotifier<AsyncValue<LiteUser?>> {
  LiteUserController(this._ref, this._userId) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;
  final String _userId;

  Future<void> load() async {
    try {
      final api = _ref.read(userApiProvider);
      final res = await api.batchLite(userIds: [_userId]);

      // user yoksa: null
      final user = res.items.isEmpty ? null : res.items.first;
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}