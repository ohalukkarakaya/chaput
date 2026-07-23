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
  Future<void>? _connectFuture;
  final Set<String> _profileSubscriptions = <String>{};
  final Map<String, String?> _threadSubscriptions = <String, String?>{};
  bool _disposed = false;
  bool _isReady = false;
  bool _suspended = false;
  Timer? _reconnectTimer;

  Stream<ChaputSocketEvent> get events => _events.stream;

  Future<void> ensureConnected() async {
    if (_disposed || _suspended) return;
    final inFlight = _connectFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    if (_channel != null) return;

    final completer = Completer<void>();
    _connectFuture = completer.future;

    try {
      final token = await _storage.readAccessToken();
      if (_disposed || _suspended || token == null || token.isEmpty) {
        _cleanup();
        completer.complete();
        return;
      }

      final api = Uri.parse(Env.apiBaseUrl);
      final ws = api.replace(
        scheme: api.scheme == 'https' ? 'wss' : 'ws',
        path: '/ws/chaput',
        queryParameters: {'token': token},
      );

      final channel = WebSocketChannel.connect(ws);
      _channel = channel;
      _isReady = false;
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
        onDone: _handleDisconnect,
        onError: (_, _) => _handleDisconnect(),
      );

      await channel.ready;
      if (_disposed || _suspended || _channel != channel) {
        _cleanup(scheduleReconnect: false);
        if (!completer.isCompleted) {
          completer.complete();
        }
        return;
      }
      _isReady = true;
      _flushSubscriptions();
      completer.complete();
    } catch (_) {
      _cleanup();
      if (!completer.isCompleted) {
        completer.complete();
      }
    } finally {
      _connectFuture = null;
    }
  }

  void _handleDisconnect() {
    _cleanup();
  }

  void _cleanup({bool scheduleReconnect = true}) {
    _sub?.cancel();
    _sub = null;
    _isReady = false;
    final ch = _channel;
    _channel = null;
    try {
      ch?.sink.close();
    } catch (_) {}
    if (scheduleReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_disposed || _suspended) return;
    if (_profileSubscriptions.isEmpty && _threadSubscriptions.isEmpty) return;
    _reconnectTimer = Timer(const Duration(milliseconds: 600), () {
      if (_disposed || _suspended || _channel != null) return;
      unawaited(ensureConnected());
    });
  }

  void suspendForBackground() {
    _suspended = true;
    _reconnectTimer?.cancel();
    _cleanup(scheduleReconnect: false);
  }

  Future<void> resumeFromBackground() async {
    if (_disposed) return;
    _suspended = false;
    await ensureConnected();
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _cleanup(scheduleReconnect: false);
    _events.close();
  }

  void subscribeProfile(String profileId) {
    if (profileId.isEmpty) return;
    _profileSubscriptions.add(profileId);
    _send({'type': 'subscribe_profile', 'profile_id': profileId});
  }

  void unsubscribeProfile(String profileId) {
    if (profileId.isEmpty) return;
    _profileSubscriptions.remove(profileId);
    _send({
      'type': 'unsubscribe_profile',
      'profile_id': profileId,
    }, reconnectIfDisconnected: false);
  }

  void subscribeThread(String threadId, {String? profileId}) {
    if (threadId.isEmpty) return;
    _threadSubscriptions[threadId] = profileId;
    final payload = <String, dynamic>{
      'type': 'subscribe_thread',
      'thread_id': threadId,
    };
    if (profileId != null && profileId.isNotEmpty) {
      payload['profile_id'] = profileId;
    }
    _send(payload);
  }

  void unsubscribeThread(String threadId) {
    if (threadId.isEmpty) return;
    _threadSubscriptions.remove(threadId);
    _send({
      'type': 'unsubscribe_thread',
      'thread_id': threadId,
    }, reconnectIfDisconnected: false);
  }

  void sendTyping(String threadId, bool isTyping) {
    if (threadId.isEmpty) return;
    _send({'type': 'typing', 'thread_id': threadId, 'is_typing': isTyping});
  }

  void _send(Map<String, dynamic> data, {bool reconnectIfDisconnected = true}) {
    if (_disposed || _suspended) return;
    if (!_isReady) {
      if (reconnectIfDisconnected) {
        unawaited(ensureConnected());
      }
      return;
    }
    final ch = _channel;
    if (ch == null) {
      if (reconnectIfDisconnected) {
        unawaited(ensureConnected());
      }
      return;
    }
    try {
      ch.sink.add(jsonEncode(data));
    } catch (_) {
      _cleanup();
    }
  }

  void _flushSubscriptions() {
    for (final profileId in _profileSubscriptions) {
      _send({
        'type': 'subscribe_profile',
        'profile_id': profileId,
      }, reconnectIfDisconnected: false);
    }
    for (final entry in _threadSubscriptions.entries) {
      final payload = <String, dynamic>{
        'type': 'subscribe_thread',
        'thread_id': entry.key,
      };
      final profileId = entry.value;
      if (profileId != null && profileId.isNotEmpty) {
        payload['profile_id'] = profileId;
      }
      _send(payload, reconnectIfDisconnected: false);
    }
  }
}

final chaputSocketProvider = Provider<ChaputSocketClient>((ref) {
  final storage = ref.read(tokenStorageProvider);
  final client = ChaputSocketClient(storage);
  ref.onDispose(client.dispose);
  return client;
});
