import 'dart:async';

import 'package:chaput/chaput/application/chaput_decision_controller.dart';
import 'package:chaput/chaput/application/chaput_messages_controller.dart';
import 'package:chaput/chaput/application/chaput_threads_controller.dart';
import 'package:chaput/chaput/data/chaput_api.dart';
import 'package:chaput/chaput/data/chaput_socket.dart';
import 'package:chaput/chaput/domain/chaput_message.dart';
import 'package:chaput/chaput/domain/chaput_thread.dart';
import 'package:chaput/features/profile/presentation/utils/chaput_session_order.dart';
import 'package:chaput/features/user/data/user_api.dart';
import 'package:chaput/features/user/data/user_api_provider.dart';
import 'package:chaput/features/user/domain/lite_user.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ChaputThreadItem thread(
  String id, {
  String user = 'other',
  String state = 'OPEN',
}) => ChaputThreadItem(
  threadId: id,
  threadSlug: '',
  userAId: 'owner',
  userBId: user,
  starterId: user,
  kind: 'NORMAL',
  state: state,
  lastMessageAt: null,
  pendingExpiresAt: null,
  createdAt: null,
  x: null,
  y: null,
  z: null,
);

class _Api extends ChaputApi {
  _Api() : super(Dio());
  final threads =
      Completer<({List<ChaputThreadItem> items, String? nextCursor})>();
  final messages =
      Completer<({List<ChaputMessage> items, String? nextCursor})>();
  @override
  Future<({List<ChaputThreadItem> items, String? nextCursor})> listThreads({
    required String profileIdHex,
    int limit = 20,
    String? cursor,
  }) => threads.future;
  @override
  Future<({List<ChaputMessage> items, String? nextCursor})> listMessages({
    required String threadIdHex,
    String? profileIdHex,
    int limit = 30,
    String? cursor,
  }) => messages.future;
}

class _Users extends UserApi {
  _Users() : super(Dio());
  @override
  Future<({List<LiteUser> items, List<String> missingIds})> batchLite({
    required List<String> userIds,
  }) async => (items: <LiteUser>[], missingIds: <String>[]);
}

void main() {
  test(
    'archive removes thread immediately and stale API cannot restore it',
    () async {
      final api = _Api();
      final container = ProviderContainer(
        overrides: [
          chaputApiProvider.overrideWithValue(api),
          userApiProvider.overrideWithValue(_Users()),
        ],
      );
      addTearDown(container.dispose);
      final args = ChaputThreadsArgs(
        profileId: 'profile',
        viewerId: 'me',
        ownerId: 'owner',
        restricted: false,
      );
      final provider = chaputThreadsControllerProvider(args);
      container.listen(provider, (_, _) {});
      final ctrl = container.read(provider.notifier);
      ctrl.addThreadOptimistic(thread('archived'), args);
      ctrl.addThreadOptimistic(thread('keep'), args);
      ctrl.upsertThreadFromSocket(thread('archived', state: 'ARCHIVED'), args);
      expect(container.read(provider).items.map((t) => t.threadId), ['keep']);
      api.threads.complete((
        items: [thread('archived'), thread('keep')],
        nextCursor: null,
      ));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).items.map((t) => t.threadId), ['keep']);
      ctrl.upsertThreadFromSocket(thread('archived', state: 'PENDING'), args);
      expect(
        container.read(provider).items.length,
        2,
      ); // Explicit revival still works.
    },
  );

  test(
    'new-thread HTTP ID matches its socket event before optimistic insertion',
    () async {
      final dio = Dio();
      final id = 'ab' * 16;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {'ok': true, 'thread_id': id, 'already_exists': false},
              ),
            );
          },
        ),
      );
      final started = await ChaputApi(dio).startThread(profileIdHex: 'profile');
      final event = ChaputSocketEvent('chaput.thread.bump', {'thread_id': id});
      expect(started.threadId, event.data['thread_id']);
    },
  );

  test(
    'revive response provides immediate snapshot without a list reload',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {
                  'ok': true,
                  'thread': {
                    'thread_id': 'revived',
                    'user_a_id': 'owner',
                    'user_b_id': 'me',
                    'starter_id': 'me',
                    'state': 'PENDING',
                    'kind': 'NORMAL',
                    'pending_expires_at': '2026-09-18 12:00:00',
                  },
                },
              ),
            );
          },
        ),
      );
      final revived = await ChaputApi(dio).reviveThread(threadIdHex: 'revived');
      expect(revived!.threadId, 'revived');
      expect(revived.starterId, 'me');
      expect(revived.state, 'PENDING');
      expect(revived.pendingExpiresAt, DateTime.utc(2026, 9, 18, 12));
    },
  );

  test(
    'local selection promotes thread even if its socket event arrived first',
    () {
      final source = [thread('a'), thread('revived', user: 'me'), thread('b')];
      final local = orderChaputSession(
        previousIds: ['a', 'revived', 'b'],
        source: source,
        viewerId: 'me',
        createdThreadId: 'revived',
      );
      expect(local.map((t) => t.threadId), ['revived', 'a', 'b']);
      final remote = orderChaputSession(
        previousIds: ['a', 'revived', 'b'],
        source: source,
        viewerId: 'owner',
      );
      expect(remote.map((t) => t.threadId), ['a', 'revived', 'b']);
    },
  );

  test(
    'revival socket updates starter and expiry on an already visible thread',
    () {
      final api = _Api();
      final container = ProviderContainer(
        overrides: [chaputApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      final args = ChaputThreadsArgs(
        profileId: 'profile',
        viewerId: 'me',
        ownerId: 'owner',
        restricted: false,
      );
      final provider = chaputThreadsControllerProvider(args);
      container.listen(provider, (_, _) {});
      final ctrl = container.read(provider.notifier);
      ctrl.addThreadOptimistic(
        thread('revived', user: 'me').copyWith(starterId: 'owner'),
        args,
      );
      final deadline = DateTime.utc(2026, 9, 18, 12);
      ctrl.upsertThreadFromSocket(
        thread(
          'revived',
          user: 'me',
          state: 'PENDING',
        ).copyWith(pendingExpiresAt: deadline),
        args,
      );
      final revived = container.read(provider).items.single;
      expect(revived.starterId, 'me');
      expect(revived.pendingExpiresAt, deadline);
      expect(revived.state, 'PENDING');
    },
  );

  test('all socket event IDs match REST without modifying message text', () {
    final lower = 'ab' * 16;
    final upper = lower.toUpperCase();
    for (final type in [
      'chaput.message.created',
      'chaput.thread.bump',
      'chaput.typing',
      'chaput.message.read',
    ]) {
      final event = ChaputSocketEvent(type, {
        'thread_id': lower,
        'profile_id': lower,
        'user_id': lower,
        'message': {'id': lower, 'sender_id': lower, 'body': lower},
      });
      expect(event.data['thread_id'], upper);
      expect(event.data['profile_id'], upper);
      expect(event.data['user_id'], upper);
      expect(event.data['message']['id'], upper);
      expect(event.data['message']['body'], lower);
    }
    expect(
      ChaputMessagesArgs(threadId: lower, profileId: lower),
      ChaputMessagesArgs(threadId: upper, profileId: upper),
    );
  });

  test('new personal chaput is first; existing order stays fixed on bumps', () {
    final ordered = orderChaputSession(
      previousIds: ['a', 'b', 'c'],
      source: [
        thread('c'),
        thread('new', user: 'me'),
        thread('b'),
        thread('a'),
      ],
      viewerId: 'me',
    );
    expect(ordered.map((t) => t.threadId), ['new', 'a', 'b', 'c']);
    expect(ordered.indexWhere((t) => t.threadId == 'b'), 2);
    final bumped = orderChaputSession(
      previousIds: ordered.map((t) => t.threadId).toList(),
      source: [thread('b'), ...ordered.where((t) => t.threadId != 'b')],
      viewerId: 'me',
    );
    expect(bumped.map((t) => t.threadId), ['new', 'a', 'b', 'c']);
  });

  test(
    'new visitor chaput is inserted at ranked position without reordering old ones',
    () {
      final ordered = orderChaputSession(
        previousIds: ['a', 'b', 'c'],
        source: [thread('a'), thread('new'), thread('c'), thread('b')],
        viewerId: 'me',
      );
      expect(ordered.map((t) => t.threadId), ['a', 'b', 'new', 'c']);
    },
  );

  test(
    'slow initial API response cannot erase new chaputs or undo PENDING -> OPEN',
    () async {
      final api = _Api();
      final container = ProviderContainer(
        overrides: [
          chaputApiProvider.overrideWithValue(api),
          userApiProvider.overrideWithValue(_Users()),
        ],
      );
      addTearDown(container.dispose);
      final args = ChaputThreadsArgs(
        profileId: 'profile',
        viewerId: 'me',
        ownerId: 'owner',
        restricted: false,
      );
      final provider = chaputThreadsControllerProvider(args);
      container.listen(provider, (_, _) {});
      final controller = container.read(provider.notifier);
      controller.addThreadOptimistic(
        thread('pending', user: 'me', state: 'PENDING'),
        args,
      );
      controller.upsertThreadFromSocket(thread('pending', user: 'me'), args);
      controller.upsertThreadFromSocket(thread('new'), args);
      api.threads.complete((
        items: [thread('pending', user: 'me', state: 'PENDING')],
        nextCursor: null,
      ));
      await Future<void>.delayed(Duration.zero);
      final items = container.read(provider).items;
      expect(items.map((t) => t.threadId), containsAll(['pending', 'new']));
      expect(items.firstWhere((t) => t.threadId == 'pending').state, 'OPEN');
    },
  );

  test(
    'duplicate delivery and stale refresh cannot turn a blue tick back to unread',
    () async {
      final api = _Api();
      final container = ProviderContainer(
        overrides: [chaputApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      final args = ChaputMessagesArgs(threadId: 'thread', profileId: 'profile');
      final provider = chaputMessagesControllerProvider(args);
      container.listen(provider, (_, _) {});
      final ctrl = container.read(provider.notifier);
      ChaputMessage message(bool read) => ChaputMessage.fromJson({
        'id': 'message',
        'sender_id': 'sender',
        'body': 'reply',
        'read_by_other': read,
      });
      ctrl.upsertMessageFromSocket(message(true));
      ctrl.upsertMessageFromSocket(message(false));
      expect(container.read(provider).items.single.readByOther, isTrue);
      api.messages.complete((items: [message(false)], nextCursor: null));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).items.single.readByOther, isTrue);
    },
  );
}
