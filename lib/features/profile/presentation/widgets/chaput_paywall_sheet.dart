import 'package:flutter/material.dart';

import 'sheet_handle.dart';

enum PaywallFeature { bind, hideCredentials, boost, whisper }

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
  });

  final PaywallFeature feature;
  final String planType;
  final String? planPeriod;

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

    final title = widget.feature == PaywallFeature.bind
        ? 'Chaput Bağlama Hakkı'
        : (widget.feature == PaywallFeature.hideCredentials
            ? 'Anonim Chaput'
            : widget.feature == PaywallFeature.whisper
                ? 'Fısıltı Mesajı'
                : 'Öne Çıkar');

    final subtitle = widget.feature == PaywallFeature.bind
        ? 'Bugün hakkın bitti. Hemen hak satın al veya paket seç.'
        : (widget.feature == PaywallFeature.hideCredentials
            ? 'Kimliğini gizleyerek chaput bağla. Daha özgür, daha güvenli.'
            : widget.feature == PaywallFeature.whisper
                ? 'Fısıltı mesajları yalnızca taraflara görünür.'
                : 'Chaputunu daha görünür yap. Daha fazla kişi görsün.');

    final proMonthly = PaywallPlan(
      badge: 'AYLIK',
      title: 'Pro',
      price: '€9.99 / ay',
      hint: 'Tüm haklar + bonus',
      productId: 'chaput_pro_month',
      bullets: const [
        'Anonim chaput',
        'Öne çıkarma',
        'Daha fazla günlük boost',
        'Özel rozet (fake)',
      ],
    );

    final proYearly = PaywallPlan(
      badge: 'YILLIK',
      title: 'Pro Yıllık',
      price: '€79.99 / yıl',
      hint: '2 ay bedava (fake)',
      productId: 'chaput_pro_year',
      bullets: const [
        'Tüm Pro ayrıcalıkları',
        'Daha ucuz yıllık fiyat',
        'Erken erişim (fake)',
      ],
    );

    final plusMonthly = PaywallPlan(
      badge: 'EN POPÜLER',
      title: 'Plus',
      price: '€4.99 / ay',
      hint: 'Anonim + Öne çıkar',
      productId: 'chaput_plus_month',
      bullets: const [
        'Anonim chaput',
        'Öne çıkarma',
        'Daha yüksek görünürlük',
        'Öncelikli destek (fake)',
      ],
    );

    final plans = <PaywallPlan>[
      if (isFree) plusMonthly,
      if (isFree || isPlus) proMonthly,
      if (isFree || isPlus || isProMonthly) proYearly,
    ];
    final selectedIndex = plans.isEmpty ? 0 : _selectedIndex.clamp(0, plans.length - 1);

    final singles = widget.feature == PaywallFeature.bind
        ? <PaywallSingle>[
            PaywallSingle(title: 'Chaput Hak (1)', price: '€0.99', caption: '1 chaput bağla', productId: 'chaput_bind_1'),
            PaywallSingle(title: 'Chaput Paket (5)', price: '€3.49', caption: '5 chaput bağla', productId: 'chaput_bind_5'),
            PaywallSingle(title: 'Chaput Paket (20)', price: '€9.99', caption: 'En uygun (fake)', productId: 'chaput_bind_20'),
          ]
        : widget.feature == PaywallFeature.hideCredentials
        ? <PaywallSingle>[
            PaywallSingle(title: 'Anonim Hak (1)', price: '€0.99', caption: '1 chaput anonim', productId: 'chaput_hidden_1'),
            PaywallSingle(title: 'Anonim Paket (5)', price: '€3.49', caption: '5 chaput anonim', productId: 'chaput_hidden_5'),
            PaywallSingle(title: 'Anonim Paket (20)', price: '€9.99', caption: 'En uygun (fake)', productId: 'chaput_hidden_20'),
          ]
        : widget.feature == PaywallFeature.whisper
        ? <PaywallSingle>[
            PaywallSingle(title: 'Fısıltı (1)', price: '€0.79', caption: '1 fısıltı mesajı', productId: 'chaput_whisper_1'),
            PaywallSingle(title: 'Fısıltı (10)', price: '€3.49', caption: '10 fısıltı mesajı', productId: 'chaput_whisper_10'),
            PaywallSingle(title: 'Fısıltı (30)', price: '€7.99', caption: 'En uygun (fake)', productId: 'chaput_whisper_30'),
          ]
        : <PaywallSingle>[
            PaywallSingle(title: 'Boost (1)', price: '€0.79', caption: '1 kez öne çıkar', productId: 'chaput_special_1'),
            PaywallSingle(title: 'Boost (5)', price: '€2.99', caption: '5 kez öne çıkar', productId: 'chaput_special_5'),
            PaywallSingle(title: 'Boost (20)', price: '€8.99', caption: 'En uygun (fake)', productId: 'chaput_special_20'),
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
                color: Colors.white,
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
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black.withOpacity(0.65),
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
                                color: Colors.black.withOpacity(0.06),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 20, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),

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
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: Text(
                              '${plans[selectedIndex].title} ile aç',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),
                    ],

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Row(
                        children: [
                          Text(
                            'Tekli satın al',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Colors.black.withOpacity(0.85),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'İhtiyacın kadar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black.withOpacity(0.55),
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

                    const SizedBox(height: 10),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Bu ekran şimdilik demo. Fiyatlar ve haklar örnektir.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black.withOpacity(0.45),
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
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Colors.black : Colors.black.withOpacity(0.10),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              spreadRadius: 0,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(selected ? 0.25 : 0.08),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withOpacity(0.14) : Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                plan.badge,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black.withOpacity(0.70),
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
                color: selected ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              plan.price,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white.withOpacity(0.92) : Colors.black.withOpacity(0.85),
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
                color: selected ? Colors.white.withOpacity(0.70) : Colors.black.withOpacity(0.55),
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
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
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
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.check, size: 12, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black.withOpacity(0.78),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(
              blurRadius: 14,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(0.06),
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
                color: Colors.black,
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
                    color: Colors.black.withOpacity(0.55),
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
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, size: 15, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
