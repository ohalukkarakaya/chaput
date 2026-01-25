import 'package:chaput/features/user/domain/subscription_entitlement.dart';
import 'package:chaput/features/user/domain/today_usage.dart';

import 'credit_balances.dart';
import 'entitlement_limits.dart';
import 'me_entitlement.dart';

class ChaputEntitlements {
  final bool ok;
  final MeEntitlement me;
  final SubscriptionEntitlement subscription;
  final CreditBalances credits;
  final TodayUsage today;
  final EntitlementLimits limits;

  ChaputEntitlements({
    required this.ok,
    required this.me,
    required this.subscription,
    required this.credits,
    required this.today,
    required this.limits,
  });

  factory ChaputEntitlements.fromJson(Map<String, dynamic> json) {
    return ChaputEntitlements(
      ok: json['ok'] == true,
      me: MeEntitlement.fromJson(json['me'] as Map<String, dynamic>),
      subscription: SubscriptionEntitlement.fromJson(
        json['subscription'] as Map<String, dynamic>,
      ),
      credits: CreditBalances.fromJson(
        json['credits'] as Map<String, dynamic>,
      ),
      today: TodayUsage.fromJson(
        json['today'] as Map<String, dynamic>,
      ),
      limits: EntitlementLimits.fromJson(
        json['limits'] as Map<String, dynamic>,
      ),
    );
  }
}
