class MeResponse {
  final bool ok;
  final MeUser user;
  final MeSubscription subscription;
  final MeBalances balances;
  final MeSecretAd secretAd;

  MeResponse({
    required this.ok,
    required this.user,
    required this.subscription,
    required this.balances,
    required this.secretAd,
  });

  factory MeResponse.fromJson(Map<String, dynamic> json) {
    return MeResponse(
      ok: json['ok'] == true,
      user: MeUser.fromJson((json['user'] ?? const {}) as Map<String, dynamic>),
      subscription: MeSubscription.fromJson((json['subscription'] ?? const {}) as Map<String, dynamic>),
      balances: MeBalances.fromJson((json['balances'] ?? const {}) as Map<String, dynamic>),
      secretAd: MeSecretAd.fromJson((json['secret_ad'] ?? const {}) as Map<String, dynamic>),
    );
  }
}

class MeUser {
  final String userId;
  final String email;
  final bool emailVerified;
  final String fullName;
  final String username;
  final String bio;
  final String? defaultAvatar;
  final int treeId;
  final String? profilePhotoKey;
  final String? profilePhotoUrl;

  MeUser({
    required this.userId,
    required this.email,
    required this.emailVerified,
    required this.fullName,
    required this.username,
    required this.bio,
    required this.defaultAvatar,
    required this.treeId,
    required this.profilePhotoKey,
    required this.profilePhotoUrl,
  });

  factory MeUser.fromJson(Map<String, dynamic> json) {
    return MeUser(
      userId: (json['user_id'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      emailVerified: json['email_verified'] == true,
      fullName: (json['full_name'] ?? '') as String,
      username: (json['username'] ?? '') as String,
      bio: (json['bio'] ?? '') as String,
      defaultAvatar: json['default_avatar'] as String?,
      treeId: (json['tree_id'] ?? 0) as int,
      profilePhotoKey: json['profile_photo_key'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
    );
  }
}

class MeSubscription {
  final String plan; // FREE/PLUS/PRO
  final String? expiresAt;

  MeSubscription({required this.plan, required this.expiresAt});

  factory MeSubscription.fromJson(Map<String, dynamic> json) {
    return MeSubscription(
      plan: (json['plan'] ?? 'FREE') as String,
      expiresAt: json['expires_at'] as String?,
    );
  }
}

class MeBalances {
  final int special;
  final int secret;

  MeBalances({required this.special, required this.secret});

  factory MeBalances.fromJson(Map<String, dynamic> json) {
    return MeBalances(
      special: (json['special'] ?? 0) as int,
      secret: (json['secret'] ?? 0) as int,
    );
  }
}

class MeSecretAd {
  final int grantedToday;
  final int progress;

  MeSecretAd({required this.grantedToday, required this.progress});

  factory MeSecretAd.fromJson(Map<String, dynamic> json) {
    return MeSecretAd(
      grantedToday: (json['granted_today'] ?? 0) as int,
      progress: (json['progress'] ?? 0) as int,
    );
  }
}