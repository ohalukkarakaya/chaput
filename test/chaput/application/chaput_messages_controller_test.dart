import 'dart:async';

import 'package:chaput/chaput/application/chaput_decision_controller.dart';
import 'package:chaput/chaput/application/chaput_messages_controller.dart';
import 'package:chaput/chaput/data/chaput_api.dart';
import 'package:chaput/chaput/domain/chaput_message.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keeps socket messages when initial API load returns stale data',
    () async {
      final api = _FakeChaputApi();
      final container = ProviderContainer(
        overrides: [chaputApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);

      final args = ChaputMessagesArgs(
        threadId: 'thread1',
        profileId: 'profile1',
      );
      final sub = container.listen(
        chaputMessagesControllerProvider(args),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);

      final socketMessage = _message(
        id: 'socket_message',
        createdAt: DateTime.utc(2026, 8, 9, 12),
      );
      container
          .read(chaputMessagesControllerProvider(args).notifier)
          .upsertMessageFromSocket(socketMessage);

      api.completeListMessages([
        _message(id: 'older_message', createdAt: DateTime.utc(2026, 8, 9, 11)),
      ]);
      await Future<void>.delayed(Duration.zero);

      final ids = container
          .read(chaputMessagesControllerProvider(args))
          .items
          .map((message) => message.id)
          .toList(growable: false);

      expect(ids, ['socket_message', 'older_message']);
    },
  );
}

ChaputMessage _message({required String id, required DateTime createdAt}) {
  return ChaputMessage(
    id: id,
    senderId: 'sender1',
    kind: 'NORMAL',
    body: 'hello',
    createdAt: createdAt,
    replyToId: null,
    replyToSenderId: null,
    replyToBody: null,
    likeCount: 0,
    likedByMe: false,
    delivered: true,
    readByOther: false,
    topLikers: const [],
  );
}

class _FakeChaputApi extends ChaputApi {
  _FakeChaputApi() : super(Dio());

  final _listMessages =
      Completer<({List<ChaputMessage> items, String? nextCursor})>();

  void completeListMessages(List<ChaputMessage> items) {
    _listMessages.complete((items: items, nextCursor: null));
  }

  @override
  Future<({List<ChaputMessage> items, String? nextCursor})> listMessages({
    required String threadIdHex,
    String? profileIdHex,
    int limit = 30,
    String? cursor,
  }) {
    return _listMessages.future;
  }
}
