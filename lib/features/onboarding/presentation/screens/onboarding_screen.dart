import 'dart:developer';

import 'package:chaput/core/i18n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/device/device_id_service.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/secure_storage_provider.dart';
import '../../../../core/ui/video/video_background.dart';
import '../../../../core/ui/widgets/code_verify_sheet.dart';
import '../../../../core/ui/widgets/email_cta_form.dart';

import '../../../auth/data/auth_api.dart';
import '../../../me/application/me_controller.dart';
import '../../data/internal_users_api.dart';
import '../../presentation/widgets/signup_sheet.dart';
import '../../../me/data/me_api.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _emailController = TextEditingController();
  final PageController _textController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onTextPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  Future<void> _startLoginFlow({
    required String email,
    required String deviceId,
  }) async {
    final authApi = ref.read(authApiProvider);
    final storage = ref.read(tokenStorageProvider);

    log('ONB: login flow -> request code');
    await authApi.requestLoginCode(email: email, deviceId: deviceId);
    HapticFeedback.selectionClick();

    final verified = await showCodeVerifySheet(
      context: context,
      email: email,
      onResend: () => authApi.requestLoginCode(email: email, deviceId: deviceId),
      onVerify: (code) => authApi.verifyLoginCode(email: email, deviceId: deviceId, code: code),
    );

    if (!mounted) return;
    if (verified == null) return;

    await storage.saveAccessToken(verified.accessToken);
    await storage.saveRefreshToken(verified.refreshToken);

    try {
      await ref.read(meControllerProvider.notifier).fetchAndStoreMe();
      if (!mounted) return;
      context.go(Routes.home);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      // 401/404 -> controller clear yaptı; onboarding'de kal
      log('ONB: /me failed status=$code', error: e);
      HapticFeedback.heavyImpact();
    } catch (e) {
      log('ONB: /me unknown fail', error: e);
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _startSignupFlow({
    required String email,
    required String deviceId,
  }) async {
    final authApi = ref.read(authApiProvider);
    final storage = ref.read(tokenStorageProvider);

    // 1) sheet (dismissible) -> iptal edilirse onboarding’de kal
    final draft = await showSignupSheet(context: context, email: email);
    if (!mounted) return;
    if (draft == null) {
      log('ONB: signup sheet dismissed -> stay onboarding');
      return;
    }

    // 2) signup code iste
    log('ONB: signup flow -> request signup code');
    await authApi.requestSignupCode(email: email, deviceId: deviceId);
    HapticFeedback.selectionClick();

    // 3) signup verify (✅ /signup/verify-code)
    final verified = await showCodeVerifySheet(
      context: context,
      email: email,
      onResend: () => authApi.requestSignupCode(email: email, deviceId: deviceId),
      onVerify: (code) => authApi.verifySignupCode(
        email: email,
        deviceId: deviceId,
        code: code,
      ),
    );

    if (!mounted) return;
    if (verified == null) return;

    // 4) tokens kaydet
    await storage.saveAccessToken(verified.accessToken);
    await storage.saveRefreshToken(verified.refreshToken);

    // 5) gender -> default avatar (✅ POST /me/default-avatar)
    final meApi = ref.read(meApiProvider);
    try {
      log('ONB: set default avatar gender=${draft.gender}');
      await meApi.setDefaultAvatarByGender(gender: draft.gender);
    } on DioException catch (e, st) {
      // 409 already_set -> ignore
      if (e.response?.statusCode != 409) {
        log('ONB: /me/default-avatar error', error: e, stackTrace: st);
        rethrow;
      }
    }

    // 6) profile patch
    final birthIso = draft.birthDate.toIso8601String().substring(0, 10);
    log('ONB: update profile fullName=${draft.fullName} username=${draft.username} birth=$birthIso');

    await meApi.updateFullName(fullName: draft.fullName.toLowerCase());
    await meApi.updateUsername(username: draft.username.toLowerCase());
    await meApi.updateBirthDate(birthDateIso: birthIso);


    if (!mounted) return;
    try {
      await ref.read(meControllerProvider.notifier).fetchAndStoreMe();
      if (!mounted) return;
      context.go(Routes.home);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      // 401/404 -> controller clear yaptı; onboarding'de kal
      log('ONB: /me failed status=$code', error: e);
      HapticFeedback.heavyImpact();
    } catch (e) {
      log('ONB: /me unknown fail', error: e);
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _onSubmit() async {
    final email = _emailController.text.trim();

    final isValid = email.contains('@') && email.contains('.com');
    if (!isValid) {
      HapticFeedback.heavyImpact();
      return;
    }

    final deviceId = await ref.read(deviceIdServiceProvider).getOrCreate();

    try {
      // 0) lookup
      final lookupApi = ref.read(internalUsersApiProvider);
      log('ONB: lookup-email -> $email');
      final lookup = await lookupApi.lookupEmail(email);
      log('ONB: lookup result = $lookup');

      if (!mounted) return;

      switch (lookup) {
        case EmailLookupResult.userFoundComplete:
          await _startLoginFlow(email: email, deviceId: deviceId);
          return;

        case EmailLookupResult.userNotFound:
        case EmailLookupResult.userFoundNeedsProfileSetup:
          await _startSignupFlow(email: email, deviceId: deviceId);
          return;
      }
    } on DioException catch (e, st) {
      log('ONB: Dio error', error: e, stackTrace: st);
      HapticFeedback.heavyImpact();
    } catch (e, st) {
      log('ONB: Unknown error', error: e, stackTrace: st);
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final isKeyboardOpen = keyboard > 0;
    final screenHeight = mq.size.height;
    final cardHeight = (screenHeight * 0.085).clamp(64.0, 92.0);

    final sliderTexts = [
      {
        'title': context.t('onboarding.slide1_title'),
        'subtitle': context.t('onboarding.slide1_subtitle'),
      },
      {
        'title': context.t('onboarding.slide2_title'),
        'subtitle': context.t('onboarding.slide2_subtitle'),
      },
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: VideoBackground(
        assetPath: 'assets/videos/chaput_bg.M4V',
        overlayOpacity: 0.45,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final h = constraints.maxHeight;
                    final w = constraints.maxWidth;
                    return AnimatedBuilder(
                      animation: _textController,
                      builder: (context, _) {
                        final maxPage = (sliderTexts.length - 1).clamp(1, 999);
                        final page = _textController.hasClients
                            ? (_textController.page ?? _currentIndex.toDouble())
                            : _currentIndex.toDouble();
                        final t = (page / maxPage).clamp(0.0, 1.0);
                        final maxWidth = w * 1.25;
                        final minWidth = w;
                        final heightDrivenWidth = h * 1.35;
                        final imageWidth = heightDrivenWidth.clamp(minWidth, maxWidth);
                        const sidePadding = 12.0;
                        final dx = sidePadding + (w - imageWidth - 2 * sidePadding) * t;

                        return ClipRect(
                          child: Stack(
                            children: [
                              Positioned(
                                left: dx,
                                top: 0,
                                width: imageWidth,
                                height: h,
                                child: Image.asset(
                                  'assets/images/chaput_slider.png',
                                  width: imageWidth,
                                  height: h,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topLeft,
                                ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        AppColors.chaputTransparent,
                                        AppColors.chaputBlack.withOpacity(0.55),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                width: double.infinity,
                color: AppColors.chaputBlack.withOpacity(0.78),
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 6 + keyboard + mq.padding.bottom),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: cardHeight,
                          child: PageView.builder(
                            controller: _textController,
                            itemCount: sliderTexts.length,
                            onPageChanged: _onTextPageChanged,
                            itemBuilder: (context, index) {
                              final item = sliderTexts[index];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] ?? '',
                                    style: const TextStyle(
                                      color: AppColors.chaputWhite,
                                      fontSize: 20,
                                      height: 1.15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['subtitle'] ?? '',
                                    style: TextStyle(
                                      color: AppColors.chaputWhite.withOpacity(0.78),
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: List.generate(
                            sliderTexts.length,
                            (index) {
                              final isActive = index == _currentIndex;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(right: 6),
                                width: isActive ? 14 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.chaputWhite
                                      : AppColors.chaputWhite.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 6),
                        Divider(color: AppColors.chaputWhite.withOpacity(0.12)),
                        const SizedBox(height: 6),
                        EmailCtaForm(
                          controller: _emailController,
                          hint: context.t('common.email'),
                          buttonText: context.t('common.continue'),
                          onSubmit: _onSubmit,
                        ),
                        SizedBox(height: isKeyboardOpen ? 0 : 4),
                      ],
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
