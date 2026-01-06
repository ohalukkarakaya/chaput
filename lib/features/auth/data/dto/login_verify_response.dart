class LoginVerifyResponse {
  final String accessToken;
  final String refreshToken;

  const LoginVerifyResponse({
    required this.accessToken,
    required this.refreshToken,
  });

  factory LoginVerifyResponse.fromJson(Map<String, dynamic> json) {
    return LoginVerifyResponse(
      accessToken: (json['access_token'] ?? '') as String,
      refreshToken: (json['refresh_token'] ?? '') as String,
    );
  }
}