import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_api_provider.dart';

final notificationCountControllerProvider =
    AutoDisposeNotifierProvider<NotificationCountController, int>(
  NotificationCountController.new,
);

class NotificationCountController extends AutoDisposeNotifier<int> {
  @override
  int build() {
    _refresh();
    return 0;
  }

  Future<void> _refresh() async {
    try {
      final c = await ref.read(notificationApiProvider).countUnread();
      state = c;
    } catch (e, st) {
      log('notif count error: $e', stackTrace: st);
    }
  }

  Future<void> refresh() => _refresh();

  void updateFromSocket(int? count) {
    if (count == null) return;
    state = count;
  }

  void decrementIfUnread() {
    if (state > 0) state = state - 1;
  }
}
