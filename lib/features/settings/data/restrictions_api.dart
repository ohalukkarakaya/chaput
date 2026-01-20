import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chaput/core/network/dio_provider.dart';

class RestrictionsApi {
  RestrictionsApi(this._dio);
  final Dio _dio;

  Future<({List<Map<String, dynamic>> items, String? nextCursor})> list({
    required int limit,
    required String? cursor,
  }) async {
    final res = await _dio.get('/me/restrictions', queryParameters: {
      'limit': limit,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    });

    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'bad_request');
    }

    final items = ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);

    final nextCursor = data['next_cursor']?.toString();
    return (items: items, nextCursor: (nextCursor == 'null') ? null : nextCursor);
  }
}

final restrictionsApiProvider = Provider<RestrictionsApi>((ref) {
  return RestrictionsApi(ref.read(dioProvider));
});