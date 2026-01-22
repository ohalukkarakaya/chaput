import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/restrictions_api.dart';

sealed class RestrictActionState {
  const RestrictActionState();
}

class RestrictIdle extends RestrictActionState {
  const RestrictIdle();
}

class RestrictLoading extends RestrictActionState {
  const RestrictLoading();
}

class RestrictError extends RestrictActionState {
  const RestrictError(this.message);
  final String message;
}

final restrictionsControllerProvider =
AutoDisposeNotifierProvider<RestrictionsController, RestrictActionState>(
  RestrictionsController.new,
);

class RestrictionsController extends AutoDisposeNotifier<RestrictActionState> {
  @override
  RestrictActionState build() => const RestrictIdle();

  /// returns new restricted state
  Future<bool> toggle(String userHex) async {
    if (state is RestrictLoading) return false;
    state = const RestrictLoading();
    try {
      final api = ref.read(restrictionsApiProvider);
      final restricted = await api.toggle(userHex: userHex);
      state = const RestrictIdle();
      return restricted;
    } catch (e) {
      state = RestrictError(e.toString());
      rethrow;
    }
  }
}