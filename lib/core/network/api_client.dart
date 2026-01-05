import 'package:dio/dio.dart';

class ApiClient {
  final Dio dio;
  ApiClient(this.dio);

  Future<Response<T>> get<T>(
      String path, {
        Map<String, dynamic>? query,
        Options? options,
      }) {
    return dio.get<T>(path, queryParameters: query, options: options);
  }

  Future<Response<T>> post<T>(
      String path, {
        Object? data,
        Map<String, dynamic>? query,
        Options? options,
      }) {
    return dio.post<T>(path, data: data, queryParameters: query, options: options);
  }

  Future<Response<T>> delete<T>(
      String path, {
        Object? data,
        Map<String, dynamic>? query,
        Options? options,
      }) {
    return dio.delete<T>(path, data: data, queryParameters: query, options: options);
  }
}