import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/constants.dart';
import '../../../core/network/dio_provider.dart';

enum EmailLookupResult {
  userNotFound,
  userFoundComplete,
  userFoundNeedsProfileSetup,
}

final internalUsersApiProvider = Provider<InternalUsersApi>((ref) {
  // Interceptor'suz dio kullanıyoruz (authDioProvider)
  final dio = ref.watch(authDioProvider);
  return InternalUsersApi(dio);
});

class InternalUsersApi {
  final Dio _dio;
  InternalUsersApi(this._dio);

  Future<EmailLookupResult> lookupEmail(String email) async {
    final res = await _dio.post(
      '/internal/users/lookup-email',
      data: {'email': email},
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'X-App-Key': Constants.internalAppKey,
        },
      ),
    );

    final data = res.data;

    // Backend bazen düz string döner, bazen json döner diye esnek parse:
    String? value;
    if (data is String) {
      value = data;
    } else if (data is Map<String, dynamic>) {
      value = (data['result'] ?? data['status'] ?? data['code'])?.toString();
    }

    switch (value) {
      case 'USER_NOT_FOUND':
        return EmailLookupResult.userNotFound;
      case 'USER_FOUND_COMPLETE':
        return EmailLookupResult.userFoundComplete;
      case 'USER_FOUND_NEEDS_PROFILE_SETUP':
        return EmailLookupResult.userFoundNeedsProfileSetup;
      default:
        throw StateError('Unexpected lookup result: $data');
    }
  }
}