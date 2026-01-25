class ProfileEntitlement {
  final String profileId;
  final bool isPublic;

  ProfileEntitlement({
    required this.profileId,
    required this.isPublic,
  });

  factory ProfileEntitlement.fromJson(Map<String, dynamic> json) {
    return ProfileEntitlement(
      profileId: json['profile_id'] as String,
      isPublic: json['is_public'] as bool? ?? false,
    );
  }
}