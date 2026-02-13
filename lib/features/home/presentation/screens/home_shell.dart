import 'dart:async';

import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/ui/backgrounds/animated_mesh_background.dart';

import '../../../helpers/string_helpers/format_full_name.dart';
import '../../../me/application/me_controller.dart';
import '../../../notifications/application/notification_count_controller.dart';
import '../../../../chaput/data/chaput_socket.dart';
import '../../../notifications/application/push_token_registrar.dart';
import '../../../user_search/presentation/search_overlay.dart';
import '../../../recommended_users/application/recommended_user_controller.dart';
import '../../../../core/ui/widgets/glow_shimmer_card.dart';
import '../../../../core/ui/widgets/share_bar.dart';
import '../../../../core/ui/widgets/shimmer_skeleton.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  StreamSubscription<ChaputSocketEvent>? _socketSub;

  @override
  void initState() {
    super.initState();
    _bootNotifications();
  }

  Future<void> _bootNotifications() async {
    await ref.read(chaputSocketProvider).ensureConnected();
    _socketSub ??= ref.read(chaputSocketProvider).events.listen(_handleSocketEvent);
    await ref.read(pushTokenRegistrarProvider).registerOnce();
  }

  void _handleSocketEvent(ChaputSocketEvent ev) {
    if (ev.type != 'notif.created') return;
    final me = ref.read(meControllerProvider).valueOrNull;
    final meId = me?.user?.userId ?? '';
    if (meId.isEmpty) return;
    final raw = ev.data['notification'];
    var isForMe = false;
    if (raw is Map) {
      final userId = raw['user_id']?.toString() ?? '';
      if (userId.isEmpty) return;
      if (userId != meId) return;
      isForMe = true;
    }
    final unread = ev.data['unread_count'];
    if (isForMe) {
      if (unread is int) {
        ref.read(notificationCountControllerProvider.notifier).updateFromSocket(unread);
      } else if (unread is num) {
        ref.read(notificationCountControllerProvider.notifier).updateFromSocket(unread.toInt());
      }
    }
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _socketSub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chaputCloudBlue,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: AnimatedMeshBackground(
              baseColor: AppColors.chaputCloudBlue,
            ),
          ),

          // 🌳 ALT DEKOR (SafeArea DIŞINDA) → tam en alta, tam sağ/sola oturur
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.95,
                child: Image.asset(
                  'assets/images/tree_bg.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // ✅ UI katmanı (SafeArea içinde) → görselin üstünde kalır
          SafeArea(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ✅ Header + Search (üst)
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: SafeArea(
                    bottom: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Consumer(
                                    builder: (context, ref, _) {
                                      final meAsync =
                                      ref.watch(meControllerProvider);

                                      return meAsync.when(
                                        loading: () => const _HomeHeaderShimmer(),
                                        error: (_, __) => const SizedBox(height: 44),
                                        data: (me) {
                                          final rawName =
                                              me?.user.fullName ?? '';
                                          final fullName =
                                          formatFullName(rawName);
                                          final unread = ref.watch(notificationCountControllerProvider);
                                          return Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    context.t('home.welcome'),
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w300,
                                                      color: AppColors.chaputBlack
                                                          .withOpacity(0.55),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  InkWell(
                                                    borderRadius: BorderRadius.circular(12),
                                                    onTap: () => context.push(Routes.notifications),
                                                    child: Stack(
                                                      clipBehavior: Clip.none,
                                                      children: [
                                                        Icon(
                                                          Icons.keyboard_arrow_down,
                                                          size: 18,
                                                          color: AppColors.chaputBlack.withOpacity(0.6),
                                                        ),
                                                        if (unread > 0)
                                                          Positioned(
                                                            right: -6,
                                                            top: -6,
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: AppColors.chaputBlack,
                                                                borderRadius: BorderRadius.circular(10),
                                                              ),
                                                              child: Text(
                                                                unread > 99 ? '99+' : unread.toString(),
                                                                style: const TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight: FontWeight.w800,
                                                                  color: AppColors.chaputWhite,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                fullName.isEmpty
                                                    ? context.t('common.na')
                                                    : fullName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.chaputBlack,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Sağ: avatar
                                Consumer(
                                  builder: (context, ref, _) {
                                    final meAsync =
                                    ref.watch(meControllerProvider);

                                    return meAsync.when(
                                      loading: () => const _HomeAvatarShimmer(),
                                      error: (_, __) => const SizedBox(width: 40, height: 40),
                                      data: (me) {
                                        if (me == null) {
                                          return const SizedBox(
                                              width: 40, height: 40);
                                        }
                                        final user = me.user;

                                        return GestureDetector(
                                          onTap: () async => context.push(
                                            await Routes.profile(user.userId),
                                          ),
                                          child: ChaputCircleAvatar(
                                            width: 42,
                                            height: 42,
                                            radius: 999,
                                            borderWidth: 2,
                                            bgColor: AppColors.chaputBlack,
                                            isDefaultAvatar:
                                            user.profilePhotoUrl == null,
                                            imageUrl: user.profilePhotoUrl ??
                                                user.defaultAvatar!,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // ✅ Search bar
                            Hero(
                              tag: SearchOverlay.heroTag,
                              child: Material(
                                color: AppColors.chaputTransparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => Navigator.of(context)
                                      .push(_SearchOverlayRoute()),
                                  child: Container(
                                    height: 46,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.chaputWhite.withOpacity(0.92),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.search, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          context.t('search.hint'),
                                          style: TextStyle(
                                            color: AppColors.chaputBlack
                                                .withOpacity(0.55),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),
                            _RecommendedUserCard(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ✅ EN ALT: Share bar sabit (foreground)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Consumer(
                          builder: (context, ref, _) {
                            final meAsync = ref.watch(meControllerProvider);

                            return meAsync.when(
                              loading: () => const _ShareBarShimmer(),
                              error: (_, __) => const SizedBox(),
                              data: (me) {
                                if (me == null) return const SizedBox();

                                final username = me.user.username;
                                if (username == null || username.isEmpty) {
                                  return const SizedBox();
                                }

                                final link =
                                    'https://chaput.app/me/$username';

                                return ShareBar(
                                  link: link,
                                  title: context.t('home.share_title'),
                                  subtitle: context.t('home.share_subtitle'),
                                  showShareButton: false,
                                );

                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendedUserCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recAsync = ref.watch(recommendedUserControllerProvider);

    Widget wrap(Widget child) => GlowShimmerCard(
      radius: 22,
      glowSigma: 24,
      glowOpacity: 0.55,
      enableBlur: false,
      child: child,
    );

    return recAsync.when(
      loading: () => wrap(const _RecommendedUserShimmer()),
      error: (e, _) => wrap(
        Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.chaputWhite70),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.t('home.reco_failed'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => ref
                  .read(recommendedUserControllerProvider.notifier)
                  .refresh(),
              child: Text(context.t('common.retry')),
            ),
          ],
        ),
      ),
      data: (u) {
        if (u == null) {
          return wrap(
            Row(
              children: [
                const Icon(Icons.people_outline, color: AppColors.chaputWhite70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.t('home.reco_empty'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => ref
                      .read(recommendedUserControllerProvider.notifier)
                      .refresh(),
                  child: Text(context.t('common.refresh')),
                ),
              ],
            ),
          );
        }

        final isLoading = recAsync.isLoading;

        return wrap(
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async => context.push(await Routes.profile(u.id)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ChaputCircleAvatar(
                        width: 40,
                        height: 40,
                        radius: 999,
                        borderWidth: 2,
                        bgColor: AppColors.chaputBlack,
                        isDefaultAvatar: u.profilePhotoPath == null || u.profilePhotoPath!.isEmpty,
                        imageUrl: (u.profilePhotoPath != null && u.profilePhotoPath!.isNotEmpty)
                            ? u.profilePhotoPath!
                            : u.defaultAvatar,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.fullName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                          Text(
                            u.username == null ? context.t('common.na') : '@${u.username}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => ref
                    .read(recommendedUserControllerProvider.notifier)
                    .refresh(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.chaputBlack,
                  foregroundColor: AppColors.chaputWhite,
                  disabledBackgroundColor: AppColors.chaputBlack.withOpacity(0.6),
                  disabledForegroundColor: AppColors.chaputWhite.withOpacity(0.7),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: isLoading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.chaputWhite),
                  ),
                )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  isLoading ? context.t('common.loading') : context.t('common.refresh'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeHeaderShimmer extends StatelessWidget {
  const _HomeHeaderShimmer();

  @override
  Widget build(BuildContext context) {
    return const ShimmerLoading(
      child: SizedBox(
        height: 44,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerLine(width: 90, height: 10),
            SizedBox(height: 8),
            ShimmerLine(width: 160, height: 16),
          ],
        ),
      ),
    );
  }
}

class _HomeAvatarShimmer extends StatelessWidget {
  const _HomeAvatarShimmer();

  @override
  Widget build(BuildContext context) {
    return const ShimmerLoading(
      child: ShimmerCircle(size: 42),
    );
  }
}

class _ShareBarShimmer extends StatelessWidget {
  const _ShareBarShimmer();

  @override
  Widget build(BuildContext context) {
    return const ShimmerLoading(
      child: ShimmerBlock(
        height: 52,
        radius: 18,
      ),
    );
  }
}

class _RecommendedUserShimmer extends StatelessWidget {
  const _RecommendedUserShimmer();

  @override
  Widget build(BuildContext context) {
    return const ShimmerLoading(
      child: Row(
        children: [
          ShimmerCircle(size: 40),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLine(width: 140, height: 12),
                SizedBox(height: 6),
                ShimmerLine(width: 90, height: 10),
              ],
            ),
          ),
          SizedBox(width: 12),
          ShimmerBlock(width: 72, height: 32, radius: 12),
        ],
      ),
    );
  }
}

class _SearchOverlayRoute extends PageRouteBuilder<void> {
  _SearchOverlayRoute()
      : super(
    opaque: false,
    barrierDismissible: true,
    barrierColor: AppColors.chaputTransparent,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) =>
    const SearchOverlay(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
      CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}
