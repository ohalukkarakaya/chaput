class RecommendedUser {
  final String id;
  final String? username;
  final String fullName;
  final String defaultAvatar;
  final String? profilePhotoKey;
  final String? profilePhotoUrl;
  final bool isPublic;
  final bool requestPending;
  final bool isFollowing;

  const RecommendedUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.defaultAvatar,
    required this.profilePhotoKey,
    required this.profilePhotoUrl,
    required this.isPublic,
    required this.requestPending,
    required this.isFollowing,
  });

  factory RecommendedUser.fromJson(Map<String, dynamic> json) {
    return RecommendedUser(
      id: json['id'] as String,
      username: json['username'] as String?,
      fullName: (json['full_name'] as String?) ?? '',
      defaultAvatar: (json['default_avatar'] as String?) ?? '',
      profilePhotoKey: json['profile_photo_key'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      isPublic: json['is_public'] == true,
      requestPending:
          _jsonBool(json, 'request_pending') ||
          _viewerStateBool(json, 'request_pending'),
      isFollowing:
          _jsonBool(json, 'is_following') ||
          _jsonBool(json, 'following') ||
          _jsonBool(json, 'followed') ||
          _viewerStateBool(json, 'is_following'),
    );
  }

  String? get profilePhotoPath {
    if (profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty)
      return profilePhotoUrl;
    if (profilePhotoKey != null && profilePhotoKey!.isNotEmpty) {
      if (profilePhotoKey!.contains('/')) return profilePhotoKey;
      return '/uploads/profile_photos/$profilePhotoKey';
    }
    return null;
  }
}

bool _jsonBool(Map<String, dynamic> json, String key) => json[key] == true;

bool _viewerStateBool(Map<String, dynamic> json, String key) {
  final viewerState = json['viewer_state'];
  if (viewerState is! Map) return false;
  return viewerState[key] == true;
}
