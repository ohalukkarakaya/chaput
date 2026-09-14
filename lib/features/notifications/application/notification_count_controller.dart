import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_api_provider.dart';

final notificationCountControllerProvider =
    NotifierProvider.autoDispose<NotificationCountController, int>(
      NotificationCountController.new,
    );

class NotificationCountController extends Notifier<int> {
  int _revision = 0;
  int _request = 0;
  @override
  int build() {
    _refresh();
    return 0;
  }

  Future<void> _refresh() async {
    final revision = _revision;
    final request = ++_request;
    try {
      final c = await ref.read(notificationApiProvider).countUnread();
      if (!ref.mounted || revision != _revision || request != _request) return;
      state = c < 0 ? 0 : c;
    } catch (e, st) {
      log('notif count error: $e', stackTrace: st);
    }
  }

  Future<void> refresh() => _refresh();

  void updateFromSocket(int? count) {
    if (count == null) return;
    _revision++;
    final normalized = count < 0 ? 0 : count;
    state = normalized;
  }

  void decrementIfUnread() {
    if (state <= 0) return;
    _revision++;
    final next = state - 1;
    state = next;
  }

  void decrementBy(int count) {
    if (count <= 0 || state <= 0) return;
    _revision++;
    final next = state - count;
    final normalized = next < 0 ? 0 : next;
    state = normalized;
  }
}
