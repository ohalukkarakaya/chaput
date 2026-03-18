import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';

class ReportsApi {
  ReportsApi(this._dio);

  final Dio _dio;

  Future<void> reportChaput({
    required String chaputIdHex,
    required String reasonCode,
    required String details,
  }) async {
    await _post(
      '/reports/chaput/$chaputIdHex',
      reasonCode: reasonCode,
      details: details,
    );
  }

  Future<void> reportMessage({
    required String messageIdHex,
    required String reasonCode,
    required String details,
  }) async {
    await _post(
      '/reports/message/$messageIdHex',
      reasonCode: reasonCode,
      details: details,
    );
  }

  Future<void> _post(
    String path, {
    required String reasonCode,
    required String details,
  }) async {
    final res = await _dio.post(
      path,
      data: {'reason_code': reasonCode, 'details': details},
    );
    final data = res.data;
    if (data is Map<String, dynamic> && data['ok'] == true) return;
    if (data is Map<String, dynamic>) {
      throw Exception(data['error'] ?? 'report_error');
    }
    throw Exception('bad_report_response');
  }
}

final reportsApiProvider = Provider<ReportsApi>((ref) {
  return ReportsApi(ref.read(dioProvider));
});
