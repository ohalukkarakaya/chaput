import 'package:dio/dio.dart';

import '../domain/chaput_decision.dart';
import '../domain/chaput_message.dart';
import '../domain/chaput_thread.dart';

class ChaputApi {
  ChaputApi(this._dio);

  final Dio _dio;

  Future<ChaputDecision> getDecision(String profileIdHex) async {
    final res = await _dio.get('/chaput/decision/$profileIdHex');
    final data = res.data;
    if (data is Map<String, dynamic>) {
      if (data['ok'] == true) {
        return ChaputDecision.fromJson(data);
      }
      throw Exception(data['error'] ?? 'decision_error');
    }
    throw Exception('bad_decision_response');
  }

  Future<({List<ChaputThreadItem> items, String? nextCursor})> listThreads({
    required String profileIdHex,
    int limit = 20,
    String? cursor,
  }) async {
    final res = await _dio.get(
      '/chaput/profile/$profileIdHex/threads',
      queryParameters: {
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      if (data['ok'] == true) {
        final itemsJson = (data['items'] as List?) ?? const [];
        final items = itemsJson
            .map((e) => ChaputThreadItem.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
        return (items: items, nextCursor: data['next_cursor']?.toString());
      }
      throw Exception(data['error'] ?? 'threads_error');
    }
    throw Exception('bad_threads_response');
  }

  Future<({List<ChaputMessage> items, String? nextCursor})> listMessages({
    required String threadIdHex,
    String? profileIdHex,
    int limit = 30,
    String? cursor,
  }) async {
    final res = await _dio.get(
      '/chaput/threads/$threadIdHex/messages',
      queryParameters: {
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        if (profileIdHex != null && profileIdHex.isNotEmpty) 'profile_id': profileIdHex,
      },
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      if (data['ok'] == true) {
        final itemsJson = (data['items'] as List?) ?? const [];
        final items = itemsJson
            .map((e) => ChaputMessage.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
        return (items: items, nextCursor: data['next_cursor']?.toString());
      }
      throw Exception(data['error'] ?? 'messages_error');
    }
    throw Exception('bad_messages_response');
  }

  Future<void> recordView({
    required String threadIdHex,
  }) async {
    final res = await _dio.post('/chaput/threads/$threadIdHex/view');
    final data = res.data;
    if (data is Map<String, dynamic> && data['ok'] == true) return;
    if (data is Map<String, dynamic>) {
      throw Exception(data['error'] ?? 'view_error');
    }
    throw Exception('bad_view_response');
  }

  Future<({String threadId, bool alreadyExists})> startThread({
    required String profileIdHex,
    String? kind,
  }) async {
    final payload = <String, dynamic>{};
    if (kind != null && kind.isNotEmpty) {
      payload['kind'] = kind;
    }
    final res = await _dio.post(
      '/chaput/profile/$profileIdHex/start',
      data: payload.isEmpty ? null : payload,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      if (data['ok'] == true) {
        return (
          threadId: data['thread_id']?.toString() ?? '',
          alreadyExists: data['already_exists'] == true,
        );
      }
      throw Exception(data['error'] ?? 'start_error');
    }
    throw Exception('bad_start_response');
  }

  Future<void> sendMessage({
    required String threadIdHex,
    required String body,
    String? kind,
  }) async {
    final payload = <String, dynamic>{'body': body};
    if (kind != null && kind.isNotEmpty) {
      payload['kind'] = kind;
    }
    final res = await _dio.post('/chaput/threads/$threadIdHex/messages', data: payload);
    final data = res.data;
    if (data is Map<String, dynamic> && data['ok'] == true) {
      return;
    }
    if (data is Map<String, dynamic>) {
      throw Exception(data['error'] ?? 'send_error');
    }
    throw Exception('bad_send_response');
  }

  Future<bool> setThreadNode({
    required String threadIdHex,
    required String profileIdHex,
    required double x,
    required double y,
    required double z,
  }) async {
    final res = await _dio.post(
      '/chaput/threads/$threadIdHex/node',
      data: {
        'profile_id': profileIdHex,
        'x': x,
        'y': y,
        'z': z,
      },
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      if (data['ok'] == true) {
        return data['set'] == true;
      }
      throw Exception(data['error'] ?? 'node_error');
    }
    throw Exception('bad_node_response');
  }

  Future<void> reviveThread({
    required String threadIdHex,
  }) async {
    final res = await _dio.post('/chaput/threads/$threadIdHex/revive');
    final data = res.data;
    if (data is Map<String, dynamic> && data['ok'] == true) return;
    if (data is Map<String, dynamic>) {
      throw Exception(data['error'] ?? 'revive_error');
    }
    throw Exception('bad_revive_response');
  }

  Future<void> hideThread({
    required String threadIdHex,
  }) async {
    final res = await _dio.post('/chaput/threads/$threadIdHex/hide');
    final data = res.data;
    if (data is Map<String, dynamic> && data['ok'] == true) {
      return;
    }
    if (data is Map<String, dynamic>) {
      throw Exception(data['error'] ?? 'hide_error');
    }
    throw Exception('bad_hide_response');
  }

  Future<bool> watchAd() async {
    final res = await _dio.post('/chaput/ads/watch');
    final data = res.data;
    if (data is Map<String, dynamic>) {
      if (data['ok'] == true) return true;
      return false;
    }
    throw Exception('bad_watch_response');
  }

  Future<String> startAdRewardSession({
    String network = 'FAKE',
    String rewardType = 'CHAPUT_BIND',
    int requiredAds = 1,
  }) async {
    final res = await _dio.post('/chaput/ads/reward/start', data: {
      'network': network,
      'reward_type': rewardType,
      'required_ads': requiredAds,
    });
    final data = res.data;
    if (data is Map<String, dynamic>) {
      if (data['ok'] == true) {
        return data['session_id']?.toString() ?? '';
      }
      throw Exception(data['error'] ?? 'ad_start_failed');
    }
    throw Exception('bad_ad_start_response');
  }

  Future<({int watchedToday, bool canWatch})> claimAdReward({
    required String sessionId,
    required int watchedCount,
  }) async {
    final res = await _dio.post('/chaput/ads/reward/claim', data: {
      'session_id': sessionId,
      'watched_count': watchedCount,
    });
    final data = res.data;
    if (data is Map<String, dynamic>) {
      if (data['ok'] == true) {
        return (
          watchedToday: (data['watched_today'] as num?)?.toInt() ?? 0,
          canWatch: data['can_watch'] == true,
        );
      }
      throw Exception(data['error'] ?? 'ad_claim_failed');
    }
    throw Exception('bad_ad_claim_response');
  }
}
