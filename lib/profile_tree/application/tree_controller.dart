import 'package:flutter_riverpod/flutter_riverpod.dart';

final treeControllerProvider =
AutoDisposeAsyncNotifierProviderFamily<TreeController, void, String>(TreeController.new);

class TreeController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build(String userId) async {
    // TODO: /profiles/:id/tree endpoint -> nodes + chaput list
    return null;
  }
}