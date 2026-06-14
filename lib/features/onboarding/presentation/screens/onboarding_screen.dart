import 'dart:developer';
import 'dart:math' as math;

import 'package:chaput/core/i18n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/deep_links/deep_link_state.dart';
import '../../../../core/device/device_id_service.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/secure_storage_provider.dart';
import '../../../../core/ui/responsive/chaput_responsive.dart';
import '../../../../core/ui/widgets/code_verify_sheet.dart';
import '../../../../core/ui/widgets/email_cta_form.dart';
import '../../../../core/ui/widgets/shimmer_skeleton.dart';

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
  static const _textHeightAnimationDuration = Duration(milliseconds: 220);
  static const _textRevealDelay = Duration(milliseconds: 240);

  final _emailController = TextEditingController();
  final PageController _textController = PageController();
  int _currentIndex = 0;
  int _textHeightIndex = 0;
  int _settledTextIndex = 0;
  int _textRevealToken = 0;
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

  bool _handleTextScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.horizontal) return false;

    if (notification is ScrollStartNotification) {
      _textRevealToken += 1;
    } else if (notification is ScrollEndNotification) {
      _settleTextPage();
    }

    return false;
  }

  void _settleTextPage() {
    final page = _textController.hasClients
        ? (_textController.page ?? _currentIndex.toDouble())
        : _currentIndex.toDouble();
    final index = page.round().clamp(0, 8);

    final alreadySettled =
        _textHeightIndex == index && _settledTextIndex == index;
    if (alreadySettled) {
      if (_currentIndex != index) {
        setState(() => _currentIndex = index);
      }
      return;
    }

    _textRevealToken += 1;
    final token = _textRevealToken;

    setState(() {
      _currentIndex = index;
      _textHeightIndex = index;
    });

    Future<void>.delayed(_textRevealDelay, () {
      if (!mounted || token != _textRevealToken) return;
      setState(() => _settledTextIndex = index);
    });
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

  double _measureTextHeight(
    String text,
    TextStyle style, {
    required double maxWidth,
    required TextScaler textScaler,
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);

    return painter.height;
  }

  double _measureOnboardingTextHeight({
    required String title,
    required String subtitle,
    required double maxWidth,
    required TextScaler textScaler,
    required TextStyle titleStyle,
    required TextStyle subtitleStyle,
    required double verticalPadding,
  }) {
    final titleHeight = _measureTextHeight(
      title,
      titleStyle,
      maxWidth: maxWidth,
      textScaler: textScaler,
      maxLines: 2,
    );
    final subtitleHeight = _measureTextHeight(
      subtitle,
      subtitleStyle,
      maxWidth: maxWidth,
      textScaler: textScaler,
    );

    return (verticalPadding +
            titleHeight +
            8 +
            subtitleHeight +
            verticalPadding)
        .ceilToDouble();
  }

  void _goAfterAuthentication() {
    final pendingLink = ref.read(pendingDeepLinkProvider);
    if (pendingLink != null) {
      ref.read(pendingDeepLinkProvider.notifier).state = null;
      context.go(pendingLink.location, extra: pendingLink.extra);
      return;
    }

    context.go(Routes.home);
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
    if (raw.contains('invalid_full_name')) {
      return context.t('signup.full_name_letters_only');
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
      _goAfterAuthentication();
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

    await meApi.updateFullName(fullName: draft.fullName);
    await meApi.updateUsername(username: draft.username.toLowerCase());
    await meApi.updateBirthDate(birthDateIso: birthIso);

    if (!mounted) return;
    try {
      await ref.read(meControllerProvider.notifier).fetchAndStoreMe();
      if (!mounted) return;
      _goAfterAuthentication();
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
    final responsive = context.responsive;
    final keyboard = responsive.keyboardInset;
    final isKeyboardOpen = keyboard > 0;
    final pauseTree = _emailFocused || isKeyboardOpen || _submitting;
    final textViewportMinHeight = isKeyboardOpen ? 72.0 : 88.0;
    final textVerticalPadding = isKeyboardOpen ? 8.0 : 14.0;
    final textMeasurementBuffer = isKeyboardOpen ? 8.0 : 12.0;
    final textMaxWidth = math.max(1.0, math.min(mq.size.width, 520.0) - 32);
    final textScaler = MediaQuery.textScalerOf(context);
    const titleStyle = TextStyle(
      color: AppColors.chaputWhite,
      fontSize: 20,
      height: 1.15,
      fontWeight: FontWeight.w700,
    );
    final subtitleStyle = TextStyle(
      color: AppColors.chaputWhite.withValues(alpha: 0.82),
      fontSize: 12.5,
      height: 1.32,
      fontWeight: FontWeight.w500,
    );

    final sliderTexts = List.generate(9, (index) {
      final slide = index + 1;
      return {
        'title': context.t('onboarding.slide${slide}_title'),
        'subtitle': context.t('onboarding.slide${slide}_subtitle'),
      };
    });
    final slideHeights = sliderTexts.map((text) {
      return _measureOnboardingTextHeight(
        title: text['title'] ?? '',
        subtitle: text['subtitle'] ?? '',
        maxWidth: textMaxWidth,
        textScaler: textScaler,
        titleStyle: titleStyle,
        subtitleStyle: subtitleStyle,
        verticalPadding: textVerticalPadding,
      );
    }).toList();
    final textHeightIndex = _textHeightIndex.clamp(0, sliderTexts.length - 1);
    final textViewportHeight = math.max(
      textViewportMinHeight,
      slideHeights[textHeightIndex] + textMeasurementBuffer,
    );
    final showRealTextForIndex = _settledTextIndex == _textHeightIndex
        ? _settledTextIndex.clamp(0, sliderTexts.length - 1)
        : -1;

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
                      color: AppColors.chaputBlack.withValues(alpha: 0.78),
                      child: AnimatedPadding(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        padding: EdgeInsets.fromLTRB(
                          0,
                          8,
                          0,
                          responsive.bottomFixedOffset(base: 6),
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
                                AnimatedContainer(
                                  duration: _textHeightAnimationDuration,
                                  curve: Curves.easeOutCubic,
                                  height: textViewportHeight,
                                  child: NotificationListener<ScrollNotification>(
                                    onNotification:
                                        _handleTextScrollNotification,
                                    child: PageView.builder(
                                      controller: _textController,
                                      itemCount: sliderTexts.length,
                                      onPageChanged: _onTextPageChanged,
                                      itemBuilder: (context, index) {
                                        final item = sliderTexts[index];
                                        final showReal =
                                            index == showRealTextForIndex;

                                        return Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: textVerticalPadding,
                                          ),
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth: math.max(
                                                1,
                                                textMaxWidth,
                                              ),
                                            ),
                                            child: Align(
                                              alignment: Alignment.topLeft,
                                              child: AnimatedSwitcher(
                                                duration: const Duration(
                                                  milliseconds: 160,
                                                ),
                                                switchInCurve: Curves.easeOut,
                                                switchOutCurve: Curves.easeOut,
                                                child: showReal
                                                    ? _OnboardingSlideText(
                                                        key: ValueKey(
                                                          'text-$index',
                                                        ),
                                                        title:
                                                            item['title'] ?? '',
                                                        subtitle:
                                                            item['subtitle'] ??
                                                            '',
                                                        titleStyle: titleStyle,
                                                        subtitleStyle:
                                                            subtitleStyle,
                                                      )
                                                    : _OnboardingTextShimmer(
                                                        key: ValueKey(
                                                          'shimmer-$index',
                                                        ),
                                                        title:
                                                            item['title'] ?? '',
                                                        titleStyle: titleStyle,
                                                        subtitleStyle:
                                                            subtitleStyle,
                                                      ),
                                              ),
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
                                                      .withValues(alpha: 0.35),
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
                                    color: AppColors.chaputWhite.withValues(
                                      alpha: 0.12,
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

class _OnboardingSlideText extends StatelessWidget {
  const _OnboardingSlideText({
    super.key,
    required this.title,
    required this.subtitle,
    required this.titleStyle,
    required this.subtitleStyle,
  });

  final String title;
  final String subtitle;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: subtitleStyle),
      ],
    );
  }
}

class _OnboardingTextShimmer extends StatelessWidget {
  const _OnboardingTextShimmer({
    super.key,
    required this.title,
    required this.titleStyle,
    required this.subtitleStyle,
  });

  final String title;
  final TextStyle titleStyle;
  final TextStyle subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final lineColor = AppColors.chaputWhite.withValues(alpha: 0.72);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 88.0;
        final textScaler = MediaQuery.textScalerOf(context);
        final titleHeight = (TextPainter(
          text: TextSpan(text: title, style: titleStyle),
          textDirection: Directionality.of(context),
          textScaler: textScaler,
          maxLines: 2,
        )..layout(maxWidth: width)).height;
        final lineHeight = ((subtitleStyle.fontSize ?? 12.5) * 0.88).clamp(
          10.0,
          13.0,
        );
        const lineGap = 9.0;
        final bodyTop = math.min(height, titleHeight + 8);
        final bodyHeight = math.max(0.0, height - bodyTop);
        var lineCount = ((bodyHeight + lineGap) / (lineHeight + lineGap))
            .floor()
            .clamp(1, 12);
        while (lineCount > 1 &&
            (lineCount * lineHeight + (lineCount - 1) * lineGap) > bodyHeight) {
          lineCount -= 1;
        }

        return ClipRect(
          child: SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
                if (bodyHeight > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: bodyTop,
                    height: bodyHeight,
                    child: ShimmerLoading(
                      baseColor: AppColors.chaputWhite.withValues(alpha: 0.34),
                      highlightColor: AppColors.chaputWhite.withValues(
                        alpha: 0.86,
                      ),
                      period: const Duration(milliseconds: 1050),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < lineCount; i++) ...[
                            FractionallySizedBox(
                              widthFactor: _paragraphLineWidthFactor(
                                i,
                                lineCount,
                              ),
                              child: ShimmerLine(
                                height: lineHeight,
                                radius: 999,
                                color: lineColor,
                              ),
                            ),
                            if (i != lineCount - 1)
                              const SizedBox(height: lineGap),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _paragraphLineWidthFactor(int index, int lineCount) {
    if (index == lineCount - 1) return 0.62;
    const widths = [0.94, 0.86, 0.98, 0.78, 0.91, 0.83];
    return widths[index % widths.length];
  }
}
