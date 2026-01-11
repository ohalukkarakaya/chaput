class UserSearchItem {
  final String id;
  final String fullName;
  final String? username;
  final String defaultAvatar;
  final String? profilePhotoKey;
  final bool isPublic;

  UserSearchItem({
    required this.id,
    required this.fullName,
    required this.username,
    required this.defaultAvatar,
    required this.profilePhotoKey,
    required this.isPublic,
  });

  factory UserSearchItem.fromJson(Map<String, dynamic> json) {
    return UserSearchItem(
      id: (json['id'] ?? '') as String,
      fullName: (json['full_name'] ?? '') as String,
      username: json['username'] as String?,
      defaultAvatar: (json['default_avatar'] ?? '') as String,
      profilePhotoKey: json['profile_photo_key'] as String?,
      isPublic: (json['is_public'] ?? false) as bool,
    );
  }
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
      items: rawItems.map((e) => UserSearchItem.fromJson(e as Map<String, dynamic>)).toList(),
      nextCursor: json['next_cursor'] as String?,
    );
  }
}