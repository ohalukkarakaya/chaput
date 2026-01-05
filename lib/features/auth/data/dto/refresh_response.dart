class RefreshResponse {
  final String accessToken;
  final String? refreshToken;

  const RefreshResponse({
    required this.accessToken,
    this.refreshToken,
  });

  factory RefreshResponse.fromJson(Map<String, dynamic> json) {
    return RefreshResponse(
      accessToken: (json['accessToken'] ?? json['access_token'] ?? '') as String,
      refreshToken: (json['refreshToken'] ?? json['refresh_token']) as String?,
    );
  }
}