import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_api.dart';

final accountControllerProvider =
AutoDisposeNotifierProvider<AccountController, AsyncValue<void>>(
  AccountController.new,
);

class AccountController extends AutoDisposeNotifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> freezeMe() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(accountApiProvider);
      await api.freezeMe();
    });

    if (state.hasError) {
      throw state.error!;
      // stacktrace ile fırlatmak istersen:
      // Error.throwWithStackTrace(state.error!, state.stackTrace ?? StackTrace.current);
    }
  }

  Future<void> deleteMeHard() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(accountApiProvider);
      await api.deleteMeHard();
    });

    if (state.hasError) {
      throw state.error!;
      // veya:
      // Error.throwWithStackTrace(state.error!, state.stackTrace ?? StackTrace.current);
    }
  }
}
