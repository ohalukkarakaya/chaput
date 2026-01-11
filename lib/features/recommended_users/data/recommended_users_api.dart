import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/fresh_auth_dio_provider.dart'; // sende hangi dosyaysa onu import et
import '../domain/recommended_user.dart';

class RecommendedUsersApi {
  final Dio dio;
  RecommendedUsersApi(this.dio);

  Future<RecommendedUser?> getRecommended() async {
    final res = await dio.get('/users/recommended');

    // beklenen format:
    // { ok:true, user: {...} } veya { ok:true, user:null }
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('bad_json');
    }

    if (data['ok'] != true) {
      throw Exception((data['error'] ?? 'bad_request').toString());
    }

    final user = data['user'];
    if (user == null) return null;

    if (user is! Map<String, dynamic>) {
      throw Exception('bad_user_payload');
    }

    return RecommendedUser.fromJson(user);
  }
}

final recommendedUsersApiProvider = Provider<RecommendedUsersApi>((ref) {
  final dio = ref.read(freshAuthDioProvider); // ✅ Authorization + refresh interceptor burada olmalı
  return RecommendedUsersApi(dio);
});