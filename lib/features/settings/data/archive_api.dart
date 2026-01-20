import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chaput/core/network/dio_provider.dart';

import '../domain/archive_chaput.dart';

class ArchiveApi {
  ArchiveApi(this._dio);
  final Dio _dio;

  Future<({List<ArchiveChaput> items, String? nextCursor})> listArchived({
    required int limit,
    required String? cursor,
  }) async {
    final res = await _dio.get(
      '/me/chaputs/archive',
      queryParameters: {
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );

    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'bad_request');
    }

    final raw = (data['items'] as List?) ?? const [];
    final items = raw
        .whereType<Map>()
        .map((e) => ArchiveChaput.fromJson(e.map((k, v) => MapEntry(k.toString(), v))))
        .where((c) => c.id.isNotEmpty && c.authorId.isNotEmpty)
        .toList(growable: false);

    final next = data['next_cursor'];
    final nextCursor = next == null ? null : next.toString();
    return (items: items, nextCursor: (nextCursor == 'null') ? null : nextCursor);
  }

  Future<void> reviveChaput({required String chaputIdHex}) async {
    final res = await _dio.post('/chaputs/$chaputIdHex/revive');
    final data = res.data;

    if (data is Map && data['ok'] == true) return;
    if (data is Map && data['ok'] == false) {
      throw Exception(data['error'] ?? 'unknown_error');
    }
    // bazı controller’lar boş body dönebilir; 200 ise kabul edelim
    if (res.statusCode == 200) return;

    throw Exception('bad_response');
  }
}

final archiveApiProvider = Provider<ArchiveApi>((ref) {
  return ArchiveApi(ref.read(dioProvider));
});