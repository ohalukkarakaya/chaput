import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/chaput_entitlements.dart';

final chaputEntitlementsApiProvider = Provider((ref) {
  final dio = ref.read(dioProvider);
  return ChaputEntitlementsApi(dio);
});

class ChaputEntitlementsApi {
  ChaputEntitlementsApi(this._dio);
  final dynamic _dio; // senin dio tipine göre Dio yazabilirsin

  Future<ChaputEntitlements> getMyEntitlements() async {
    final r = await _dio.get('/me/chaputs/entitlements');
    return ChaputEntitlements.fromJson(r.data as Map<String, dynamic>);
  }
}