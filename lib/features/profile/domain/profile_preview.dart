class ProfilePreview {
  const ProfilePreview({
    required this.id,
    required this.username,
    required this.fullName,
    required this.defaultAvatar,
    required this.profilePhotoKey,
    required this.profilePhotoUrl,
    required this.isPublic,
    this.requestPending = false,
  });

  final String id;
  final String? username;
  final String fullName;
  final String defaultAvatar;
  final String? profilePhotoKey;
  final String? profilePhotoUrl;
  final bool isPublic;
  final bool requestPending;

  String? get profilePhotoPath {
    if (profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty) {
      return profilePhotoUrl;
    }
    if (profilePhotoKey != null && profilePhotoKey!.isNotEmpty) {
      if (profilePhotoKey!.contains('/')) return profilePhotoKey;
      return '/uploads/profile_photos/$profilePhotoKey';
    }
    return null;
  }

  String get avatarImageUrl {
    final path = profilePhotoPath;
    if (path != null && path.isNotEmpty) return path;
    return defaultAvatar;
  }

  bool get isDefaultAvatar =>
      profilePhotoPath == null || profilePhotoPath == '';
}

const profilePreviewExtraKey = 'profilePreview';

String profileAvatarHeroTag(String userId) => 'chaput-profile-avatar-$userId';
