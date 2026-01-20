import 'package:dio/dio.dart';

class EmailChangeApi {
  EmailChangeApi(this._dio);
  final Dio _dio;

  Future<void> requestChange({required String newEmail}) async {
    final res = await _dio.post(
      '/me/email/request-change',
      data: {'new_email': newEmail},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    final data = res.data;
    if (data is Map && data['ok'] == true) return;
    if (data is Map && data['ok'] == false) {
      throw Exception(data['error'] ?? 'unknown_error');
    }
    throw Exception('bad_response');
  }

  Future<void> verifyChange({required String newEmail, required String code}) async {
    final res = await _dio.post(
      '/me/email/verify-change',
      data: {'new_email': newEmail, 'code': code},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    final data = res.data;
    if (data is Map && data['ok'] == true) return;
    if (data is Map && data['ok'] == false) {
      throw Exception(data['error'] ?? 'unknown_error');
    }
    throw Exception('bad_response');
  }
}