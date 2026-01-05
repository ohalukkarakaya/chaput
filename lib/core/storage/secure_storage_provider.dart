import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'token_storage.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  // iOS için keychain ayarları vb. gerekirse burada özelleştirirsin.
  return const FlutterSecureStorage();
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(ref.watch(secureStorageProvider));
});