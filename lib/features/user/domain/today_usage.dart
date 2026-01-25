class TodayUsage {
  final int bindsFree;
  final int bindsPurchased;
  final int bindsAd;
  final int adUnlockedBinds;

  TodayUsage({
    required this.bindsFree,
    required this.bindsPurchased,
    required this.bindsAd,
    required this.adUnlockedBinds,
  });

  factory TodayUsage.fromJson(Map<String, dynamic> json) {
    int v(String k) => (json[k] as num?)?.toInt() ?? 0;

    return TodayUsage(
      bindsFree: v('binds_free'),
      bindsPurchased: v('binds_purchased'),
      bindsAd: v('binds_ad'),
      adUnlockedBinds: v('ad_unlocked_binds'),
    );
  }
}