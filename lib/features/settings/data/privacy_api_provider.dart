import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/network/dio_provider.dart';
import 'privacy_api.dart';

final privacyApiProvider = Provider<PrivacyApi>((ref) {
  final Dio dio = ref.read(dioProvider);
  return PrivacyApi(dio);
});