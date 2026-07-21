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

  factory UserSearchItem.fromJson(Map<String, dynamic> json) {
    return UserSearchItem(
      id: (json['id'] ?? '') as String,
      fullName: (json['full_name'] ?? '') as String,
      username: json['username'] as String?,
      defaultAvatar: (json['default_avatar'] ?? '') as String,
      profilePhotoKey: json['profile_photo_key'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      isPublic: (json['is_public'] ?? false) as bool,
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
}

bool _jsonBool(Map<String, dynamic> json, String key) => json[key] == true;

bool _viewerStateBool(Map<String, dynamic> json, String key) {
  final viewerState = json['viewer_state'];
  if (viewerState is! Map) return false;
  return viewerState[key] == true;
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
