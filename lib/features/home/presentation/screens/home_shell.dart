import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/secure_storage_provider.dart';
import '../../../../core/ui/video/video_background.dart';
import '../../../auth/data/auth_api.dart';
import '../../../me/application/me_controller.dart';
import '../../../user_search/presentation/search_overlay.dart';
import '../../../recommended_users/application/recommended_user_controller.dart';
import '../../../../core/ui/widgets/glow_shimmer_card.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: VideoBackground(
        assetPath: 'assets/videos/chaput_bg_2.mp4',
        overlayOpacity: 0.45,
        child: SafeArea(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ✅ Search bar (üst orta)
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: SafeArea(
                  bottom: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Hero(
                        tag: SearchOverlay.heroTag,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () =>
                                Navigator.of(context).push(_SearchOverlayRoute()),
                            child: Container(
                              height: 46,
                              padding:
                              const EdgeInsets.symmetric(horizontal: 12),
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
                                      color: Colors.black.withOpacity(0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ✅ Önerilen kullanıcı kartı (TAM ORTA)
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _RecommendedUserCard(),
                  ),
                ),
              ),

              // ✅ Logout butonu SOL ALT
              Positioned(
                left: 16,
                bottom: 16,
                child: SafeArea(
                  top: false,
                  child: ElevatedButton(
                    onPressed: () async {
                      final storage = ref.read(tokenStorageProvider);
                      final refresh = await storage.readRefreshToken();

                      if (refresh == null || refresh.isEmpty) {
                        if (context.mounted) context.go(Routes.onboarding);
                        return;
                      }

                      try {
                        final api = ref.read(authApiProvider);
                        await api.logout(refreshToken: refresh);

                        await storage.clear();
                        if (context.mounted) context.go(Routes.onboarding);
                      } on DioException {
                        await storage.clear();
                        if (context.mounted) context.go(Routes.onboarding);
                      } catch (_) {
                        await storage.clear();
                        if (context.mounted) context.go(Routes.onboarding);
                      }
                    },
                    child: const Text('Logout'),
                  ),
                ),
              ),

              // ✅ Avatar sağ alt
              Positioned(
                right: 16,
                bottom: 16,
                child: Consumer(
                  builder: (context, ref, _) {
                    final meAsync = ref.watch(meControllerProvider);

                    return meAsync.when(
                      data: (me) {
                        if (me == null) return const SizedBox();
                        final user = me.user;

                        return ChaputCircleAvatar(
                          width: 40,
                          height: 40,
                          radius: 999,
                          borderWidth: 2,
                          isDefaultAvatar: user.profilePhotoUrl == null,
                          imageUrl:
                          user.profilePhotoUrl ?? user.defaultAvatar!,
                        );
                      },
                      loading: () => const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (_, __) => const SizedBox(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
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
      glassOpacity: 0.18,
      glowSigma: 24,
      glowOpacity: 0.55,
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
                style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
                style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
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
            children: [
              GestureDetector(
                onTap: () async => context.push(await Routes.profile(u.id)),
                child: ChaputCircleAvatar(
                  width: 40,
                  height: 40,
                  radius: 999,
                  borderWidth: 2,
                  isDefaultAvatar: u.profilePhotoKey == null,
                  imageUrl: u.profilePhotoKey ?? u.defaultAvatar,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.fullName,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      u.username == null ? '—' : '@${u.username}',
                      style:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () => ref.read(recommendedUserControllerProvider.notifier).refresh(),
                icon: isLoading
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(isLoading ? "Yükleniyor" : "Yenile"),
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
