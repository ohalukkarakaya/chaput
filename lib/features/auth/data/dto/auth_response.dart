class AuthResponse {
  final String userId;
  final String accessToken;
  final String refreshToken;

  const AuthResponse({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      userId: (json['userId'] ?? json['_id'] ?? json['id'] ?? '') as String,
      accessToken: (json['accessToken'] ?? json['access_token'] ?? '') as String,
      refreshToken: (json['refreshToken'] ?? json['refresh_token'] ?? '') as String,
    );
  }
}