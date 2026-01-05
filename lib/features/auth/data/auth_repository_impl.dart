import '../domain/auth_repository.dart';
import 'auth_api.dart';
import 'dto/auth_response.dart';
import 'dto/refresh_response.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthApi api;
  AuthRepositoryImpl(this.api);

  @override
  Future<AuthResponse> login({required String username, required String password}) {
    return api.login(username: username, password: password);
  }

  @override
  Future<RefreshResponse> refresh({required String refreshToken}) {
    return api.refresh(refreshToken: refreshToken);
  }
}