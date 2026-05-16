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
import '../../../../core/ui/widgets/code_verify_sheet.dart';
import '../../../../core/ui/widgets/email_cta_form.dart';

import '../../../auth/data/auth_api.dart';
import '../../../me/application/me_controller.dart';
import '../../application/onboarding_tree_preload.dart';
import '../../data/internal_users_api.dart';
import '../widgets/onboarding_tree_scene.dart';
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
  bool _submitting = false;
  String? _submitError;
  int _shakeSignal = 0;
  bool _treeInteracting = false;
  bool _emailFocused = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_handleEmailChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(onboardingTreePreloadProvider).prepareRandom();
    });
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleEmailChanged);
    _emailController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onTextPageChanged(int index) {
    setState(() => _currentIndex = index);
    HapticFeedback.selectionClick();
  }

  void _handleTreeInteractionChanged(bool value) {
    if (_treeInteracting == value) return;
    setState(() => _treeInteracting = value);
    if (value) {
      FocusScope.of(context).unfocus();
    }
  }

  void _handleEmailFocusChanged(bool value) {
    if (_emailFocused == value) return;
    setState(() => _emailFocused = value);
  }

  void _handleEmailChanged() {
    if (_submitError == null) return;
    setState(() => _submitError = null);
  }

  Future<void> _showSubmitError(String message) async {
    if (!mounted) return;
    setState(() {
      _submitError = message;
      _shakeSignal += 1;
    });
    await HapticFeedback.mediumImpact();
  }

  String _mapOnboardingError(DioException e) {
    final data = e.response?.data;
    final raw = data is Map
        ? data['error']?.toString() ?? ''
        : data?.toString() ?? '';

    if (raw.contains('email_blacklisted')) {
      return context.t('errors.email_blacklisted');
    }
    if (raw.contains('full_name_blacklisted')) {
      return context.t('errors.full_name_blacklisted');
    }
    if (raw.contains('username_blacklisted')) {
      return context.t('errors.username_blacklisted');
    }
    if (raw.contains('invalid_email')) {
      return context.t('errors.invalid_email');
    }
    if (raw.contains('user_already_exists')) {
      return context.t('errors.email_taken');
    }
    if (raw.contains('db_error')) {
      return context.t('errors.db_error');
    }

    final status = e.response?.statusCode;
    if (status == 401) return context.t('errors.unauthorized');
    if (status == 403) return context.t('errors.forbidden');
    if (status == 429) return context.t('errors.too_many_attempts');
    return context.t('errors.generic');
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
    if (!mounted) return;

    final verified = await showCodeVerifySheet(
      context: context,
      email: email,
      onResend: () =>
          authApi.requestLoginCode(email: email, deviceId: deviceId),
      onVerify: (code) =>
          authApi.verifyLoginCode(email: email, deviceId: deviceId, code: code),
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

    final draft = await showSignupSheet(context: context, email: email);
    if (!mounted) return;
    if (draft == null) {
      log('ONB: signup sheet dismissed -> stay onboarding');
      return;
    }

    log('ONB: signup flow -> request signup code');
    await authApi.requestSignupCode(email: email, deviceId: deviceId);
    HapticFeedback.selectionClick();
    if (!mounted) return;

    final verified = await showCodeVerifySheet(
      context: context,
      email: email,
      onResend: () =>
          authApi.requestSignupCode(email: email, deviceId: deviceId),
      onVerify: (code) => authApi.verifySignupCode(
        email: email,
        deviceId: deviceId,
        code: code,
      ),
    );

    if (!mounted) return;
    if (verified == null) return;

    await storage.saveAccessToken(verified.accessToken);
    await storage.saveRefreshToken(verified.refreshToken);

    final meApi = ref.read(meApiProvider);
    try {
      log('ONB: set default avatar gender=${draft.gender}');
      await meApi.setDefaultAvatarByGender(gender: draft.gender);
    } on DioException catch (e, st) {
      if (e.response?.statusCode != 409) {
        log('ONB: /me/default-avatar error', error: e, stackTrace: st);
        rethrow;
      }
    }

    final birthIso = draft.birthDate.toIso8601String().substring(0, 10);
    log(
      'ONB: update profile fullName=${draft.fullName} username=${draft.username} birth=$birthIso',
    );

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
      log('ONB: /me failed status=$code', error: e);
      HapticFeedback.heavyImpact();
    } catch (e) {
      log('ONB: /me unknown fail', error: e);
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;
    final email = _emailController.text.trim();

    final isValid = email.contains('@') && email.contains('.com');
    if (!isValid) {
      await _showSubmitError(context.t('errors.invalid_email'));
      return;
    }

    final deviceId = await ref.read(deviceIdServiceProvider).getOrCreate();
    if (mounted) {
      setState(() {
        _submitting = true;
        _submitError = null;
      });
    }

    try {
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
      await _showSubmitError(_mapOnboardingError(e));
    } catch (e, st) {
      log('ONB: Unknown error', error: e, stackTrace: st);
      if (!mounted) return;
      await _showSubmitError(context.t('errors.generic'));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preload = ref.watch(onboardingTreePreloadProvider);
    final preset = preload.preset;
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final isKeyboardOpen = keyboard > 0;
    final pauseTree = _emailFocused || isKeyboardOpen || _submitting;
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
      {
        'title': context.t('onboarding.slide3_title'),
        'subtitle': context.t('onboarding.slide3_subtitle'),
      },
      {
        'title': context.t('onboarding.slide4_title'),
        'subtitle': context.t('onboarding.slide4_subtitle'),
      },
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Color(preset.bgColor),
      body: Stack(
        fit: StackFit.expand,
        children: [
          OnboardingTreeScene(
            preset: preset,
            activePage: _currentIndex,
            paused: pauseTree,
            onInteractionChanged: _handleTreeInteractionChanged,
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: IgnorePointer(
                ignoring: _treeInteracting,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  offset: _treeInteracting
                      ? const Offset(0, 1.08)
                      : Offset.zero,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 120),
                    opacity: _treeInteracting ? 0 : 1,
                    child: Container(
                      width: double.infinity,
                      color: AppColors.chaputBlack.withOpacity(0.78),
                      child: AnimatedPadding(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: EdgeInsets.fromLTRB(
                          0,
                          8,
                          0,
                          6 + keyboard + mq.padding.bottom,
                        ),
                        child: Align(
                          alignment: Alignment.center,
                          heightFactor: 1,
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
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                                color: AppColors.chaputWhite
                                                    .withOpacity(0.78),
                                                fontSize: 13,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: List.generate(
                                      sliderTexts.length,
                                      (index) {
                                        final isActive = index == _currentIndex;
                                        return AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          margin: const EdgeInsets.only(
                                            right: 6,
                                          ),
                                          width: isActive ? 14 : 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? AppColors.chaputWhite
                                                : AppColors.chaputWhite
                                                      .withOpacity(0.35),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Divider(
                                    color: AppColors.chaputWhite.withOpacity(
                                      0.12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: EmailCtaForm(
                                    controller: _emailController,
                                    hint: context.t('common.email'),
                                    buttonText: context.t('common.continue'),
                                    isLoading: _submitting,
                                    errorText: _submitError,
                                    shakeSignal: _shakeSignal,
                                    onFocusChanged: _handleEmailFocusChanged,
                                    onSubmit: _onSubmit,
                                  ),
                                ),
                                SizedBox(height: isKeyboardOpen ? 0 : 4),
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
          ),
        ],
      ),
    );
  }
}
