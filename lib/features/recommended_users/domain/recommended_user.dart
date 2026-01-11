class RecommendedUser {
  final String id;
  final String? username;
  final String fullName;
  final String defaultAvatar;
  final String? profilePhotoKey;

  const RecommendedUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.defaultAvatar,
    required this.profilePhotoKey,
  });

  factory RecommendedUser.fromJson(Map<String, dynamic> json) {
    return RecommendedUser(
      id: json['id'] as String,
      username: json['username'] as String?,
      fullName: (json['full_name'] as String?) ?? '',
      defaultAvatar: (json['default_avatar'] as String?) ?? '',
      profilePhotoKey: json['profile_photo_key'] as String?,
    );
  }
}