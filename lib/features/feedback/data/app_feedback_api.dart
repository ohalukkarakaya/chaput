import 'package:dio/dio.dart';

import '../../../core/utils/logger.dart';

class AppFeedbackApi {
  AppFeedbackApi(this._dio);

  final Dio _dio;

  Future<void> submit(FormData formData) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/app/feedback',
        data: formData,
        options: Options(contentType: Headers.multipartFormDataContentType),
      );

      final data = response.data ?? const <String, dynamic>{};
      if (data['ok'] == true) return;
      throw AppFeedbackSubmitException(
        data['error']?.toString() ?? 'feedback_submit_failed',
      );
    } on DioException catch (e, st) {
      final payload = e.response?.data;
      final message = _extractMessage(payload) ?? e.message ?? 'dio_error';
      Log.e(
        'Feedback submit failed (${e.response?.statusCode}) ${e.requestOptions.uri} -> $message',
        tag: 'Feedback',
        error: payload ?? e,
        st: st,
      );
      throw AppFeedbackSubmitException(
        message,
        statusCode: e.response?.statusCode,
      );
    } catch (e, st) {
      Log.e('Feedback submit crashed', tag: 'Feedback', error: e, st: st);
      if (e is AppFeedbackSubmitException) rethrow;
      throw AppFeedbackSubmitException(e.toString());
    }
  }

  String? _extractMessage(Object? payload) {
    if (payload is Map<String, dynamic>) {
      final error = payload['error']?.toString().trim();
      if (error != null && error.isNotEmpty) return error;
      final message = payload['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }
    if (payload is String) {
      final text = payload.trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}

class AppFeedbackSubmitException implements Exception {
  AppFeedbackSubmitException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => statusCode == null ? message : '$message ($statusCode)';
}
