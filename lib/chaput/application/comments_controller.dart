import 'package:flutter_riverpod/flutter_riverpod.dart';

final commentsControllerProvider =
AutoDisposeAsyncNotifierProviderFamily<CommentsController, void, String>(CommentsController.new);

class CommentsController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build(String chaputId) async {
    // TODO: cursor pagination comments
  }
}