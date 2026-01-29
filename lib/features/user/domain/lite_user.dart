class LiteUser {
  final String id;
  final String? username;
  final String fullName;
  final String? bio;
  final String defaultAvatar;
  final String? profilePhotoKey;
  final String? profilePhotoUrl;

  const LiteUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.bio,
    required this.defaultAvatar,
    required this.profilePhotoKey,
    required this.profilePhotoUrl,
  });

  factory LiteUser.fromJson(Map<String, dynamic> j) {
    return LiteUser(
      id: j['id'] as String,
      username: j['username'] as String?,
      fullName: (j['full_name'] ?? '') as String,
      bio: j['bio'] as String?,
      defaultAvatar: (j['default_avatar'] ?? true) as String,
      profilePhotoKey: j['profile_photo_key'] as String?,
      profilePhotoUrl: j['profile_photo_url'] as String?,
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
