class BillingVerifyResult {
  const BillingVerifyResult({
    required this.planType,
    required this.expiresAt,
    required this.credits,
  });

  final String planType;
  final String? expiresAt;
  final BillingCredits credits;

  factory BillingVerifyResult.fromJson(Map<String, dynamic> json) {
    final plan = (json['plan'] as Map<String, dynamic>?);
    final credits = (json['credits'] as Map<String, dynamic>?) ?? const {};

    return BillingVerifyResult(
      planType: plan?['type']?.toString() ?? 'FREE',
      expiresAt: plan?['expires_at']?.toString(),
      credits: BillingCredits.fromJson(credits),
    );
  }
}

class BillingCredits {
  const BillingCredits({
    required this.normal,
    required this.hidden,
    required this.special,
    required this.revive,
    required this.whisper,
  });

  final int normal;
  final int hidden;
  final int special;
  final int revive;
  final int whisper;

  factory BillingCredits.fromJson(Map<String, dynamic> json) {
    int v(String k) => (json[k] as num?)?.toInt() ?? 0;
    return BillingCredits(
      normal: v('normal'),
      hidden: v('hidden'),
      special: v('special'),
      revive: v('revive'),
      whisper: v('whisper'),
    );
  }
}
