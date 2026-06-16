import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/deep_links/deep_link_state.dart';
import '../../../../core/device/device_id_service.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/secure_storage_provider.dart';
import '../../../../core/ui/widgets/chaput_tunnel_splash.dart';
import '../../../auth/data/auth_api.dart';
import '../../../me/application/me_controller.dart';
import '../../../notifications/application/firebase_token_cleanup.dart';
import '../../../notifications/application/notification_badge_service.dart';
import '../../../notifications/data/notification_api_provider.dart';
import '../../application/onboarding_tree_preload.dart';

class BootScreen extends ConsumerStatefulWidget {
  const BootScreen({super.key});

  @override
  ConsumerState<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends ConsumerState<BootScreen>
    with SingleTickerProviderStateMixin {
  bool _navigated = false;
  bool _exitHapticFired = false;
  late final AnimationController _exitController;

  @override
  void initState() {
    super.initState();
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    _exitController.addListener(() {
      if (_exitHapticFired || _exitController.value < 0.92) {
        return;
      }
      _exitHapticFired = true;
      HapticFeedback.mediumImpact();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  @override
  void dispose() {
    _exitController.dispose();
    super.dispose();
  }

  Future<void> _leave(VoidCallback navigate) async {
    if (_navigated) return;
    _navigated = true;
    if (_exitController.status == AnimationStatus.dismissed) {
      await _exitController.forward();
    }
    if (!mounted) return;
    navigate();
  }

  Future<void> _goAfterBoot() async {
    final pendingLink = ref.read(pendingDeepLinkProvider);
    await _leave(() {
      if (pendingLink != null) {
        context.go(Routes.home);
        return;
      }
      context.pushReplacement(Routes.home);
    });
  }

  Future<void> _prepareOnboardingTree() async {
    try {
      await ref
          .read(onboardingTreePreloadProvider)
          .prepareRandom(forceNew: true);
    } catch (_) {}
  }

  Future<void> _boot() async {
    if (_navigated) return;

    await NotificationBadgeService.resetAppIconBadge();

    final storage = ref.read(tokenStorageProvider);

    // 1) device id ensure
    final deviceId = await ref.read(deviceIdServiceProvider).getOrCreate();
    debugPrint('BOOT: deviceId = $deviceId');

    // 2) refresh token check
    final refresh = await storage.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      debugPrint('BOOT: refresh token yok -> onboarding');
      ref.read(pendingDeepLinkProvider.notifier).state = null;

      await Future.wait([
        Future.delayed(const Duration(milliseconds: 600)),
        _prepareOnboardingTree(),
      ]);
      if (!mounted) return;

      await _leave(() => context.pushReplacement(Routes.onboarding));
      return;
    }

    debugPrint(
      'BOOT: refresh token var -> /auth/token/refresh isteği atılıyor',
    );

    // küçük bir süre boot görünsün
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    try {
      final authApi = ref.read(authApiProvider);
      final res = await authApi.refresh(refreshToken: refresh);

      if (res.accessToken.isEmpty) {
        debugPrint(
          'BOOT: refresh 200 geldi ama access_token boş -> onboarding',
        );
        await FirebaseTokenCleanup.deleteLocalMessagingToken();
        await storage.clear();
        ref.read(pendingDeepLinkProvider.notifier).state = null;
        await _prepareOnboardingTree();
        if (!mounted) return;
        await _leave(() => context.pushReplacement(Routes.onboarding));
        return;
      }

      await storage.saveAccessToken(res.accessToken);
      debugPrint('BOOT: refresh OK -> /me fetch');

      try {
        await ref.read(meControllerProvider.notifier).fetchAndStoreMe();
        await storage.markAuthenticated();
        try {
          await ref
              .read(notificationApiProvider)
              .resetBadge(allowUnauthorized: true);
        } catch (_) {}
        debugPrint('BOOT: /me OK -> HOME');

        if (mounted) {
          await _goAfterBoot();
        }
      } on DioException catch (e) {
        final code = e.response?.statusCode;

        if (code == 401 || code == 404) {
          debugPrint('BOOT: /me failed status=$code -> onboarding, error= $e');
          ref.read(pendingDeepLinkProvider.notifier).state = null;
          await _prepareOnboardingTree();
          if (mounted) {
            await _leave(() => context.pushReplacement(Routes.onboarding));
          }
          return;
        }

        debugPrint(
          'BOOT: /me transient fail status=$code -> stay boot, error= $e',
        );
        return;
      } catch (e) {
        debugPrint('BOOT: /me unknown fail -> stay boot, error= $e');
        return;
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final data = e.response?.data;

      debugPrint('BOOT: refresh ERROR status=$code data=$data error= $e');

      // 400/401 => invalid_refresh_token / refresh_expired gibi durumlar
      if (code == 400 || code == 401) {
        await FirebaseTokenCleanup.deleteLocalMessagingToken();
        await storage.clear();
        ref.read(pendingDeepLinkProvider.notifier).state = null;
        debugPrint('BOOT: refresh invalid/expired -> onboarding');
        await _prepareOnboardingTree();
        if (mounted) {
          await _leave(() => context.pushReplacement(Routes.onboarding));
        }
        return;
      }

      // diğer hatalar (500, network vs.)
      debugPrint('BOOT: refresh transient error -> stay boot');
      return;
    } catch (e) {
      debugPrint('BOOT: refresh unknown ERROR -> stay boot, error= $e');
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chaputBlack,
      body: AnimatedBuilder(
        animation: _exitController,
        builder: (context, _) {
          return ChaputTunnelSplash(progress: _exitController.value);
        },
      ),
    );
  }
}
