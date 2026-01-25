class CreditBalances {
  final int normal;
  final int hidden;
  final int special;
  final int pendingExtend;
  final int revive;

  CreditBalances({
    required this.normal,
    required this.hidden,
    required this.special,
    required this.pendingExtend,
    required this.revive,
  });

  factory CreditBalances.fromJson(Map<String, dynamic> json) {
    int v(String k) => (json[k] as num?)?.toInt() ?? 0;

    return CreditBalances(
      normal: v('normal'),
      hidden: v('hidden'),
      special: v('special'),
      pendingExtend: v('pending_extend'),
      revive: v('revive'),
    );
  }

  int get total =>
      normal + hidden + special + pendingExtend + revive;
}