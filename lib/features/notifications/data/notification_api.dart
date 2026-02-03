import 'package:dio/dio.dart';

class NotificationApi {
  NotificationApi(this._dio);
  final Dio _dio;

  Future<({List<Map<String, dynamic>> items, String? nextCursor})> list({
    String? cursor,
    int limit = 20,
  }) async {
    final res = await _dio.get('/me/notifications', queryParameters: {
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      'limit': limit,
    });

    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'bad_request');
    }
    final items = ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);
    final nextCursor = data['next_cursor']?.toString();
    return (items: items, nextCursor: nextCursor == 'null' ? null : nextCursor);
  }

  Future<int> countUnread() async {
    final res = await _dio.get('/me/notifications/unread-count');
    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'bad_request');
    }
    return (data['unread'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) async {
    await _dio.post('/me/notifications/$id/read');
  }

  Future<bool> approveFollowRequest(int requestSeq) async {
    final res = await _dio.post(
      '/me/follow-requests/$requestSeq/approve',
      options: Options(
        validateStatus: (code) =>
            code == null || (code >= 200 && code < 300) || code == 404,
      ),
    );
    final code = res.statusCode ?? 0;
    return code >= 200 && code < 300;
  }

  Future<void> upsertPushToken({
    required String token,
    required String platform,
    required String deviceId,
  }) async {
    await _dio.post('/me/push-tokens', data: {
      'token': token,
      'platform': platform,
      'device_id': deviceId,
    });
  }
}
