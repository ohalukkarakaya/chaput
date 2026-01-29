class RecommendedUser {
  final String id;
  final String? username;
  final String fullName;
  final String defaultAvatar;
  final String? profilePhotoKey;
  final String? profilePhotoUrl;

  const RecommendedUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.defaultAvatar,
    required this.profilePhotoKey,
    required this.profilePhotoUrl,
  });

  factory RecommendedUser.fromJson(Map<String, dynamic> json) {
    return RecommendedUser(
      id: json['id'] as String,
      username: json['username'] as String?,
      fullName: (json['full_name'] as String?) ?? '',
      defaultAvatar: (json['default_avatar'] as String?) ?? '',
      profilePhotoKey: json['profile_photo_key'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
    );
  }

  String? get profilePhotoPath {
    if (profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty) return profilePhotoUrl;
    if (profilePhotoKey != null && profilePhotoKey!.isNotEmpty) {
      if (profilePhotoKey!.contains('/')) return profilePhotoKey;
      return '/uploads/profile_photos/$profilePhotoKey';
    }
    return null;
  }
}
