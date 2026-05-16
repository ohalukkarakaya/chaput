import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/device/device_id_service.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/secure_storage_provider.dart';
import '../../../../core/ui/video/video_background.dart';
import '../../../auth/data/auth_api.dart';
import '../../../me/application/me_controller.dart';
import '../../application/onboarding_tree_preload.dart';

class BootScreen extends ConsumerStatefulWidget {
  const BootScreen({super.key});

  @override
  ConsumerState<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends ConsumerState<BootScreen> {
  bool _navigated = false;

  Future<void> _prepareOnboardingTree() async {
    try {
      await ref
          .read(onboardingTreePreloadProvider)
          .prepareRandom(forceNew: true);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    if (_navigated) return;

    final storage = ref.read(tokenStorageProvider);

    // 1) device id ensure
    final deviceId = await ref.read(deviceIdServiceProvider).getOrCreate();
    debugPrint('BOOT: deviceId = $deviceId');

    // 2) refresh token check
    final refresh = await storage.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      debugPrint('BOOT: refresh token yok -> onboarding');

      await Future.wait([
        Future.delayed(const Duration(milliseconds: 600)),
        _prepareOnboardingTree(),
      ]);
      if (!mounted) return;

      _navigated = true;
      context.pushReplacement(Routes.onboarding); // 👈 Hero için
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
        await storage.clear();
        await _prepareOnboardingTree();
        if (!mounted) return;
        _navigated = true;
        context.pushReplacement(Routes.onboarding);
        return;
      }

      await storage.saveAccessToken(res.accessToken);
      await storage.saveAccessToken(res.accessToken);
      debugPrint('BOOT: refresh OK -> /me fetch');

      try {
        await ref.read(meControllerProvider.notifier).fetchAndStoreMe();
        debugPrint('BOOT: /me OK -> HOME');

        _navigated = true;
        if (mounted) context.pushReplacement(Routes.home);
      } on DioException catch (e) {
        final code = e.response?.statusCode;

        if (code == 401 || code == 404) {
          debugPrint('BOOT: /me failed status=$code -> onboarding, error= $e');
          await _prepareOnboardingTree();
          _navigated = true;
          if (mounted) context.pushReplacement(Routes.onboarding);
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
        await storage.clear();
        debugPrint('BOOT: refresh invalid/expired -> onboarding');
        await _prepareOnboardingTree();
        _navigated = true;
        if (mounted) context.pushReplacement(Routes.onboarding);
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
      body: VideoBackground(
        assetPath: 'assets/videos/chaput_bg.M4V',
        overlayOpacity: 0.55,
        child: Center(
          child: Hero(tag: 'chaput_logo', child: _BootLogo()),
        ),
      ),
    );
  }
}

class _BootLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Logon PNG ise burayı Image.asset yap.
    // UI’da “bir tık büyük” dediğin için 64 dp verdim.
    return SizedBox(
      width: 64,
      height: 64,
      child: Center(
        child: Image.asset(
          'assets/images/chaput_logo_256px_h.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
