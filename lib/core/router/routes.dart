class Routes {
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const boot = '/';
  static const tree = '/u/:userId';
  static const chaput = '/c/:chaputId';
  static const post = '/post/:postId';
  static const home = '/home';
  static const notifications = '/notifications';
  static const profileByUsername = '/me/:username';
  static const profileBase = '/profile';
  static const settings = '/settings';
  static const legal = '/legal';

  static String treePath(String userId) => '/u/$userId';
  static String chaputPath(String chaputId) => '/c/$chaputId';
  static String postPath(String postId) => '/post/$postId';
  static String profilePath(String userId) => '$profileBase/$userId';

  static Future<String> profile(String userId) async => '$profileBase/$userId';
}
