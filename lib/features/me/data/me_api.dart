import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/fresh_auth_dio_provider.dart';
import '../domain/me_models.dart';

final meApiProvider = Provider<MeApi>((ref) {
  return MeApi(ref.read(freshAuthDioProvider));
});

class MeApi {
  final Dio _dio;
  MeApi(this._dio);

  Future<MeResponse> getMe() async {
    print('[ME] baseUrl=${_dio.options.baseUrl}');
    final res = await _dio.get<Map<String, dynamic>>('/me');
    print('[ME] realUri=${res.realUri}');
    return MeResponse.fromJson(res.data ?? const {});
  }

  Future<String?> setDefaultAvatarByGender({required String gender}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/default-avatar',
      data: {'gender': gender},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
    return (res.data?['default_avatar'] as String?);
  }

  /// PATCH /me/full-name
  Future<void> updateFullName({required String fullName}) async {
    try {
      final res = await _dio.patch(
        '/me/full-name',
        data: {'full_name': fullName},
        options: Options(contentType: Headers.jsonContentType),
      );
      // debug
      print(res.data);
    } on DioException catch (e) {
      // en kritik satır:
      print('STATUS: ${e.response?.statusCode}');
      print('DATA: ${e.response?.data}');
      print('HEADERS: ${e.response?.headers}');
      rethrow;
    }
  }

  /// PATCH /me/username
  Future<void> updateUsername({required String username}) async {
    await _dio.patch(
      '/me/username',
      data: {'username': username},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
  }

  /// PATCH /me/birth-date
  Future<void> updateBirthDate({required String birthDateIso}) async {
    await _dio.patch(
      '/me/birth-date',
      data: {'birth_date': birthDateIso}, // yyyy-mm-dd
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
  }
}