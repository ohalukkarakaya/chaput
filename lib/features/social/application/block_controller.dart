import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../settings/data/blocks_api.dart';

sealed class BlockActionState {
  const BlockActionState();
}
class BlockActionIdle extends BlockActionState {
  const BlockActionIdle();
}
class BlockActionLoading extends BlockActionState {
  const BlockActionLoading();
}
class BlockActionError extends BlockActionState {
  const BlockActionError(this.message);
  final String message;
}

final blockControllerProvider =
AutoDisposeNotifierProvider<BlockController, BlockActionState>(
  BlockController.new,
);

class BlockController extends AutoDisposeNotifier<BlockActionState> {
  @override
  BlockActionState build() => const BlockActionIdle();

  Future<void> blockUser(String username) async {
    if (state is BlockActionLoading) return;
    state = const BlockActionLoading();
    try {
      final api = ref.read(blocksApiProvider);
      await api.blockByUsername(username);
      state = const BlockActionIdle();
    } catch (e) {
      state = BlockActionError(_mapErr(e));
      rethrow;
    }
  }

  String _mapErr(Object e) {
    // Backend: user_not_found, cannot_block_self, vs...
    // Dio error body’nizi biliyorsan burada parse et
    return e.toString();
  }
}