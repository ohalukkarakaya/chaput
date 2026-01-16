import 'package:dio/dio.dart';
import '../domain/lite_user.dart';

class UserApi {
  UserApi(this._dio);
  final Dio _dio;

  Future<({List<LiteUser> items, List<String> missingIds})> batchLite({
    required List<String> userIds,
  }) async {
    final cleaned = userIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (cleaned.isEmpty) throw Exception('empty_user_ids');

    final res = await _dio.post(
      '/users/batch-lite',
      data: {'user_ids': cleaned},
      options: Options(headers: {'Content-Type': 'application/json'}),
    );

    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'bad_request');
    }

    final itemsJson = (data['items'] as List?) ?? const [];
    final items = itemsJson
        .map((e) => LiteUser.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);

    final missingJson = (data['missing_ids'] as List?) ?? const [];
    final missing = missingJson.map((e) => e.toString()).toList(growable: false);

    return (items: items, missingIds: missing);
  }
}