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

  RecommendedUser copyWith({
    String? id,
    String? username,
    String? fullName,
    String? defaultAvatar,
    String? profilePhotoKey,
    String? profilePhotoUrl,
    bool? isPublic,
    bool? requestPending,
    bool? isFollowing,
  }) {
    return RecommendedUser(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      defaultAvatar: defaultAvatar ?? this.defaultAvatar,
      profilePhotoKey: profilePhotoKey ?? this.profilePhotoKey,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      isPublic: isPublic ?? this.isPublic,
      requestPending: requestPending ?? this.requestPending,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

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
          _jsonBoolAny(json, _requestPendingKeys) ||
          _viewerStateBoolAny(json, _requestPendingKeys),
      isFollowing:
          _jsonBoolAny(json, _isFollowingKeys) ||
          _viewerStateBoolAny(json, _isFollowingKeys),
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

const _requestPendingKeys = [
  'request_pending',
  'i_requested_follow',
  'requested_follow',
  'follow_request_pending',
  'request_created',
];

const _isFollowingKeys = [
  'is_following',
  'i_following',
  'following',
  'followed',
  'am_following',
  'viewer_is_following',
  'is_followed_by_me',
];

bool _jsonBoolAny(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (_boolValue(json[key])) return true;
  }
  return false;
}

bool _viewerStateBoolAny(Map<String, dynamic> json, List<String> keys) {
  final viewerState = json['viewer_state'];
  if (viewerState is! Map) return false;
  for (final key in keys) {
    if (_boolValue(viewerState[key])) return true;
  }
  return false;
}

bool _boolValue(Object? value) {
  if (value == true) return true;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}
