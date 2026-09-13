import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_api.dart';

final accountControllerProvider =
    NotifierProvider.autoDispose<AccountController, AsyncValue<void>>(
      AccountController.new,
    );

class AccountController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> freezeMe() => _run((api) => api.freezeMe());

  Future<void> deleteMeHard({required String reason}) =>
      _run((api) => api.deleteMeHard(reason: reason));

  Future<void> _run(Future<void> Function(AccountApi api) operation) async {
    // Settings reads this auto-dispose notifier without subscribing to it.
    final link = ref.keepAlive();
    try {
      state = const AsyncLoading();
      final result = await AsyncValue.guard(
        () => operation(ref.read(accountApiProvider)),
      );
      if (ref.mounted) state = result;
      if (result.hasError) {
        Error.throwWithStackTrace(result.error!, result.stackTrace!);
      }
    } finally {
      link.close();
    }
  }
}
