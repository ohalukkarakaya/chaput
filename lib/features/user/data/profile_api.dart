import 'package:dio/dio.dart';

class ProfileApi {
  ProfileApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getProfile(String userIdHex) async {
    final res = await _dio.get('/users/$userIdHex');
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw Exception('bad_profile_response');
  }

  Future<Map<String, dynamic>> getTree(String userIdHex) async {
    final res = await _dio.get('/users/$userIdHex/tree');
    final data = res.data;
    if (data is Map<String, dynamic>) return data;
    throw Exception('bad_tree_response');
  }

  Future<({String userId, bool isPrivate})> resolveUsername(String username) async {
    final encoded = Uri.encodeComponent(username);
    final res = await _dio.get('/users/by-username/$encoded');
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('bad_username_response');
    }
    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'bad_username_response');
    }
    final userId = data['user_id']?.toString() ?? '';
    if (userId.isEmpty) {
      throw Exception('bad_username_response');
    }
    final isPrivate = data['is_private'] == true;
    return (userId: userId, isPrivate: isPrivate);
  }
}
