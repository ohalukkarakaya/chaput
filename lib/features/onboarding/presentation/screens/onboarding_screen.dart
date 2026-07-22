import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:chaput/core/i18n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/attribution/chaput_attribution_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/deep_links/deep_link_state.dart';
import '../../../../core/device/device_id_service.dart';
import '../../../../core/review/app_review_service.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/storage/secure_storage_provider.dart';
import '../../../../core/ui/responsive/chaput_responsive.dart';
import '../../../../core/ui/widgets/code_verify_sheet.dart';
import '../../../../core/ui/widgets/email_cta_form.dart';

import '../../../auth/data/auth_api.dart';
import '../../../me/application/me_controller.dart';
import '../../application/onboarding_tree_preload.dart';
import '../../application/onboarding_permission_coordinator.dart';
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
  static const _textRevealDelay = Duration(milliseconds: 160);

  final _emailController = TextEditingController();
  final PageController _textController = PageController();
  int _currentIndex = 0;
  int _textHeightIndex = 0;
  int _settledTextIndex = 0;
  int _shimmerShapeIndex = 0;
  int _textRevealToken = 0;
  bool _textResizeInProgress = false;
  List<double> _lastTextViewportHeights = const [];
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
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        unawaited(
          OnboardingPermissionCoordinator.requestWhenOnboardingIsVisible(
            context,
          ),
        );
      });
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
      if (!_textResizeInProgress && _shimmerShapeIndex != _settledTextIndex) {
        setState(() => _shimmerShapeIndex = _settledTextIndex);
      }
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
      if (_currentIndex != index ||
          _textResizeInProgress ||
          _shimmerShapeIndex != index) {
        setState(() {
          _currentIndex = index;
          _textResizeInProgress = false;
          _shimmerShapeIndex = index;
        });
      }
      return;
    }

    _textRevealToken += 1;
    final token = _textRevealToken;
    final previousIndex = _settledTextIndex.clamp(0, 8);
    final willResize = _willTextViewportResize(index);

    setState(() {
      _currentIndex = index;
      _shimmerShapeIndex = previousIndex;
      _textHeightIndex = index;
      _textResizeInProgress = willResize;
    });

    final delay = willResize ? _textHeightAnimationDuration : _textRevealDelay;
    Future<void>.delayed(delay, () {
      if (!mounted || token != _textRevealToken) return;
      setState(() {
        _textResizeInProgress = false;
        _settledTextIndex = index;
        _shimmerShapeIndex = index;
      });
    });
  }

  bool _willTextViewportResize(int targetIndex) {
    if (_lastTextViewportHeights.isEmpty) {
      return _textHeightIndex != targetIndex;
    }
    final currentHeight = _textViewportHeightAt(_textHeightIndex);
    final targetHeight = _textViewportHeightAt(targetIndex);
    if (currentHeight == null || targetHeight == null) {
      return _textHeightIndex != targetIndex;
    }
    return (currentHeight - targetHeight).abs() > 0.5;
  }

  double? _textViewportHeightAt(int index) {
    if (index < 0 || index >= _lastTextViewportHeights.length) return null;
    return _lastTextViewportHeights[index];
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
    InlineSpan? span,
  }) {
    final painter = TextPainter(
      text: span ?? TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);

    return painter.height;
  }

  TextSpan _buildOnboardingSubtitleSpan(
    String subtitle,
    TextStyle subtitleStyle,
  ) {
    final paragraphs = subtitle.split('\n\n');
    final children = <InlineSpan>[];

    for (var i = 0; i < paragraphs.length; i += 1) {
      if (i > 0) {
        children.add(const TextSpan(text: '\n\n'));
      }
      children.add(
        TextSpan(
          text: paragraphs[i],
          style: i == 0
              ? subtitleStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.chaputWhite.withValues(alpha: 0.94),
                )
              : subtitleStyle,
        ),
      );
    }

    return TextSpan(style: subtitleStyle, children: children);
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
      '',
      subtitleStyle,
      maxWidth: maxWidth,
      textScaler: textScaler,
      span: _buildOnboardingSubtitleSpan(subtitle, subtitleStyle),
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
      context.go(Routes.home);
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

  Future<void> _playSuccessHaptics() async {
    await HapticFeedback.selectionClick();
    await Future<void>.delayed(const Duration(milliseconds: 70));
    await HapticFeedback.selectionClick();
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

    await _playSuccessHaptics();

    await storage.saveAccessToken(verified.accessToken);
    await storage.saveRefreshToken(verified.refreshToken);

    try {
      final me = await ref
          .read(meControllerProvider.notifier)
          .fetchAndStoreMe();
      final userId = me?.user.userId ?? '';
      if (userId.isNotEmpty) {
        await ref
            .read(appReviewServiceProvider)
            .recordAppOpenForSession(userId);
      }
      unawaited(ref.read(chaputAttributionServiceProvider).recordLogin());
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

    await _playSuccessHaptics();

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
      final me = await ref
          .read(meControllerProvider.notifier)
          .fetchAndStoreMe();
      final userId = me?.user.userId ?? '';
      if (userId.isNotEmpty) {
        await ref
            .read(appReviewServiceProvider)
            .recordAppOpenForSession(userId);
      }
      unawaited(ref.read(chaputAttributionServiceProvider).recordSignUp());
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
    final textViewportHeights = slideHeights
        .map(
          (height) =>
              math.max(textViewportMinHeight, height + textMeasurementBuffer),
        )
        .toList(growable: false);
    _lastTextViewportHeights = textViewportHeights;
    final textHeightIndex = _textHeightIndex
        .clamp(0, sliderTexts.length - 1)
        .toInt();
    final shimmerShapeIndex = _shimmerShapeIndex
        .clamp(0, sliderTexts.length - 1)
        .toInt();
    final shimmerShapeText = sliderTexts[shimmerShapeIndex];
    final textViewportHeight = textViewportHeights[textHeightIndex];
    final textPageContentHeight = math.max(
      0.0,
      textViewportHeight - (textVerticalPadding * 2),
    );
    final showRealTextForIndex =
        !_textResizeInProgress && _settledTextIndex == _textHeightIndex
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
                                          child: SizedBox(
                                            height: textPageContentHeight,
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
                                                  switchOutCurve:
                                                      Curves.easeOut,
                                                  child: showReal
                                                      ? _OnboardingSlideText(
                                                          key: ValueKey(
                                                            'text-$index',
                                                          ),
                                                          title:
                                                              item['title'] ??
                                                              '',
                                                          subtitle:
                                                              item['subtitle'] ??
                                                              '',
                                                          titleStyle:
                                                              titleStyle,
                                                          subtitleStyle:
                                                              subtitleStyle,
                                                        )
                                                      : _textResizeInProgress
                                                      ? SizedBox(
                                                          key: ValueKey(
                                                            'blank-$index',
                                                          ),
                                                        )
                                                      : _OnboardingTextShimmer(
                                                          key: ValueKey(
                                                            'shimmer-$index-$shimmerShapeIndex',
                                                          ),
                                                          title:
                                                              shimmerShapeText['title'] ??
                                                              '',
                                                          subtitle:
                                                              shimmerShapeText['subtitle'] ??
                                                              '',
                                                          titleStyle:
                                                              titleStyle,
                                                          subtitleStyle:
                                                              subtitleStyle,
                                                        ),
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

  TextSpan _buildSubtitleSpan() {
    final paragraphs = subtitle.split('\n\n');
    final children = <InlineSpan>[];

    for (var i = 0; i < paragraphs.length; i += 1) {
      if (i > 0) {
        children.add(const TextSpan(text: '\n\n'));
      }
      children.add(
        TextSpan(
          text: paragraphs[i],
          style: i == 0
              ? subtitleStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.chaputWhite.withValues(alpha: 0.94),
                )
              : subtitleStyle,
        ),
      );
    }

    return TextSpan(style: subtitleStyle, children: children);
  }

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
        Text.rich(_buildSubtitleSpan(), textAlign: TextAlign.start),
      ],
    );
  }
}

class _OnboardingTextShimmer extends StatefulWidget {
  const _OnboardingTextShimmer({
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
  State<_OnboardingTextShimmer> createState() => _OnboardingTextShimmerState();
}

class _OnboardingTextShimmerState extends State<_OnboardingTextShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleBaseColor = AppColors.chaputWhite.withValues(alpha: 0.36);
    final featuredBaseColor = AppColors.chaputWhite.withValues(alpha: 0.32);
    final bodyBaseColor = AppColors.chaputWhite.withValues(alpha: 0.24);
    final titleHighlightColor = AppColors.chaputWhite.withValues(alpha: 0.86);
    final bodyHighlightColor = AppColors.chaputWhite.withValues(alpha: 0.68);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 88.0;
        final textScaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        final titleFontSize = widget.titleStyle.fontSize ?? 20.0;
        final subtitleFontSize = widget.subtitleStyle.fontSize ?? 12.5;
        final emojiSize = math.min(24.0, math.max(20.0, titleFontSize * 1.05));
        final titleLineHeight = math.min(
          19.0,
          math.max(15.0, titleFontSize * 0.78),
        );
        final featuredLineHeight = math.min(
          13.0,
          math.max(10.5, subtitleFontSize * 0.90),
        );
        final bodyLineHeight = math.min(
          12.0,
          math.max(10.0, subtitleFontSize * 0.82),
        );
        final titleText = _titleWithoutLeadingEmoji();
        final hasEmojiSlot = titleText != widget.title.trim();
        final titleTextWidth = hasEmojiSlot
            ? math.max(1.0, width - emojiSize - 8)
            : width;
        final titleWidths = _lineWidthFactors(
          text: titleText,
          style: widget.titleStyle,
          maxWidth: titleTextWidth,
          textScaler: textScaler,
          textDirection: direction,
          maxLines: 2,
        );
        final paragraphs = widget.subtitle
            .split('\n\n')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList(growable: false);
        final featuredStyle = widget.subtitleStyle.copyWith(
          fontWeight: FontWeight.w600,
        );
        final featuredWidths = paragraphs.isEmpty
            ? const <double>[0.78]
            : _lineWidthFactors(
                text: paragraphs.first,
                style: featuredStyle,
                maxWidth: width,
                textScaler: textScaler,
                textDirection: direction,
              );
        final bodyParagraphs = paragraphs.length <= 1
            ? const <String>[]
            : paragraphs.skip(1);
        final children = <Widget>[];
        var top = 0.0;

        void addLine({
          required double left,
          required double topOffset,
          required double lineWidth,
          required double lineHeight,
          required Color baseColor,
          required Color highlightColor,
          double radius = 999,
        }) {
          if (topOffset >= height || lineWidth <= 0) return;
          final visibleHeight = math.min(lineHeight, height - topOffset);
          if (visibleHeight <= 1) return;
          children.add(
            Positioned(
              left: left,
              top: topOffset,
              width: math.min(lineWidth, math.max(0.0, width - left)),
              height: visibleHeight,
              child: _OnboardingShimmerLine(
                animation: _controller,
                height: visibleHeight,
                baseColor: baseColor,
                highlightColor: highlightColor,
                radius: radius,
              ),
            ),
          );
        }

        if (hasEmojiSlot) {
          addLine(
            left: 0,
            topOffset: top,
            lineWidth: emojiSize,
            lineHeight: emojiSize,
            baseColor: titleBaseColor,
            highlightColor: titleHighlightColor,
            radius: 7,
          );
          addLine(
            left: emojiSize + 8,
            topOffset: top + ((emojiSize - titleLineHeight) / 2),
            lineWidth: titleTextWidth * titleWidths.first,
            lineHeight: titleLineHeight,
            baseColor: titleBaseColor,
            highlightColor: titleHighlightColor,
          );
          top += math.max(emojiSize, titleLineHeight) + 6;
        } else {
          addLine(
            left: 0,
            topOffset: top,
            lineWidth: width * titleWidths.first,
            lineHeight: titleLineHeight,
            baseColor: titleBaseColor,
            highlightColor: titleHighlightColor,
          );
          top += titleLineHeight + 6;
        }

        for (final factor in titleWidths.skip(1)) {
          addLine(
            left: 0,
            topOffset: top,
            lineWidth: width * factor,
            lineHeight: titleLineHeight,
            baseColor: titleBaseColor,
            highlightColor: titleHighlightColor,
          );
          top += titleLineHeight + 6;
        }

        top += 2;

        for (final factor in featuredWidths) {
          addLine(
            left: 0,
            topOffset: top,
            lineWidth: width * factor,
            lineHeight: featuredLineHeight,
            baseColor: featuredBaseColor,
            highlightColor: titleHighlightColor,
          );
          top += featuredLineHeight + 6;
        }

        if (bodyParagraphs.isNotEmpty) {
          top += 8;
        }

        for (final paragraph in bodyParagraphs) {
          final bodyWidths = _lineWidthFactors(
            text: paragraph,
            style: widget.subtitleStyle,
            maxWidth: width,
            textScaler: textScaler,
            textDirection: direction,
          );
          for (final factor in bodyWidths) {
            addLine(
              left: 0,
              topOffset: top,
              lineWidth: width * factor,
              lineHeight: bodyLineHeight,
              baseColor: bodyBaseColor,
              highlightColor: bodyHighlightColor,
            );
            top += bodyLineHeight + 6;
          }
          top += 7;
        }

        return ClipRect(
          child: SizedBox(
            height: height,
            child: Stack(clipBehavior: Clip.hardEdge, children: children),
          ),
        );
      },
    );
  }

  String _titleWithoutLeadingEmoji() {
    final title = widget.title.trim();
    final firstSpace = title.indexOf(' ');
    if (firstSpace > 0 && firstSpace <= 4 && firstSpace < title.length - 1) {
      return title.substring(firstSpace + 1).trim();
    }
    return title;
  }

  List<double> _lineWidthFactors({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required TextScaler textScaler,
    required TextDirection textDirection,
    int? maxLines,
  }) {
    if (text.trim().isEmpty || maxWidth <= 1) return const [0.62];

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);
    final metrics = painter.computeLineMetrics();
    if (metrics.isEmpty) return const [0.62];

    return metrics
        .map((metric) {
          final widthFactor = metric.width / maxWidth;
          return widthFactor.clamp(0.32, 0.98).toDouble();
        })
        .toList(growable: false);
  }
}

class _OnboardingShimmerLine extends StatelessWidget {
  const _OnboardingShimmerLine({
    required this.animation,
    required this.height,
    required this.baseColor,
    required this.highlightColor,
    this.radius = 999,
  });

  final Animation<double> animation;
  final double height;
  final Color baseColor;
  final Color highlightColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            children: [
              Container(height: height, color: baseColor),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-1.8 + (3.6 * t), 0),
                      end: Alignment(-0.8 + (3.6 * t), 0),
                      colors: [
                        AppColors.chaputTransparent,
                        highlightColor,
                        AppColors.chaputTransparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
