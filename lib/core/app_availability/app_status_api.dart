import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_provider.dart';

final appStatusApiProvider = Provider<AppStatusApi>((ref) {
  return AppStatusApi(ref.read(authDioProvider));
});

class AppStatusApi {
  AppStatusApi(this._dio);

  final Dio _dio;

  Future<AppStatusSnapshot> fetchStatus() async {
    final response = await _dio.get<dynamic>(
      '/app/status',
      options: Options(
        sendTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        validateStatus: (status) => status != null && status < 600,
      ),
    );

    final data = response.data;
    if (data is Map) {
      final maintenance =
          data['maintenance'] == true || data['available'] == false;
      return AppStatusSnapshot(
        maintenance: maintenance,
        message: data['message']?.toString(),
      );
    }

    if (response.statusCode == 503) {
      return const AppStatusSnapshot(maintenance: true);
    }

    return const AppStatusSnapshot(maintenance: false);
  }
}

class AppStatusSnapshot {
  const AppStatusSnapshot({required this.maintenance, this.message});

  final bool maintenance;
  final String? message;
}
