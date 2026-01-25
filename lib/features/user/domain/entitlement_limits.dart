class EntitlementLimits {
  final int dailyFreeQuota;
  final int dailyAdBindCap;

  EntitlementLimits({
    required this.dailyFreeQuota,
    required this.dailyAdBindCap,
  });

  factory EntitlementLimits.fromJson(Map<String, dynamic> json) {
    int v(String k) => (json[k] as num?)?.toInt() ?? 0;

    return EntitlementLimits(
      dailyFreeQuota: v('daily_free_quota'),
      dailyAdBindCap: v('daily_ad_bind_cap'),
    );
  }
}