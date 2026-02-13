import 'package:chaput/core/config/env.dart';
import 'package:chaput/core/router/routes.dart';
import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:chaput/features/billing/data/billing_api_provider.dart';
import 'package:chaput/features/me/application/me_controller.dart';
import 'package:chaput/features/profile/presentation/widgets/chaput_paywall_sheet.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chaput/core/ui/widgets/shimmer_skeleton.dart';
import 'package:go_router/go_router.dart';

import '../../application/archive_controller.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

class ArchiveChaputsScreen extends ConsumerWidget {
  const ArchiveChaputsScreen({super.key});

  Future<bool> _verifyPurchase(BuildContext context, WidgetRef ref, PaywallPurchase purchase) async {
    try {
      final api = ref.read(billingApiProvider);
      await api.verifyPurchase(
        provider: purchase.provider,
        productId: purchase.productId,
        transactionId: purchase.transactionId,
        devToken: Env.devBillingToken,
      );
      ref.read(meControllerProvider.notifier).fetchAndStoreMe();
      return true;
    } catch (_) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('billing.verify_failed'))),
      );
      return false;
    }
  }

  Future<PaywallPurchase?> _openPaywall(
    BuildContext context,
    WidgetRef ref, {
    required PaywallReviveTarget reviveTarget,
  }) async {
    final me = ref.read(meControllerProvider).valueOrNull;
    final planType = (me?.subscription.plan ?? 'FREE');
    return showModalBottomSheet<PaywallPurchase>(
      context: context,
      backgroundColor: AppColors.chaputTransparent,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (_) => FakePaywallSheet(
        feature: PaywallFeature.revive,
        planType: planType,
        reviveTarget: reviveTarget,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(archiveControllerProvider);
    final me = ref.watch(meControllerProvider).valueOrNull;
    final plan = (me?.subscription.plan ?? 'FREE').toUpperCase();
    final isPro = plan.contains('PRO');

    return Scaffold(
      backgroundColor: AppColors.chaputLightGrey,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.t('common.back'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => ref.read(archiveControllerProvider.notifier).refresh(),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.t('archive.title'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (st.isLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: st.isLoading && st.items.isEmpty
                        ? const _ArchiveShimmerList()
                        : st.error != null
                        ? Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(context.t(st.error!), style: const TextStyle(color: AppColors.chaputMaterialRed, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () => ref.read(archiveControllerProvider.notifier).refresh(),
                                  child: Text(context.t('common.retry')),
                                ),
                              ],
                            ),
                          )
                        : (st.items.isEmpty && !st.isLoading)
                            ? Center(
                                child: Text(
                                  context.t('common.empty'),
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.chaputBlack54),
                                ),
                              )
                            : NotificationListener<ScrollNotification>(
                                onNotification: (n) {
                                  if (st.hasMore && n.metrics.pixels >= n.metrics.maxScrollExtent - 220) {
                                    ref.read(archiveControllerProvider.notifier).loadMore();
                                  }
                                  return false;
                                },
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                  itemCount: st.items.length + 1,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, i) {
                                    if (i == st.items.length) {
                                      if (st.isLoadingMore) {
                                        return const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Center(
                                            child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox(height: 6);
                                    }

                                    final it = st.items[i];
                                    final u = st.usersById[it.otherUserId];

                                      final fullName = u?.fullName ?? context.t('common.na');
                                      final rawUsername = u?.username;
                                      final username = (rawUsername == null || rawUsername.isEmpty) ? it.otherUserId : rawUsername;
                                      final defaultAvatar = u?.defaultAvatar ?? '';
                                      final imgUrl = (u?.profilePhotoPath != null && u!.profilePhotoPath!.isNotEmpty)
                                          ? u.profilePhotoPath
                                          : defaultAvatar;

                                      final isDefault = u?.profilePhotoPath == null || u?.profilePhotoPath == '';
                                      final isBusy = st.revivingChaputId == it.threadId;

                                      final reviveTarget = PaywallReviveTarget(
                                        avatarUrl: imgUrl.toString(),
                                        isDefaultAvatar: isDefault,
                                        fullName: fullName,
                                        username: username,
                                      );

                                    return _ArchivedRow(
                                      fullName: fullName,
                                      subtitle: '@$username',
                                      avatarUrl: imgUrl.toString(),
                                      isDefaultAvatar: isDefault,
                                        onTap: () async {
                                          await context.push(await Routes.profile(it.otherUserId));
                                        },
                                        onRevive: isBusy
                                            ? null
                                            : () async {
                                                if (!isPro) {
                                                  final purchase = await _openPaywall(
                                                    context,
                                                    ref,
                                                    reviveTarget: reviveTarget,
                                                  );
                                                  if (purchase == null) return;
                                                  final ok = await _verifyPurchase(context, ref, purchase);
                                                  if (!ok) return;
                                                }
                                                final ok = await ref.read(archiveControllerProvider.notifier).revive(it.threadId);
                                                if (!context.mounted) return;
                                                if (ok) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text(context.t('archive.revived_ok'))),
                                                  );
                                                }
                                              },
                                        busy: isBusy,
                                    );
                                  },
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchivedRow extends StatelessWidget {
  final String fullName;
  final String subtitle;
  final String avatarUrl;
  final bool isDefaultAvatar;
  final VoidCallback? onTap;
  final VoidCallback? onRevive;
  final bool busy;

  const _ArchivedRow({
    required this.fullName,
    required this.subtitle,
    required this.avatarUrl,
    required this.isDefaultAvatar,
    required this.onTap,
    required this.onRevive,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.chaputWhite.withOpacity(0.96),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.chaputBlack.withOpacity(0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChaputCircleAvatar(
              width: 44,
              height: 44,
              radius: 999,
              borderWidth: 2,
              bgColor: AppColors.chaputBlack,
              isDefaultAvatar: isDefaultAvatar,
              imageUrl: avatarUrl,
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fullName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.chaputBlack.withOpacity(0.55), fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            const SizedBox(width: 10),

            SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: onRevive,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.chaputBlack,
                  foregroundColor: AppColors.chaputWhite,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.chaputWhite))
                    : Text(context.t('archive.revive'), style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveShimmerList extends StatelessWidget {
  const _ArchiveShimmerList();

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const ShimmerUserCard(
          radius: 20,
          line1Factor: 0.75,
          line2Factor: 0.55,
        ),
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final Widget child;
  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.chaputWhite.withOpacity(0.92),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            blurRadius: 26,
            offset: const Offset(0, 14),
            color: AppColors.chaputBlack.withOpacity(0.08),
          ),
        ],
      ),
      child: child,
    );
  }
}
