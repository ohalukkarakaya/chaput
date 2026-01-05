import 'package:flutter_riverpod/flutter_riverpod.dart';

final chaputControllerProvider =
AutoDisposeAsyncNotifierProviderFamily<ChaputController, void, String>(ChaputController.new);

class ChaputController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build(String chaputId) async {
    // TODO: chaput detail fetch
  }
}