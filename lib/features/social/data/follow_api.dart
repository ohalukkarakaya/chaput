import 'package:dio/dio.dart';

class FollowApi {
  FollowApi(this._dio);
  final Dio _dio;

  /// POST /users/{username}/follow
  Future<FollowResult> follow(String username) async {
    final res = await _dio.post('/users/$username/follow');
    final data = res.data as Map<String, dynamic>;

    return FollowResult(
      followed: data['followed'] == true,
      requestCreated: data['request_created'] == true,
    );
  }

  /// DELETE /users/{username}/follow
  Future<void> unfollow(String username) async {
    await _dio.delete('/users/$username/follow');
  }

  Future<({List<Map<String, dynamic>> items, int nextAfter})> listFollowers({
    required String username,
    required int after,
    required int limit,
  }) async {
    final res = await _dio.get(
      '/users/$username/followers',
      queryParameters: {
        'after': after,
        'limit': limit,
      },
      options: Options(validateStatus: (s) => s != null && s < 500),
    );

    if (res.statusCode == 403) {
      throw const FollowForbidden();
    }

    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'bad_request');
    }

    final items = ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);

    final nextAfter = (data['next_after'] as num?)?.toInt() ?? 0;
    return (items: items, nextAfter: nextAfter);
  }

  Future<({List<Map<String, dynamic>> items, int nextAfter})> listFollowing({
    required String username,
    required int after,
    required int limit,
  }) async {
    final res = await _dio.get(
      '/users/$username/following',
      queryParameters: {
        'after': after,
        'limit': limit,
      },
      options: Options(validateStatus: (s) => s != null && s < 500),
    );

    if (res.statusCode == 403) {
      throw const FollowForbidden();
    }

    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'bad_request');
    }

    final items = ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);

    final nextAfter = (data['next_after'] as num?)?.toInt() ?? 0;
    return (items: items, nextAfter: nextAfter);
  }

  Future<void> removeFollower({
    required String username,
    required String followerUsername,
  }) async {
    await _dio.delete('/users/$username/followers/$followerUsername');
  }
}

class FollowResult {
  final bool followed;
  final bool requestCreated;

  FollowResult({
    required this.followed,
    required this.requestCreated,
  });
}

class FollowForbidden implements Exception {
  const FollowForbidden();

  @override
  String toString() => 'follow_forbidden';
}
