import 'package:chaput/features/notifications/application/notifications_controller.dart';
import 'package:chaput/features/notifications/domain/notification_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AppNotification notification(String id, String type, int round) =>
    AppNotification.fromJson({
      'id': id,
      'type': type,
      'payload': {'game_id': 'pair', 'round': round},
    });

class _Seeded extends NotificationsController {
  @override
  NotificationsState build() => NotificationsState(
    items: [
      notification('result-1', 'rps_result', 1),
      notification('invite-2', 'rps_invite', 2),
    ],
  );
}

void main() {
  test(
    'socket results replace only their invitation and preserve all earlier results',
    () {
      final container = ProviderContainer(
        overrides: [notificationsControllerProvider.overrideWith(_Seeded.new)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        notificationsControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final controller = container.read(
        notificationsControllerProvider.notifier,
      );
      controller.addFromSocket(notification('result-2', 'rps_result', 2));
      controller.addFromSocket(notification('invite-3', 'rps_invite', 3));
      controller.addFromSocket(
        notification('invite-2', 'rps_invite', 2),
      ); // delayed duplicate
      controller.addFromSocket(notification('result-2', 'rps_result', 2));
      expect(
        container.read(notificationsControllerProvider).items.map((n) => n.id),
        ['invite-3', 'result-2', 'result-1'],
      );
    },
  );
}
