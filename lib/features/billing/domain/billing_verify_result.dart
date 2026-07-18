class BillingVerifyResult {
  const BillingVerifyResult({
    required this.planType,
    required this.planPeriod,
    required this.expiresAt,
    required this.credits,
    required this.transactionId,
    required this.productId,
    required this.currency,
    required this.value,
  });

  final String planType;
  final String? planPeriod;
  final String? expiresAt;
  final BillingCredits credits;
  final String? transactionId;
  final String? productId;
  final String? currency;
  final double? value;

  factory BillingVerifyResult.fromJson(Map<String, dynamic> json) {
    final plan = (json['plan'] as Map<String, dynamic>?);
    final credits = (json['credits'] as Map<String, dynamic>?) ?? const {};
    final purchase = (json['purchase'] as Map<String, dynamic>?);

    return BillingVerifyResult(
      planType: plan?['type']?.toString() ?? 'FREE',
      planPeriod: plan?['period']?.toString(),
      expiresAt: plan?['expires_at']?.toString(),
      credits: BillingCredits.fromJson(credits),
      transactionId: _stringValue(
        purchase?['transaction_id'] ?? purchase?['transactionId'],
      ),
      productId: _stringValue(
        purchase?['product_id'] ?? purchase?['productId'],
      ),
      currency: _stringValue(purchase?['currency']),
      value: _doubleValue(purchase?['value']),
    );
  }

  static String? _stringValue(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static double? _doubleValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
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
