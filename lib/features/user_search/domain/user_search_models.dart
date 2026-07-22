class UserSearchItem {
  final String id;
  final String fullName;
  final String? username;
  final String defaultAvatar;
  final String? profilePhotoKey;
  final String? profilePhotoUrl;
  final bool isPublic;
  final bool requestPending;
  final bool isFollowing;

  UserSearchItem({
    required this.id,
    required this.fullName,
    required this.username,
    required this.defaultAvatar,
    required this.profilePhotoKey,
    this.profilePhotoUrl,
    required this.isPublic,
    this.requestPending = false,
    this.isFollowing = false,
  });

  UserSearchItem copyWith({
    String? id,
    String? fullName,
    String? username,
    String? defaultAvatar,
    String? profilePhotoKey,
    String? profilePhotoUrl,
    bool? isPublic,
    bool? requestPending,
    bool? isFollowing,
  }) {
    return UserSearchItem(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      defaultAvatar: defaultAvatar ?? this.defaultAvatar,
      profilePhotoKey: profilePhotoKey ?? this.profilePhotoKey,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      isPublic: isPublic ?? this.isPublic,
      requestPending: requestPending ?? this.requestPending,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  factory UserSearchItem.fromJson(Map<String, dynamic> json) {
    final isFollowing =
        _jsonBoolAny(json, _isFollowingKeys) ||
        _viewerStateBoolAny(json, _isFollowingKeys);
    final requestPending =
        !isFollowing &&
        (_jsonBoolAny(json, _requestPendingKeys) ||
            _viewerStateBoolAny(json, _requestPendingKeys));

    return UserSearchItem(
      id: (json['id'] ?? '') as String,
      fullName: (json['full_name'] ?? '') as String,
      username: json['username'] as String?,
      defaultAvatar: (json['default_avatar'] ?? '') as String,
      profilePhotoKey: json['profile_photo_key'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      isPublic: (json['is_public'] ?? false) as bool,
      requestPending: requestPending,
      isFollowing: isFollowing,
    );
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

class UserSearchResponse {
  final bool ok;
  final List<UserSearchItem> items;
  final String? nextCursor;

  UserSearchResponse({
    required this.ok,
    required this.items,
    required this.nextCursor,
  });

  factory UserSearchResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? const []);
    return UserSearchResponse(
      ok: json['ok'] == true,
      items: rawItems
          .map((e) => UserSearchItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor'] as String?,
    );
  }
}
