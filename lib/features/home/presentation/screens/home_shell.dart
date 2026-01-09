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

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: VideoBackground(
        assetPath: 'assets/videos/chaput_bg_2.mp4',
        overlayOpacity: 0.45,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 12,
                right: 16,
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
                          imageUrl: user.profilePhotoUrl ?? user.defaultAvatar!,
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

              /// 🔴 Logout butonu (AYNEN KALDI)
              Center(
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
            ],
          ),
        ),
      ),
    );
  }
}