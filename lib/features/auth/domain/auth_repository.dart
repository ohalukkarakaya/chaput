import '../data/dto/auth_response.dart';
import '../data/dto/refresh_response.dart';

abstract class AuthRepository {
  Future<AuthResponse> login({
    required String username,
    required String password,
  });

  Future<RefreshResponse> refresh({
    required String refreshToken,
  });
}