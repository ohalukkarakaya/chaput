import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/fresh_auth_dio_provider.dart';
import '../domain/recommended_user.dart';

class RecommendedUsersApi {
  final Dio dio;
  RecommendedUsersApi(this.dio);

  Future<List<RecommendedUser>> getRecommended({int limit = 8}) async {
    final res = await dio.get(
      '/users/recommended',
      queryParameters: {'limit': limit},
    );

    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('bad_json');
    }

    if (data['ok'] != true) {
      throw Exception((data['error'] ?? 'bad_request').toString());
    }

    final items = data['items'];
    if (items is List) {
      return items
          .whereType<Map>()
          .map(
            (item) => RecommendedUser.fromJson(
              item.map((k, v) => MapEntry(k.toString(), v)),
            ),
          )
          .toList(growable: false);
    }

    final user = data['user'];
    if (user == null) return const [];
    if (user is! Map<String, dynamic>) {
      throw Exception('bad_user_payload');
    }

    return [RecommendedUser.fromJson(user)];
  }
}

final recommendedUsersApiProvider = Provider<RecommendedUsersApi>((ref) {
  final dio = ref.read(freshAuthDioProvider);
  return RecommendedUsersApi(dio);
});
