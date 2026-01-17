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
}