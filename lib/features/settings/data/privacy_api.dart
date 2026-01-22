import 'package:dio/dio.dart';

class PrivacyApi {
  PrivacyApi(this._dio);
  final Dio _dio;

  Future<bool> getIsPublic() async {
    final res = await _dio.get('/me/privacy');
    final data = res.data;
    if (data is Map<String, dynamic> && data['ok'] == true) {
      return data['is_public'] == true;
    }
    throw Exception(data is Map ? (data['error'] ?? 'privacy_get_failed') : 'bad_privacy_get');
  }

  Future<bool> setIsPublic(bool isPublic) async {
    final res = await _dio.patch('/me/privacy', data: {'is_public': isPublic});
    final data = res.data;
    if (data is Map<String, dynamic> && data['ok'] == true) {
      return data['is_public'] == true;
    }
    throw Exception(data is Map ? (data['error'] ?? 'privacy_set_failed') : 'bad_privacy_set');
  }
}