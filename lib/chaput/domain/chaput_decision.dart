class ChaputDecision {
  final ChaputDecisionTarget target;
  final ChaputDecisionPlan plan;
  final ChaputDecisionCredits credits;
  final ChaputDecisionAds ads;
  final ChaputDecisionInfo decision;

  ChaputDecision({
    required this.target,
    required this.plan,
    required this.credits,
    required this.ads,
    required this.decision,
  });

  factory ChaputDecision.fromJson(Map<String, dynamic> json) {
    return ChaputDecision(
      target: ChaputDecisionTarget.fromJson(json['target'] as Map<String, dynamic>),
      plan: ChaputDecisionPlan.fromJson(json['plan'] as Map<String, dynamic>),
      credits: ChaputDecisionCredits.fromJson(json['credits'] as Map<String, dynamic>),
      ads: ChaputDecisionAds.fromJson(json['ads'] as Map<String, dynamic>),
      decision: ChaputDecisionInfo.fromJson(json['decision'] as Map<String, dynamic>),
    );
  }

  ChaputDecision copyWith({
    ChaputDecisionTarget? target,
    ChaputDecisionPlan? plan,
    ChaputDecisionCredits? credits,
    ChaputDecisionAds? ads,
    ChaputDecisionInfo? decision,
  }) {
    return ChaputDecision(
      target: target ?? this.target,
      plan: plan ?? this.plan,
      credits: credits ?? this.credits,
      ads: ads ?? this.ads,
      decision: decision ?? this.decision,
    );
  }
}

class ChaputDecisionTarget {
  final String profileId;
  final bool canRead;
  final bool canStart;
  final bool restrictedMode;
  final bool hasThread;
  final String threadState;
  final String threadId;

  ChaputDecisionTarget({
    required this.profileId,
    required this.canRead,
    required this.canStart,
    required this.restrictedMode,
    required this.hasThread,
    required this.threadState,
    required this.threadId,
  });

  factory ChaputDecisionTarget.fromJson(Map<String, dynamic> json) {
    return ChaputDecisionTarget(
      profileId: json['profile_id']?.toString() ?? '',
      canRead: json['can_read'] == true,
      canStart: json['can_start'] == true,
      restrictedMode: json['restricted_mode'] == true,
      hasThread: json['has_thread'] == true,
      threadState: json['thread_state']?.toString() ?? '',
      threadId: json['thread_id']?.toString() ?? '',
    );
  }

  ChaputDecisionTarget copyWith({
    String? profileId,
    bool? canRead,
    bool? canStart,
    bool? restrictedMode,
    bool? hasThread,
    String? threadState,
    String? threadId,
  }) {
    return ChaputDecisionTarget(
      profileId: profileId ?? this.profileId,
      canRead: canRead ?? this.canRead,
      canStart: canStart ?? this.canStart,
      restrictedMode: restrictedMode ?? this.restrictedMode,
      hasThread: hasThread ?? this.hasThread,
      threadState: threadState ?? this.threadState,
      threadId: threadId ?? this.threadId,
    );
  }
}

class ChaputDecisionPlan {
  final String type; // FREE/PLUS/PRO
  final String? period; // MONTH/YEAR

  ChaputDecisionPlan({required this.type, required this.period});

  factory ChaputDecisionPlan.fromJson(Map<String, dynamic> json) {
    return ChaputDecisionPlan(
      type: json['type']?.toString() ?? 'FREE',
      period: json['period']?.toString(),
    );
  }

  ChaputDecisionPlan copyWith({String? type, String? period}) {
    return ChaputDecisionPlan(
      type: type ?? this.type,
      period: period ?? this.period,
    );
  }
}

class ChaputDecisionCredits {
  final int normal;
  final int hidden;
  final int special;
  final int revive;
  final int whisper;

  ChaputDecisionCredits({
    required this.normal,
    required this.hidden,
    required this.special,
    required this.revive,
    required this.whisper,
  });

  factory ChaputDecisionCredits.fromJson(Map<String, dynamic> json) {
    int v(String k) => (json[k] as num?)?.toInt() ?? 0;

    return ChaputDecisionCredits(
      normal: v('normal'),
      hidden: v('hidden'),
      special: v('special'),
      revive: v('revive'),
      whisper: v('whisper'),
    );
  }

  ChaputDecisionCredits copyWith({
    int? normal,
    int? hidden,
    int? special,
    int? revive,
    int? whisper,
  }) {
    return ChaputDecisionCredits(
      normal: normal ?? this.normal,
      hidden: hidden ?? this.hidden,
      special: special ?? this.special,
      revive: revive ?? this.revive,
      whisper: whisper ?? this.whisper,
    );
  }
}

class ChaputDecisionAds {
  final bool canWatch;
  final int watchedToday;
  final int rewardsToday;
  final int nextRewardIn;

  ChaputDecisionAds({
    required this.canWatch,
    required this.watchedToday,
    required this.rewardsToday,
    required this.nextRewardIn,
  });

  factory ChaputDecisionAds.fromJson(Map<String, dynamic> json) {
    int v(String k) => (json[k] as num?)?.toInt() ?? 0;

    return ChaputDecisionAds(
      canWatch: json['can_watch'] == true,
      watchedToday: v('watched_today'),
      rewardsToday: v('rewards_today'),
      nextRewardIn: v('next_reward_in'),
    );
  }

  ChaputDecisionAds copyWith({
    bool? canWatch,
    int? watchedToday,
    int? rewardsToday,
    int? nextRewardIn,
  }) {
    return ChaputDecisionAds(
      canWatch: canWatch ?? this.canWatch,
      watchedToday: watchedToday ?? this.watchedToday,
      rewardsToday: rewardsToday ?? this.rewardsToday,
      nextRewardIn: nextRewardIn ?? this.nextRewardIn,
    );
  }
}

class ChaputDecisionInfo {
  final String path;
  final String reason;

  ChaputDecisionInfo({required this.path, required this.reason});

  factory ChaputDecisionInfo.fromJson(Map<String, dynamic> json) {
    return ChaputDecisionInfo(
      path: json['path']?.toString() ?? 'FORBIDDEN',
      reason: json['reason']?.toString() ?? '',
    );
  }

  ChaputDecisionInfo copyWith({String? path, String? reason}) {
    return ChaputDecisionInfo(
      path: path ?? this.path,
      reason: reason ?? this.reason,
    );
  }
}
