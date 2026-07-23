import 'dart:async';
import 'dart:developer' as developer;

import 'package:chaput/core/config/env.dart';
import 'package:chaput/core/router/routes.dart';
import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:chaput/features/billing/data/billing_api_provider.dart';
import 'package:chaput/features/billing/domain/billing_verify_result.dart';
import 'package:chaput/features/me/application/me_controller.dart';
import 'package:chaput/features/profile/presentation/widgets/chaput_paywall_sheet.dart';
import 'package:chaput/features/revenuecat/data/revenue_cat_service.dart';
import 'package:chaput/features/settings/data/account_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chaput/core/ui/widgets/empty_state_illustration.dart';
import 'package:chaput/core/ui/widgets/shimmer_skeleton.dart';
import 'package:go_router/go_router.dart';

import '../../application/archive_controller.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

class ArchiveChaputsScreen extends ConsumerWidget {
  const ArchiveChaputsScreen({super.key});

  Future<bool> _verifyPurchase(
    BuildContext context,
    WidgetRef ref,
    PaywallPurchase purchase,
  ) async {
    try {
      final api = ref.read(billingApiProvider);
      BillingVerifyResult? result;
      Object? lastError;
      final attempts = purchase.provider == 'REVENUECAT' ? 6 : 1;
      for (int i = 0; i < attempts; i++) {
        try {
          result = await api.verifyPurchase(
            provider: purchase.provider,
            productId: purchase.productId,
            transactionId: purchase.transactionId,
            devToken: Env.devBillingToken,
          );
          break;
        } catch (e) {
          lastError = e;
          if (purchase.provider != 'REVENUECAT' ||
              !e.toString().contains('pending_webhook') ||
              i == attempts - 1) {
            rethrow;
          }
          await Future.delayed(Duration(milliseconds: 850 + (i * 450)));
        }
      }
      if (result == null) throw lastError ?? Exception('verify_failed');
      unawaited(
        ref.read(meControllerProvider.notifier).fetchAndStoreMe().catchError((
          _,
        ) {
          return ref.read(meControllerProvider).value;
        }),
      );
      return true;
    } catch (_) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('billing.verify_failed'))),
      );
      return false;
    }
  }

  Future<PaywallPurchase?> _purchaseWithRevenueCat(
    BuildContext context,
    WidgetRef ref,
    String productId,
  ) async {
    final userId = ref.read(meControllerProvider).value?.user.userId;
    if (userId == null || userId.isEmpty) {
      developer.log('RevenueCat purchase blocked: missing backend user id');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('paywall.purchase_failed'))),
        );
      }
      return null;
    }

    final loginResult = await RevenueCatService.instance.logInWithBackendUserId(
      userId,
    );
    if (!loginResult.isSuccess) {
      developer.log(
        'RevenueCat login before purchase failed status=${loginResult.status} '
        'code=${loginResult.errorCode} message=${loginResult.message}',
        error: loginResult.exception,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_revenueCatFailureText(context, loginResult))),
        );
      }
      return null;
    }

    final result = await RevenueCatService.instance.purchaseProductId(
      productId,
    );
    if (result.isCancelled) return null;
    if (!result.isSuccess || result.data == null) {
      developer.log(
        'RevenueCat purchase failed product=$productId status=${result.status} '
        'code=${result.errorCode} message=${result.message}',
        error: result.exception,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_revenueCatFailureText(context, result))),
        );
      }
      return null;
    }

    final transaction = result.data!.storeTransaction;
    final transactionId = transaction.transactionIdentifier.isNotEmpty
        ? transaction.transactionIdentifier
        : 'revenuecat_${DateTime.now().millisecondsSinceEpoch}_$productId';

    return PaywallPurchase(
      productId: result.data!.productId,
      provider: 'REVENUECAT',
      transactionId: transactionId,
    );
  }

  String _revenueCatFailureText(
    BuildContext context,
    RevenueCatResult<dynamic> result,
  ) {
    return switch (result.status) {
      RevenueCatResultStatus.invalidRequest ||
      RevenueCatResultStatus.notInitialized => context.t(
        'paywall.purchase_not_configured',
      ),
      RevenueCatResultStatus.productNotFound => context.t(
        'paywall.product_not_found',
      ),
      RevenueCatResultStatus.networkError => context.t(
        'paywall.purchase_network_failed',
      ),
      _ => context.t('paywall.purchase_failed'),
    };
  }

  Future<bool> _restorePurchasesWithRevenueCat(WidgetRef ref) async {
    final userId = ref.read(meControllerProvider).value?.user.userId;
    if (userId != null && userId.isNotEmpty) {
      await RevenueCatService.instance.logInWithBackendUserId(userId);
    }

    final revenueCatResult = await RevenueCatService.instance
        .restorePurchases();
    if (!revenueCatResult.isSuccess) {
      return false;
    }

    final restored = await ref.read(accountApiProvider).restorePurchases();
    await ref.read(meControllerProvider.notifier).fetchAndStoreMe();
    return restored || revenueCatResult.data?.hasChaputSubscription == true;
  }

  Future<PaywallPurchase?> _openPaywall(
    BuildContext context,
    WidgetRef ref, {
    required PaywallReviveTarget reviveTarget,
  }) async {
    final me = ref.read(meControllerProvider).value;
    final planType = (me?.subscription.plan ?? 'FREE');
    return showModalBottomSheet<PaywallPurchase>(
      context: context,
      backgroundColor: AppColors.chaputTransparent,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (_) => FakePaywallSheet(
        feature: PaywallFeature.revive,
        planType: planType,
        appUserId: me?.user.userId,
        reviveTarget: reviveTarget,
        onPurchaseProduct: (productId) =>
            _purchaseWithRevenueCat(context, ref, productId),
        onRestorePurchases: () => _restorePurchasesWithRevenueCat(ref),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(archiveControllerProvider);
    final me = ref.watch(meControllerProvider).value;
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
                      IconButton(
                        tooltip: context.t('common.back'),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.arrow_back_ios),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(archiveControllerProvider.notifier)
                              .refresh();
                        },
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
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
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
                                Text(
                                  context.t(st.error!),
                                  style: const TextStyle(
                                    color: AppColors.chaputMaterialRed,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () => ref
                                      .read(archiveControllerProvider.notifier)
                                      .refresh(),
                                  child: Text(context.t('common.retry')),
                                ),
                              ],
                            ),
                          )
                        : (st.items.isEmpty && !st.isLoading)
                        ? const EmptyStateIllustration(
                            assetPath:
                                'assets/images/empty_state/archive_empty_state.png',
                          )
                        : NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (st.hasMore &&
                                  n.metrics.pixels >=
                                      n.metrics.maxScrollExtent - 220) {
                                ref
                                    .read(archiveControllerProvider.notifier)
                                    .loadMore();
                              }
                              return false;
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                12,
                                12,
                              ),
                              itemCount: st.items.length + 1,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                if (i == st.items.length) {
                                  if (st.isLoadingMore) {
                                    return const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Center(
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox(height: 6);
                                }

                                final it = st.items[i];
                                final u = st.usersById[it.otherUserId];

                                final fullName =
                                    u?.fullName ?? context.t('common.na');
                                final rawUsername = u?.username;
                                final username =
                                    (rawUsername == null || rawUsername.isEmpty)
                                    ? it.otherUserId
                                    : rawUsername;
                                final defaultAvatar = u?.defaultAvatar ?? '';
                                final imgUrl =
                                    (u?.profilePhotoPath != null &&
                                        u!.profilePhotoPath!.isNotEmpty)
                                    ? u.profilePhotoPath
                                    : defaultAvatar;

                                final isDefault =
                                    u?.profilePhotoPath == null ||
                                    u?.profilePhotoPath == '';
                                final isBusy =
                                    st.revivingChaputId == it.threadId;

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
                                    await context.push(
                                      await Routes.profile(it.otherUserId),
                                    );
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
                                            final ok = await _verifyPurchase(
                                              context,
                                              ref,
                                              purchase,
                                            );
                                            if (!ok) return;
                                          }
                                          final ok = await ref
                                              .read(
                                                archiveControllerProvider
                                                    .notifier,
                                              )
                                              .revive(it.threadId);
                                          if (!context.mounted) return;
                                          if (ok) {
                                            HapticFeedback.mediumImpact();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  context.t(
                                                    'archive.revived_ok',
                                                  ),
                                                ),
                                              ),
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
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.chaputWhite.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.chaputBlack.withValues(alpha: 0.06),
          ),
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
                  Text(
                    fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.chaputBlack.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: onRevive == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onRevive!();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.chaputBlack,
                  foregroundColor: AppColors.chaputWhite,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.chaputWhite,
                        ),
                      )
                    : Text(
                        context.t('archive.revive'),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
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
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => const ShimmerUserCard(
          radius: 20,
          line1Factor: 0.75,
          line2Factor: 0.55,
        ),
      ),
    );
  }
}
