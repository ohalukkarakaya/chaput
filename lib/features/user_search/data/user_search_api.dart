import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/fresh_auth_dio_provider.dart';
import '../domain/user_search_models.dart';

final userSearchApiProvider = Provider<UserSearchApi>((ref) {
  return UserSearchApi(ref.read(freshAuthDioProvider));
});

class UserSearchApi {
  final Dio _dio;
  UserSearchApi(this._dio);

  Future<UserSearchResponse> search({
    required String q,
    required int limit,
    String? cursor,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/users/search',
      data: {
        'q': q,
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
      options: Options(contentType: Headers.jsonContentType),
    );

    return UserSearchResponse.fromJson(res.data ?? const {});
  }
}
