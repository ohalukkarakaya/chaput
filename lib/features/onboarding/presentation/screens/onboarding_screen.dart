import 'package:chaput/core/i18n/app_localizations.dart';
import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:flutter/material.dart';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/device/device_id_service.dart';
import '../../../../core/storage/secure_storage_provider.dart';
import '../../../../core/ui/video/video_background.dart';
import '../../../../core/ui/widgets/code_verify_sheet.dart';
import '../../../../core/ui/widgets/email_cta_form.dart';


import '../../../../core/router/routes.dart';
import '../../../auth/data/auth_api.dart';
import '../../data/internal_users_api.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final email = _emailController.text.trim();

    final isValid = email.contains('@') && email.contains('.com');
    if (!isValid) {
      HapticFeedback.heavyImpact();
      return;
    }

    try {
      final deviceId = await ref.read(deviceIdServiceProvider).getOrCreate();
      final authApi = ref.read(authApiProvider);

      // 1.1 request code
      await authApi.requestLoginCode(email: email, deviceId: deviceId);
      HapticFeedback.selectionClick();

      // Sheet: resend + verify içeride
      final verified = await showCodeVerifySheet(
        context: context,
        email: email,
        onResend: () => authApi.requestLoginCode(email: email, deviceId: deviceId),
        onVerify: (code) => authApi.verifyLoginCode(email: email, deviceId: deviceId, code: code),
      );

      if (!mounted) return;
      if (verified == null) return; // dismiss yok ama defensive

      // tokens kaydet
      final storage = ref.read(tokenStorageProvider);
      await storage.saveAccessToken(verified.accessToken);
      await storage.saveRefreshToken(verified.refreshToken);

      context.go(Routes.home);
    } on DioException {
      HapticFeedback.heavyImpact();
    } catch (_) {
      HapticFeedback.heavyImpact();
    }
  }



  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final isKeyboardOpen = keyboard > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: VideoBackground(
        assetPath: 'assets/videos/chaput_bg.M4V',
        overlayOpacity: 0.45,
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + keyboard, // input her zaman klavyenin üstünde
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SingleChildScrollView(
                      reverse: true,
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.t('onboarding.welcome_title'),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize:  30,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            context.t('onboarding.welcome_subtitle'),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.80),
                              fontSize: 16,
                              height: 1.25,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          SizedBox(height: 18),

                          EmailCtaForm(
                            controller: _emailController,
                            hint: context.t('common.email'),
                            buttonText: context.t('common.continue'),
                            onSubmit: _onSubmit,
                          ),

                          SizedBox(height: isKeyboardOpen ? 0 : 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Görselin altı asla kesilmesin:
/// - BoxFit.cover kullanıyoruz
/// - Alignment.bottomCenter ile altı sabitliyoruz
/// Böylece taşan kısım ÜSTTEN kırpılır.
class _TopCroppedHeaderImage extends StatelessWidget {
  final String assetPath;

  const _TopCroppedHeaderImage({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Image.asset(
          assetPath,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
        ),
      ),
    );
  }
}