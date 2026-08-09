import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../domain/profile_gallery_photo.dart';

class ProfileGalleryApi {
  ProfileGalleryApi(this._dio);

  final Dio _dio;

  Future<List<ProfileGalleryPhoto>> listMine() async {
    final res = await _dio.get('/me/profile-gallery');
    return _photosFromResponse(res.data);
  }

  Future<List<ProfileGalleryPhoto>> uploadMine({
    required MultipartFile file,
  }) async {
    final form = FormData.fromMap({'file': file});
    final res = await _dio.post(
      '/me/profile-gallery/photos',
      data: form,
      options: Options(contentType: Headers.multipartFormDataContentType),
    );
    return _photosFromResponse(res.data);
  }

  Future<List<ProfileGalleryPhoto>> deleteMine(String photoId) async {
    final encoded = Uri.encodeComponent(photoId);
    final res = await _dio.delete('/me/profile-gallery/photos/$encoded');
    return _photosFromResponse(res.data);
  }

  List<ProfileGalleryPhoto> _photosFromResponse(dynamic data) {
    if (data is Map && data['ok'] == false) {
      throw Exception(data['error']?.toString() ?? 'unknown_error');
    }
    if (data is Map) {
      return ProfileGalleryPhoto.listFromJson(data['photos']);
    }
    throw Exception('bad_response');
  }
}

final profileGalleryApiProvider = Provider<ProfileGalleryApi>((ref) {
  return ProfileGalleryApi(ref.read(dioProvider));
});
