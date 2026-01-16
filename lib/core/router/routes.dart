class Routes {
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const boot = '/';
  static const tree = '/u/:userId';
  static const home = '/home';
  static const profileBase = '/profile';

  static Future<String> profile(String userId) async => '$profileBase/$userId';
}
