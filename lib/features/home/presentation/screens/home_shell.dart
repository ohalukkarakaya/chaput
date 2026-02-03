import 'dart:async';

import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:flutter/material.dart';
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
      backgroundColor: const Color(0xffE9EEF3),
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(
            child: AnimatedMeshBackground(
              baseColor: Color(0xffE9EEF3),
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
                                        loading: () =>
                                        const SizedBox(height: 44),
                                        error: (_, __) =>
                                        const SizedBox(height: 44),
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
                                                    'Hoş geldin',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w300,
                                                      color: Colors.black
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
                                                          color: Colors.black.withOpacity(0.6),
                                                        ),
                                                        if (unread > 0)
                                                          Positioned(
                                                            right: -6,
                                                            top: -6,
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: Colors.black,
                                                                borderRadius: BorderRadius.circular(10),
                                                              ),
                                                              child: Text(
                                                                unread > 99 ? '99+' : unread.toString(),
                                                                style: const TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight: FontWeight.w800,
                                                                  color: Colors.white,
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
                                                    ? '—'
                                                    : fullName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.black,
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
                                      loading: () => const SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                      error: (_, __) => const SizedBox(
                                          width: 40, height: 40),
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
                                            bgColor: Colors.black,
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
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => Navigator.of(context)
                                      .push(_SearchOverlayRoute()),
                                  child: Container(
                                    height: 46,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.92),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.search, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Search users...',
                                          style: TextStyle(
                                            color: Colors.black
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
                              loading: () => const SizedBox(),
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
                                  title: '🔗 Bio’da daha iyi durur:',
                                  subtitle: '(Her bio’ya uygundur)',
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
      loading: () => wrap(
        Row(
          children: const [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Finding someone for you…",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      error: (e, _) => wrap(
        Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white70),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Couldn’t load recommendation",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => ref
                  .read(recommendedUserControllerProvider.notifier)
                  .refresh(),
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
      data: (u) {
        if (u == null) {
          return wrap(
            Row(
              children: [
                const Icon(Icons.people_outline, color: Colors.white70),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "No recommendation right now",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () => ref
                      .read(recommendedUserControllerProvider.notifier)
                      .refresh(),
                  child: const Text("Refresh"),
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
                        bgColor: Colors.black,
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
                            u.username == null ? '—' : '@${u.username}',
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
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.black.withOpacity(0.6),
                  disabledForegroundColor: Colors.white.withOpacity(0.7),
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
                    AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  isLoading ? "Yükleniyor" : "Yenile",
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

class _SearchOverlayRoute extends PageRouteBuilder<void> {
  _SearchOverlayRoute()
      : super(
    opaque: false,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
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
