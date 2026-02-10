import 'package:flutter/material.dart';

import '../../../../core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import '../../../../core/i18n/app_localizations.dart';
import 'sheet_handle.dart';
import 'package:chaput/core/constants/app_colors.dart';

enum PaywallFeature { bind, hideCredentials, boost, whisper, revive }

class PaywallPurchase {
  const PaywallPurchase({
    required this.productId,
    required this.provider,
    required this.transactionId,
  });

  final String productId;
  final String provider; // DEV / APPLE / GOOGLE
  final String transactionId;
}

class FakePaywallSheet extends StatefulWidget {
  const FakePaywallSheet({
    super.key,
    required this.feature,
    this.planType = 'FREE',
    this.planPeriod,
    this.reviveTarget,
  });

  final PaywallFeature feature;
  final String planType;
  final String? planPeriod;
  final PaywallReviveTarget? reviveTarget;

  @override
  State<FakePaywallSheet> createState() => _FakePaywallSheetState();
}

class _FakePaywallSheetState extends State<FakePaywallSheet> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.padding.bottom;
    final planType = widget.planType.toUpperCase();
    final planPeriod = widget.planPeriod?.toUpperCase();
    final isPro = planType == 'PRO' || planType.contains('PRO');
    final isPlus = planType == 'PLUS' || planType.contains('PLUS');
    final isFree = !isPro && !isPlus;
    final isProMonthly = isPro && planPeriod == 'MONTH';
    final isProYearly = isPro && planPeriod == 'YEAR';
    final t = context.t;

    final title = widget.feature == PaywallFeature.bind
        ? t('paywall.title.bind')
        : (widget.feature == PaywallFeature.hideCredentials
            ? t('paywall.title.hidden')
            : widget.feature == PaywallFeature.whisper
                ? t('paywall.title.whisper')
                : widget.feature == PaywallFeature.revive
                    ? t('paywall.title.revive')
                : t('paywall.title.boost'));

    final subtitle = widget.feature == PaywallFeature.bind
        ? t('paywall.subtitle.bind')
        : (widget.feature == PaywallFeature.hideCredentials
            ? t('paywall.subtitle.hidden')
            : widget.feature == PaywallFeature.whisper
                ? t('paywall.subtitle.whisper')
                : widget.feature == PaywallFeature.revive
                    ? t('paywall.subtitle.revive')
                : t('paywall.subtitle.boost'));

    final proMonthly = PaywallPlan(
      badge: t('paywall.badge.monthly'),
      title: t('paywall.plan.pro'),
      price: t('paywall.price_per_month', params: {'price': '€9.99'}),
      hint: t(
        'paywall.hint.all_rights_bonus',
        params: {'hidden': '5', 'special': '4', 'whisper': '30'},
      ),
      productId: 'chaput_pro_month',
      bullets: [
        t('paywall.bullets.unlimited_chaput'),
        t('paywall.bullets.gift_hidden', params: {'count': '5'}),
        t('paywall.bullets.gift_special', params: {'count': '4'}),
        t('paywall.bullets.gift_whisper', params: {'count': '30'}),
      ],
    );

    final proYearly = PaywallPlan(
      badge: t('paywall.badge.yearly'),
      title: t('paywall.plan.pro_yearly'),
      price: t('paywall.price_per_year', params: {'price': '€79.99'}),
      hint: t(
        'paywall.hint.two_months_free_fake',
        params: {'hidden': '5', 'special': '4', 'whisper': '30'},
      ),
      productId: 'chaput_pro_year',
      bullets: [
        t('paywall.bullets.unlimited_chaput'),
        t('paywall.bullets.gift_hidden', params: {'count': '5'}),
        t('paywall.bullets.gift_special', params: {'count': '4'}),
        t('paywall.bullets.gift_whisper', params: {'count': '30'}),
      ],
    );

    final plusMonthly = PaywallPlan(
      badge: t('paywall.badge.popular'),
      title: t('paywall.plan.plus'),
      price: t('paywall.price_per_month', params: {'price': '€4.99'}),
      hint: t(
        'paywall.hint.hidden_plus_boost',
        params: {'hidden': '2', 'special': '1', 'whisper': '10'},
      ),
      productId: 'chaput_plus_month',
      bullets: [
        t('paywall.bullets.daily_chaput', params: {'count': '5'}),
        t('paywall.bullets.gift_hidden', params: {'count': '2'}),
        t('paywall.bullets.gift_special', params: {'count': '1'}),
        t('paywall.bullets.gift_whisper', params: {'count': '10'}),
      ],
    );

    final plans = <PaywallPlan>[
      if (widget.feature != PaywallFeature.revive) ...[
        if (isFree) plusMonthly,
        if (isFree || isPlus) proMonthly,
        if (isFree || isPlus || isProMonthly) proYearly,
      ] else ...[
        if (isFree || isPlus) proMonthly,
        if (isFree || isPlus || isProMonthly) proYearly,
      ],
    ];
    final selectedIndex = plans.isEmpty ? 0 : _selectedIndex.clamp(0, plans.length - 1);

    final singles = widget.feature == PaywallFeature.bind
        ? <PaywallSingle>[
            PaywallSingle(
              title: t('paywall.single.chaput_right', params: {'count': '1'}),
              price: '€0.99',
              caption: t('paywall.single.bind_caption', params: {'count': '1'}),
              productId: 'chaput_bind_1',
            ),
            PaywallSingle(
              title: t('paywall.single.chaput_pack', params: {'count': '5'}),
              price: '€3.49',
              caption: t('paywall.single.bind_caption', params: {'count': '5'}),
              productId: 'chaput_bind_5',
            ),
            PaywallSingle(
              title: t('paywall.single.chaput_pack', params: {'count': '20'}),
              price: '€9.99',
              caption: t('paywall.single.best_value_fake'),
              productId: 'chaput_bind_20',
            ),
          ]
        : widget.feature == PaywallFeature.hideCredentials
        ? <PaywallSingle>[
            PaywallSingle(
              title: t('paywall.single.hidden_right', params: {'count': '1'}),
              price: '€0.99',
              caption: t('paywall.single.hidden_caption', params: {'count': '1'}),
              productId: 'chaput_hidden_1',
            ),
            PaywallSingle(
              title: t('paywall.single.hidden_pack', params: {'count': '5'}),
              price: '€3.49',
              caption: t('paywall.single.hidden_caption', params: {'count': '5'}),
              productId: 'chaput_hidden_5',
            ),
            PaywallSingle(
              title: t('paywall.single.hidden_pack', params: {'count': '20'}),
              price: '€9.99',
              caption: t('paywall.single.best_value_fake'),
              productId: 'chaput_hidden_20',
            ),
          ]
        : widget.feature == PaywallFeature.whisper
        ? <PaywallSingle>[
            PaywallSingle(
              title: t('paywall.single.whisper', params: {'count': '1'}),
              price: '€0.79',
              caption: t('paywall.single.whisper_caption', params: {'count': '1'}),
              productId: 'chaput_whisper_1',
            ),
            PaywallSingle(
              title: t('paywall.single.whisper', params: {'count': '10'}),
              price: '€3.49',
              caption: t('paywall.single.whisper_caption', params: {'count': '10'}),
              productId: 'chaput_whisper_10',
            ),
            PaywallSingle(
              title: t('paywall.single.whisper', params: {'count': '30'}),
              price: '€7.99',
              caption: t('paywall.single.best_value_fake'),
              productId: 'chaput_whisper_30',
            ),
          ]
        : widget.feature == PaywallFeature.revive
        ? <PaywallSingle>[
            PaywallSingle(
              title: t('paywall.single.revive', params: {'count': '1'}),
              price: '€0.99',
              caption: t('paywall.single.revive_caption', params: {'count': '1'}),
              productId: 'chaput_revive_1',
            ),
          ]
        : <PaywallSingle>[
            PaywallSingle(
              title: t('paywall.single.boost', params: {'count': '1'}),
              price: '€0.79',
              caption: t('paywall.single.boost_caption', params: {'count': '1'}),
              productId: 'chaput_special_1',
            ),
            PaywallSingle(
              title: t('paywall.single.boost', params: {'count': '5'}),
              price: '€2.99',
              caption: t('paywall.single.boost_caption', params: {'count': '5'}),
              productId: 'chaput_special_5',
            ),
            PaywallSingle(
              title: t('paywall.single.boost', params: {'count': '20'}),
              price: '€8.99',
              caption: t('paywall.single.best_value_fake'),
              productId: 'chaput_special_20',
            ),
          ];

    String _txId() {
      final now = DateTime.now().millisecondsSinceEpoch;
      return 'dev_${now}_$_selectedIndex';
    }

    PaywallPurchase _planPurchase() {
      return PaywallPurchase(
        productId: plans[selectedIndex].productId,
        provider: 'DEV',
        transactionId: _txId(),
      );
    }

    PaywallPurchase _singlePurchase(PaywallSingle item) {
      return PaywallPurchase(
        productId: item.productId,
        provider: 'DEV',
        transactionId: _txId(),
      );
    }

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: mq.size.height * 0.92,
            ),
            child: Container(
              padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 12),
              decoration: const BoxDecoration(
                color: AppColors.chaputWhite,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SheetHandle(),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.chaputBlack,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.chaputBlack.withOpacity(0.65),
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkResponse(
                            radius: 22,
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.chaputBlack.withOpacity(0.06),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 20, color: AppColors.chaputBlack),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Revive hedef kartı artık tekli satın al bölümünün yerinde gösterilecek.

                    const SizedBox(height: 14),

                    if (plans.isNotEmpty) ...[
                      SizedBox(
                        height: 170,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (_, i) {
                            final p = plans[i];
                          final selected = i == selectedIndex;

                            return PlanCard(
                              plan: p,
                              selected: selected,
                            onTap: () => setState(() => _selectedIndex = i),
                          );
                        },
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemCount: plans.length,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: PlanBullets(plan: plans[selectedIndex]),
                      ),

                      const SizedBox(height: 14),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context, _planPurchase());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.chaputBlack,
                              foregroundColor: AppColors.chaputWhite,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: Text(
                              t('paywall.action_unlock_with', params: {'plan': plans[selectedIndex].title}),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),
                    ],

                    if (widget.feature == PaywallFeature.revive && widget.reviveTarget != null) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                        child: Row(
                          children: [
                            Text(
                              t('paywall.section.revive_purchase'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppColors.chaputBlack.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _ReviveTargetCard(
                        target: widget.reviveTarget!,
                        onTap: () {
                          if (singles.isNotEmpty) {
                            Navigator.pop(context, _singlePurchase(singles.first));
                          }
                        },
                        priceLabel: singles.isNotEmpty ? singles.first.price : '€0.99',
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                        child: Row(
                          children: [
                            Text(
                              t('paywall.section.single_purchase'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: AppColors.chaputBlack.withOpacity(0.85),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              t('paywall.section.as_needed'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.chaputBlack.withOpacity(0.55),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (_, i) => SingleCard(
                            item: singles[i],
                            onTap: () {
                              Navigator.pop(context, _singlePurchase(singles[i]));
                            },
                          ),
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemCount: singles.length,
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        t('paywall.disclaimer_demo'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.chaputBlack.withOpacity(0.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PaywallReviveTarget {
  const PaywallReviveTarget({
    required this.avatarUrl,
    required this.isDefaultAvatar,
    required this.fullName,
    required this.username,
  });

  final String avatarUrl;
  final bool isDefaultAvatar;
  final String fullName;
  final String username;
}

class _ReviveTargetCard extends StatelessWidget {
  const _ReviveTargetCard({
    required this.target,
    required this.onTap,
    required this.priceLabel,
  });

  final PaywallReviveTarget target;
  final VoidCallback onTap;
  final String priceLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.chaputBlack.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.chaputBlack.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              ChaputCircleAvatar(
                isDefaultAvatar: target.isDefaultAvatar,
                imageUrl: target.avatarUrl,
                width: 44,
                height: 44,
                radius: 44,
                borderWidth: 0,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.fullName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${target.username}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.chaputBlack.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.chaputBlack,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Kurtar',
                  style: TextStyle(color: AppColors.chaputWhite, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                priceLabel,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.chaputBlack.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PaywallPlan {
  PaywallPlan({
    required this.badge,
    required this.title,
    required this.price,
    required this.hint,
    required this.productId,
    required this.bullets,
  });

  final String badge;
  final String title;
  final String price;
  final String hint;
  final String productId;
  final List<String> bullets;
}

class PaywallSingle {
  PaywallSingle({
    required this.title,
    required this.price,
    required this.caption,
    required this.productId,
  });

  final String title;
  final String price;
  final String caption;
  final String productId;
}

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final PaywallPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        width: 240,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.chaputBlack : AppColors.chaputWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.chaputBlack : AppColors.chaputBlack.withOpacity(0.10),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              spreadRadius: 0,
              offset: const Offset(0, 10),
              color: AppColors.chaputBlack.withOpacity(selected ? 0.25 : 0.08),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.chaputWhite.withOpacity(0.14) : AppColors.chaputBlack.withOpacity(0.06),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                plan.badge,
                style: TextStyle(
                  color: selected ? AppColors.chaputWhite : AppColors.chaputBlack.withOpacity(0.70),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              plan.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: selected ? AppColors.chaputWhite : AppColors.chaputBlack,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              plan.price,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.chaputWhite.withOpacity(0.92) : AppColors.chaputBlack.withOpacity(0.85),
              ),
            ),
            const Spacer(),
            Text(
              plan.hint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.chaputWhite.withOpacity(0.70) : AppColors.chaputBlack.withOpacity(0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlanBullets extends StatelessWidget {
  const PlanBullets({super.key, required this.plan});
  final PaywallPlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.chaputBlack.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.chaputBlack.withOpacity(0.06)),
      ),
      child: Column(
        children: plan.bullets
            .map(
              (t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.chaputBlack,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.check, size: 12, color: AppColors.chaputWhite),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.chaputBlack.withOpacity(0.78),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class SingleCard extends StatelessWidget {
  const SingleCard({super.key, required this.item, required this.onTap});
  final PaywallSingle item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.chaputWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.chaputBlack.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(
              blurRadius: 14,
              offset: const Offset(0, 10),
              color: AppColors.chaputBlack.withOpacity(0.06),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: AppColors.chaputBlack,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 2),

            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  item.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.chaputBlack.withOpacity(0.55),
                    height: 1.05,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),

            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.price,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.chaputBlack,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.chaputBlack,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, size: 15, color: AppColors.chaputWhite),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
