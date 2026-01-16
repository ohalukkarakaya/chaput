import 'package:dio/dio.dart';

class UserTreeApi {
  UserTreeApi(this._dio);

  final Dio _dio;

  Future<String> getTreeIdOfUser(String userHex) async {
    final res = await _dio.get('/users/$userHex/tree');
    final data = res.data;

    if (data is Map && data['ok'] == true && data['tree_id'] is String) {
      return data['tree_id'] as String;
    }

    // 404 vs gelirse buraya düşebilir
    final err = (data is Map && data['error'] is String) ? data['error'] : 'unknown_error';
    throw Exception(err);
  }
}