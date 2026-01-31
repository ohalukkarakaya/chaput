import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/env.dart';
import '../../core/storage/token_storage.dart';
import '../../core/storage/secure_storage_provider.dart';

class ChaputSocketEvent {
  ChaputSocketEvent(this.type, this.data);
  final String type;
  final Map<String, dynamic> data;
}

class ChaputSocketClient {
  ChaputSocketClient(this._storage);

  final TokenStorage _storage;
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _events = StreamController<ChaputSocketEvent>.broadcast();

  Stream<ChaputSocketEvent> get events => _events.stream;

  Future<void> ensureConnected() async {
    if (_channel != null) return;
    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) return;
    final api = Uri.parse(Env.apiBaseUrl);
    final ws = api.replace(
      scheme: api.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/chaput',
      queryParameters: {'token': token},
    );
    final channel = WebSocketChannel.connect(ws);
    _channel = channel;
    _sub = channel.stream.listen(
      (event) {
        if (event is String) {
          final obj = jsonDecode(event);
          if (obj is Map<String, dynamic>) {
            final type = obj['type']?.toString() ?? '';
            _events.add(ChaputSocketEvent(type, obj));
          }
        }
      },
      onDone: _cleanup,
      onError: (_) => _cleanup(),
    );
  }

  void _cleanup() {
    _sub?.cancel();
    _sub = null;
    _channel = null;
  }

  void dispose() {
    _cleanup();
    _events.close();
  }

  void subscribeProfile(String profileId) {
    _send({'type': 'subscribe_profile', 'profile_id': profileId});
  }

  void unsubscribeProfile(String profileId) {
    _send({'type': 'unsubscribe_profile', 'profile_id': profileId});
  }

  void subscribeThread(String threadId, {String? profileId}) {
    final payload = <String, dynamic>{'type': 'subscribe_thread', 'thread_id': threadId};
    if (profileId != null && profileId.isNotEmpty) {
      payload['profile_id'] = profileId;
    }
    _send(payload);
  }

  void unsubscribeThread(String threadId) {
    _send({'type': 'unsubscribe_thread', 'thread_id': threadId});
  }

  void sendTyping(String threadId, bool isTyping) {
    _send({'type': 'typing', 'thread_id': threadId, 'is_typing': isTyping});
  }

  void _send(Map<String, dynamic> data) {
    final ch = _channel;
    if (ch == null) return;
    ch.sink.add(jsonEncode(data));
  }
}

final chaputSocketProvider = Provider<ChaputSocketClient>((ref) {
  final storage = ref.read(tokenStorageProvider);
  final client = ChaputSocketClient(storage);
  ref.onDispose(client.dispose);
  return client;
});
