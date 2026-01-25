class SubscriptionEntitlement {
  final String plan;
  final String status;
  final DateTime? expiresAt;

  SubscriptionEntitlement({
    required this.plan,
    required this.status,
    required this.expiresAt,
  });

  factory SubscriptionEntitlement.fromJson(Map<String, dynamic> json) {
    return SubscriptionEntitlement(
      plan: json['plan'] as String,
      status: json['status'] as String,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'])
          : null,
    );
  }
}