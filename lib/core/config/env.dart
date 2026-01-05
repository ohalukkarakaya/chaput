/// Ortam ayarları: prod/dev gibi varyantlarda burayı genişletirsin.
class Env {
  /// Drogon backend base url
  /// - Android emulator: http://10.0.2.2:PORT
  /// - iOS simulator: http://localhost:PORT
  static const String apiBaseUrl = 'http://10.0.2.2:8080';

  /// connect/read timeout
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// debug logging
  static const bool logNetwork = true;
}