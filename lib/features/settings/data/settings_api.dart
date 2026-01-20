import 'package:dio/dio.dart';
import 'dto/upload_photo_response.dart';

class SettingsApi {
  SettingsApi(this._dio);
  final Dio _dio;

  Future<UploadPhotoResponse> uploadMePhoto({required MultipartFile file}) async {
    final form = FormData.fromMap({'file': file});

    final res = await _dio.post(
      '/me/photo',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );

    final data = res.data;
    if (data is Map && data['ok'] == true) {
      return UploadPhotoResponse.fromJson(Map<String, dynamic>.from(data));
    }
    if (data is Map && data['ok'] == false) {
      throw Exception(data['error'] ?? 'unknown_error');
    }
    throw Exception('bad_response');
  }

  Future<void> deleteMePhoto() async {
    final res = await _dio.delete('/me/photo');
    final data = res.data;
    if (data is Map && data['ok'] == true) return;
    if (data is Map && data['ok'] == false) {
      throw Exception(data['error'] ?? 'unknown_error');
    }
    throw Exception('bad_response');
  }
}