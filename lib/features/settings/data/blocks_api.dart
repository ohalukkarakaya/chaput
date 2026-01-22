import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chaput/core/network/dio_provider.dart';

class BlocksApi {
  BlocksApi(this._dio);
  final Dio _dio;

  Future<({List<Map<String, dynamic>> items, int nextAfter})> list({
    required int after,
    required int limit,
  }) async {
    final res = await _dio.get('/me/blocks', queryParameters: {
      'after': after,
      'limit': limit,
    });

    final data = res.data as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'bad_request');
    }

    final items = ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);

    final nextAfter = (data['next_after'] as num?)?.toInt() ?? 0;
    return (items: items, nextAfter: nextAfter);
  }

  Future<void> blockByUsername(String username) async {
    await _dio.post('/users/$username/block');
  }

  Future<void> unblockByUsername(String username) async {
    await _dio.delete('/users/$username/block');
  }
}

final blocksApiProvider = Provider<BlocksApi>((ref) {
  return BlocksApi(ref.read(dioProvider));
});