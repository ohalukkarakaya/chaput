import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_provider.dart';
import 'user_api.dart';

final userApiProvider = Provider<UserApi>((ref) {
  final Dio dio = ref.read(dioProvider);
  return UserApi(dio);
});