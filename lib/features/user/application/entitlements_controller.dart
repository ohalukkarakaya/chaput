import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/entitlements_api.dart';
import '../domain/chaput_entitlements.dart';


final chaputEntitlementsControllerProvider =
AsyncNotifierProvider<ChaputEntitlementsController, ChaputEntitlements?>(
  ChaputEntitlementsController.new,
);

class ChaputEntitlementsController extends AsyncNotifier<ChaputEntitlements?> {
  @override
  Future<ChaputEntitlements?> build() async {
    // Eğer provider ekranlar arası yaşamaya devam edecekse:
    // ref.keepAlive();

    final api = ref.read(chaputEntitlementsApiProvider);

    // İlk build'te fetch eder ve cache’ler.
    // Sonraki rebuildlerde Riverpod aynı instance’ı koruduğu için tekrar çağırmaz.
    final res = await api.getMyEntitlements();
    return res;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(chaputEntitlementsApiProvider);
      return api.getMyEntitlements();
    });
  }
}