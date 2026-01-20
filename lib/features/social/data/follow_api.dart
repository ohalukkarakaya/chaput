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
}

class FollowResult {
  final bool followed;
  final bool requestCreated;

  FollowResult({
    required this.followed,
    required this.requestCreated,
  });
}
