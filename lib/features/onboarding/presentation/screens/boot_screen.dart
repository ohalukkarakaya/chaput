import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/attribution/chaput_attribution_service.dart';
import '../../../../core/deep_links/deep_link_state.dart';
import '../../../../core/device/device_id_service.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/review/app_review_service.dart';
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
  bool _connectionUnavailable = false;
  bool _retrying = false;
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
          .prepareRandom(forceNew: true)
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> _ensureDeviceId() async {
    try {
      final deviceId = await ref.read(deviceIdServiceProvider).getOrCreate();
      debugPrint('BOOT: deviceId = $deviceId');
    } catch (error) {
      debugPrint('BOOT: device id unavailable, continuing: $error');
    }
  }

  Future<String?> _readRefreshTokenSafely() async {
    try {
      return await ref
          .read(tokenStorageProvider)
          .readRefreshToken()
          .timeout(const Duration(seconds: 3));
    } catch (error) {
      debugPrint('BOOT: refresh token unavailable, continuing: $error');
      return null;
    }
  }

  Future<void> _clearInvalidSession() async {
    final storage = ref.read(tokenStorageProvider);
    try {
      await FirebaseTokenCleanup.deleteLocalMessagingToken().timeout(
        const Duration(seconds: 2),
      );
    } catch (_) {}
    try {
      await storage.clear().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<void> _storeAccessTokenSafely(String accessToken) async {
    try {
      await ref
          .read(tokenStorageProvider)
          .saveAccessToken(accessToken)
          .timeout(const Duration(seconds: 2));
    } catch (error) {
      debugPrint('BOOT: access token storage delayed, continuing: $error');
    }
  }

  Future<void> _markAuthenticatedSafely() async {
    try {
      await ref
          .read(tokenStorageProvider)
          .markAuthenticated()
          .timeout(const Duration(seconds: 2));
    } catch (error) {
      debugPrint('BOOT: authentication marker delayed, continuing: $error');
    }
  }

  void _showConnectionUnavailable() {
    if (!mounted || _navigated || _connectionUnavailable) return;
    setState(() => _connectionUnavailable = true);
  }

  Future<void> _retryBoot() async {
    if (_retrying || _navigated) return;
    setState(() {
      _retrying = true;
      _connectionUnavailable = false;
    });
    try {
      await _boot();
    } finally {
      if (mounted && !_navigated) {
        setState(() => _retrying = false);
      }
    }
  }

  Future<void> _boot() async {
    if (_navigated) return;

    unawaited(NotificationBadgeService.resetAppIconBadge());

    // A device identifier improves diagnostics, but is never a reason to hold
    // the user on the boot screen.
    unawaited(_ensureDeviceId());

    // 2) refresh token check
    final refresh = await _readRefreshTokenSafely();
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
      final res = await authApi
          .refresh(refreshToken: refresh)
          .timeout(const Duration(seconds: 5));

      if (res.accessToken.isEmpty) {
        debugPrint(
          'BOOT: refresh 200 geldi ama access_token boş -> onboarding',
        );
        await _clearInvalidSession();
        ref.read(pendingDeepLinkProvider.notifier).state = null;
        await _prepareOnboardingTree();
        if (!mounted) return;
        await _leave(() => context.pushReplacement(Routes.onboarding));
        return;
      }

      await _storeAccessTokenSafely(res.accessToken);
      debugPrint('BOOT: refresh OK -> /me fetch');

      try {
        final me = await ref
            .read(meControllerProvider.notifier)
            .fetchAndStoreMe()
            .timeout(const Duration(seconds: 5));
        await _markAuthenticatedSafely();
        final userId = me?.user.userId ?? '';
        if (userId.isNotEmpty) {
          try {
            await ref
                .read(appReviewServiceProvider)
                .recordAppOpenForSession(userId)
                .timeout(const Duration(seconds: 2));
          } catch (error) {
            debugPrint('BOOT: app review state delayed, continuing: $error');
          }
        }
        unawaited(
          ref
              .read(chaputAttributionServiceProvider)
              .activateAfterAuthentication(),
        );
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
          await _clearInvalidSession();
          ref.read(pendingDeepLinkProvider.notifier).state = null;
          await _prepareOnboardingTree();
          if (mounted) {
            await _leave(() => context.pushReplacement(Routes.onboarding));
          }
          return;
        }

        debugPrint(
          'BOOT: /me transient fail status=$code -> retry wall, error= $e',
        );
        _showConnectionUnavailable();
        return;
      } catch (e) {
        debugPrint('BOOT: /me unknown fail -> retry wall, error= $e');
        _showConnectionUnavailable();
        return;
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final data = e.response?.data;

      debugPrint('BOOT: refresh ERROR status=$code data=$data error= $e');

      // 400/401 => invalid_refresh_token / refresh_expired gibi durumlar
      if (code == 400 || code == 401) {
        await _clearInvalidSession();
        ref.read(pendingDeepLinkProvider.notifier).state = null;
        debugPrint('BOOT: refresh invalid/expired -> onboarding');
        await _prepareOnboardingTree();
        if (mounted) {
          await _leave(() => context.pushReplacement(Routes.onboarding));
        }
        return;
      }

      // Do not enter Home until /me has confirmed the session. This keeps an
      // expired or otherwise unverifiable refresh token from bypassing auth.
      debugPrint('BOOT: refresh transient error -> retry wall');
      _showConnectionUnavailable();
      return;
    } catch (e) {
      debugPrint('BOOT: refresh unknown ERROR -> retry wall, error= $e');
      _showConnectionUnavailable();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chaputBlack,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _exitController,
            builder: (context, _) {
              return ChaputTunnelSplash(progress: _exitController.value);
            },
          ),
          if (_connectionUnavailable)
            Positioned.fill(
              child: Material(
                color: Colors.black.withValues(alpha: 0.32),
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.chaputWhite,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                context.t('availability.offline_title'),
                                style: const TextStyle(
                                  color: AppColors.chaputBlack,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.t('availability.offline_body'),
                                style: const TextStyle(
                                  color: Color(0xFF565656),
                                  fontSize: 15,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _retrying ? null : _retryBoot,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.chaputBlack,
                                    foregroundColor: AppColors.chaputWhite,
                                    disabledBackgroundColor:
                                        AppColors.chaputBlack,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _retrying
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.chaputWhite,
                                          ),
                                        )
                                      : Text(
                                          context.t('availability.retry'),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
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
              ),
            ),
        ],
      ),
    );
  }
}
