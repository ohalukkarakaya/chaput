import 'dart:async';
import 'package:chaput/features/notifications/application/notification_count_controller.dart';
import 'package:chaput/features/notifications/data/notification_api.dart';
import 'package:chaput/features/notifications/data/notification_api_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'resume refresh preserves count and cannot overwrite a newer socket count',
    () async {
      final api = _DelayedNotificationApi();
      final container = ProviderContainer(
        overrides: [notificationApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      container.listen(notificationCountControllerProvider, (_, _) {});
      api.pending.removeAt(0).complete(7);
      await Future<void>.delayed(Duration.zero);
      final ctrl = container.read(notificationCountControllerProvider.notifier);
      final refresh = ctrl.refresh();
      expect(container.read(notificationCountControllerProvider), 7);
      ctrl.updateFromSocket(8);
      api.pending.removeAt(0).complete(7);
      await refresh;
      expect(container.read(notificationCountControllerProvider), 8);
    },
  );

  test(
    'updates in-app unread count without writing the app icon badge',
    () async {
      const channel = MethodChannel('chaput/notifications');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final container = ProviderContainer(
        overrides: [
          notificationApiProvider.overrideWithValue(_FakeNotificationApi(7)),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        notificationCountControllerProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await Future<void>.delayed(Duration.zero);
      expect(container.read(notificationCountControllerProvider), 7);

      final controller = container.read(
        notificationCountControllerProvider.notifier,
      );
      controller.updateFromSocket(3);
      expect(container.read(notificationCountControllerProvider), 3);

      controller.decrementIfUnread();
      expect(container.read(notificationCountControllerProvider), 2);

      controller.decrementBy(5);
      expect(container.read(notificationCountControllerProvider), 0);

      expect(calls, isEmpty);
    },
  );
}

class _DelayedNotificationApi extends NotificationApi {
  _DelayedNotificationApi() : super(Dio());
  final pending = <Completer<int>>[];
  @override
  Future<int> countUnread() {
    final result = Completer<int>();
    pending.add(result);
    return result.future;
  }
}

class _FakeNotificationApi extends NotificationApi {
  _FakeNotificationApi(this._count) : super(Dio());

  final int _count;

  @override
  Future<int> countUnread() async => _count;
}
