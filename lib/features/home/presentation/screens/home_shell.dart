import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';

import '../../../../core/deep_links/deep_link_state.dart';
import '../../../../core/app_availability/app_availability_controller.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/app_availability/app_update_service.dart';
import '../../../../core/ui/backgrounds/animated_mesh_background.dart';
import '../../../../core/ui/responsive/chaput_responsive.dart';
import '../../../../core/storage/tutorial_storage.dart';
import '../../../../core/review/app_review_service.dart';

import '../../../helpers/string_helpers/format_full_name.dart';
import '../../../me/application/me_controller.dart';
import '../../../notifications/application/notification_badge_service.dart';
import '../../../notifications/application/notification_count_controller.dart';
import '../../../notifications/data/notification_api_provider.dart';
import '../../../onboarding/application/onboarding_permission_coordinator.dart';
import '../../../../chaput/data/chaput_socket.dart';
import '../../../notifications/application/push_token_registrar.dart';
import '../../../profile/domain/profile_preview.dart';
import '../../../profile/presentation/widgets/profile_avatar_hero.dart';
import '../../../user_search/presentation/search_overlay.dart';
import '../../../recommended_users/application/recommended_user_controller.dart';
import '../../../recommended_users/domain/recommended_user.dart';
import '../../../recommended_users/presentation/widgets/recommended_user_card.dart';
import '../../../../core/ui/widgets/glow_shimmer_card.dart';
import '../../../../core/ui/widgets/share_bar.dart';
import '../../../../core/ui/widgets/shimmer_skeleton.dart';
import 'package:chaput/core/i18n/app_localizations.dart';
import '../widgets/app_review_prompt_sheet.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  StreamSubscription<ChaputSocketEvent>? _socketSub;
  final GlobalKey _recoShowcaseKey = GlobalKey();
  String _homeTutorialUserId = '';
  bool _homeTutorialCheckQueued = false;
  bool _homeTutorialCheckInFlight = false;
  bool _homeRecommendationTutorialActive = false;
  bool _homeRecommendationDataSettled = false;
  bool _homeRecommendationTargetReady = false;
  bool _homeRecommendationCompletedInMemory = false;
  bool _homeFeedbackTutorialActive = false;
  bool _homeFeedbackCompletedInMemory = false;
  bool _notificationsBooted = false;
  bool _notificationsBootScheduled = false;
  bool _pendingDeepLinkOpenScheduled = false;
  bool _reviewPromptScheduled = false;
  bool _reviewPromptCheckInFlight = false;

  void _syncHomeTutorialState({
    required String userId,
    required bool recommendationDataSettled,
  }) {
    final userChanged = userId != _homeTutorialUserId;
    if (userChanged) {
      _homeTutorialUserId = userId;
      _homeTutorialCheckInFlight = false;
      _homeRecommendationTutorialActive = false;
      _homeRecommendationTargetReady = false;
      _homeRecommendationCompletedInMemory = false;
      _homeFeedbackTutorialActive = false;
      _homeFeedbackCompletedInMemory = false;
    }

    final stateChanged =
        userChanged ||
        recommendationDataSettled != _homeRecommendationDataSettled;
    _homeRecommendationDataSettled = recommendationDataSettled;

    if (stateChanged) _queueHomeTutorialCheck();
  }

  void _setHomeRecommendationTargetReady({
    required String userId,
    required bool isReady,
  }) {
    if (!mounted ||
        userId != _homeTutorialUserId ||
        isReady == _homeRecommendationTargetReady) {
      return;
    }

    _homeRecommendationTargetReady = isReady;
    _queueHomeTutorialCheck();
  }

  void _queueHomeTutorialCheck() {
    if (_homeTutorialCheckQueued || !mounted) return;
    _homeTutorialCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeTutorialCheckQueued = false;
      if (!mounted) return;
      unawaited(_tryStartNextHomeTutorial());
    });
  }

  Future<void> _tryStartNextHomeTutorial() async {
    if (_homeTutorialCheckInFlight ||
        _homeRecommendationTutorialActive ||
        _homeFeedbackTutorialActive ||
        _homeTutorialUserId.isEmpty ||
        _isHomeShowcaseRunning()) {
      return;
    }

    _homeTutorialCheckInFlight = true;
    final expectedUserId = _homeTutorialUserId;
    final storage = ref.read(tutorialStorageProvider);

    try {
      final showRecommended =
          !_homeRecommendationCompletedInMemory &&
          await storage.shouldShow(expectedUserId, 'home_recommended');
      if (!_isCurrentHomeTutorialUser(expectedUserId)) return;

      if (showRecommended) {
        if (!_homeRecommendationDataSettled) return;

        if (_homeRecommendationTargetReady) {
          _homeRecommendationTutorialActive = true;
          try {
            ShowcaseView.get().startShowCase([_recoShowcaseKey]);
          } catch (_) {
            _homeRecommendationTutorialActive = false;
            _queueHomeTutorialCheck();
            return;
          }
          _homeRecommendationCompletedInMemory = true;
          await storage.markShown(expectedUserId, 'home_recommended');
          return;
        }

        // The recommendation request completed without a card to target.
        // Record this unavailable step and immediately continue in priority.
        _homeRecommendationCompletedInMemory = true;
        await storage.markShown(expectedUserId, 'home_recommended');
        if (!_isCurrentHomeTutorialUser(expectedUserId)) return;
      }

      final showFeedback =
          !_homeFeedbackCompletedInMemory &&
          await storage.shouldShow(expectedUserId, 'home_feedback_gesture');
      if (!showFeedback || !_isCurrentHomeTutorialUser(expectedUserId)) return;

      _homeFeedbackTutorialActive = true;
      await _showFeedbackGestureTutorial();
      if (!_isCurrentHomeTutorialUser(expectedUserId)) return;

      _homeFeedbackCompletedInMemory = true;
      await storage.markShown(expectedUserId, 'home_feedback_gesture');
    } finally {
      if (_homeTutorialUserId == expectedUserId) {
        _homeTutorialCheckInFlight = false;
        _homeFeedbackTutorialActive = false;
      }
    }
  }

  bool _isCurrentHomeTutorialUser(String userId) {
    return mounted && userId == _homeTutorialUserId;
  }

  bool _isHomeShowcaseRunning() {
    try {
      return ShowcaseView.get().isShowcaseRunning;
    } catch (_) {
      return false;
    }
  }

  void _handleHomeShowcaseFinished() {
    _homeRecommendationTutorialActive = false;
    _queueHomeTutorialCheck();
  }

  void _handleHomeShowcaseDismissed(GlobalKey? dismissedAt) {
    if (dismissedAt == null || dismissedAt == _recoShowcaseKey) {
      _homeRecommendationTutorialActive = false;
    }
  }

  Future<void> _showFeedbackGestureTutorial() async {
    if (!mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'feedback tutorial',
      barrierColor: AppColors.chaputBlack.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Material(
            color: AppColors.chaputTransparent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 292,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      decoration: BoxDecoration(
                        color: AppColors.chaputBlack.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.chaputBlack.withOpacity(0.28),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FeedbackPinchPreview(),
                          const SizedBox(height: 10),
                          Text(
                            context.t('showcase.home_feedback_title'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.chaputWhite,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.t('showcase.home_feedback_body'),
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: AppColors.chaputWhite.withOpacity(0.9),
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
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _scheduleReviewPrompt(String userId) async {
    if (_reviewPromptCheckInFlight || _reviewPromptScheduled) return;
    _reviewPromptCheckInFlight = true;

    final tutorialStorage = ref.read(tutorialStorageProvider);
    try {
      final hasPendingTutorial =
          await tutorialStorage.shouldShow(userId, 'home_recommended') ||
          await tutorialStorage.shouldShow(userId, 'home_feedback_gesture');
      if (!mounted) return;

      if (hasPendingTutorial) return;
      if (ref.read(appAvailabilityProvider).blocksApp) return;

      final updateSnapshot = await ref
          .read(appUpdateServiceProvider)
          .checkForUpdate();
      if (!mounted) return;

      if (!updateSnapshot.storePublished) return;

      final shouldPrompt = await ref
          .read(appReviewServiceProvider)
          .shouldPrompt(userId);
      if (!shouldPrompt || !mounted) return;

      _reviewPromptScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 650));
        if (!mounted) return;
        if (ref.read(pendingDeepLinkProvider) != null) return;
        if (ref.read(appAvailabilityProvider).blocksApp) return;

        final action = await showAppReviewPromptSheet(this.context);
        if (!mounted) return;

        final service = ref.read(appReviewServiceProvider);
        switch (action ?? AppReviewPromptAction.later) {
          case AppReviewPromptAction.liked:
            await service.markLiked(userId);
            break;
          case AppReviewPromptAction.later:
            await service.markAskLater(userId);
            break;
        }
      });
    } finally {
      _reviewPromptCheckInFlight = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _scheduleNotificationsBoot();
  }

  void _scheduleNotificationsBoot() {
    if (_notificationsBooted || _notificationsBootScheduled) return;
    _notificationsBootScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _notificationsBootScheduled = false;
        return;
      }
      unawaited(_bootNotifications());
    });
  }

  Future<void> _bootNotifications() async {
    if (_notificationsBooted) return;
    _notificationsBootScheduled = false;
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _notificationsBooted) return;
    if (ref.read(meControllerProvider).valueOrNull == null) return;
    _notificationsBooted = true;
    await OnboardingPermissionCoordinator.requestWithChaputPrompt(context);
    if (!mounted) return;
    await ref.read(chaputSocketProvider).resumeFromBackground();
    _socketSub ??= ref
        .read(chaputSocketProvider)
        .events
        .listen(_handleSocketEvent);
    await NotificationBadgeService.resetAppIconBadge();
    try {
      await ref
          .read(notificationApiProvider)
          .resetBadge(allowUnauthorized: true);
    } catch (_) {}
    await ref.read(pushTokenRegistrarProvider).registerOnce();
  }

  void _restartBootIfUnauthenticated() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(Routes.boot);
    });
  }

  void _schedulePendingDeepLinkOpen() {
    if (_pendingDeepLinkOpenScheduled) return;
    _pendingDeepLinkOpenScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_openPendingDeepLinkFromHome());
    });
  }

  Future<void> _openPendingDeepLinkFromHome() async {
    _pendingDeepLinkOpenScheduled = false;
    if (!mounted) return;
    if (ref.read(meControllerProvider).valueOrNull == null) return;

    final scheduledTarget = ref.read(pendingDeepLinkProvider);
    if (scheduledTarget == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final target = ref.read(pendingDeepLinkProvider);
    if (target == null) return;
    if (!identical(target, scheduledTarget)) {
      _schedulePendingDeepLinkOpen();
      return;
    }
    ref.read(pendingDeepLinkProvider.notifier).state = null;

    if (target.location == Routes.home) return;

    if (target.location == Routes.onboarding ||
        target.location == Routes.login ||
        target.location == Routes.register) {
      context.go(target.location, extra: target.extra);
      return;
    }
    context.push(target.location, extra: target.extra);
  }

  void _handleSocketEvent(ChaputSocketEvent ev) {
    if (ev.type != 'notif.created') return;
    final me = ref.read(meControllerProvider).valueOrNull;
    final meId = me?.user.userId ?? '';
    if (meId.isEmpty) return;
    final raw = ev.data['notification'];
    var isForMe = false;
    if (raw is Map) {
      final userId = raw['user_id']?.toString() ?? '';
      if (userId.isEmpty) return;
      if (userId != meId) return;
      isForMe = true;
    }
    final unread = ev.data['unread_count'];
    if (isForMe) {
      if (unread is int) {
        ref
            .read(notificationCountControllerProvider.notifier)
            .updateFromSocket(unread);
      } else if (unread is num) {
        ref
            .read(notificationCountControllerProvider.notifier)
            .updateFromSocket(unread.toInt());
      }
    }
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _socketSub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      onFinish: _handleHomeShowcaseFinished,
      onDismiss: _handleHomeShowcaseDismissed,
      builder: (_) {
        final meState = ref.watch(meControllerProvider);
        final me = meState.valueOrNull;
        if (me == null) {
          if (!meState.isLoading) {
            _restartBootIfUnauthenticated();
          }
          return const Scaffold(
            backgroundColor: AppColors.chaputCloudBlue,
            body: SizedBox.expand(),
          );
        }
        final meId = me.user.userId;
        final recommendationState = ref.watch(
          recommendedUserControllerProvider,
        );
        _syncHomeTutorialState(
          userId: meId,
          recommendationDataSettled:
              recommendationState.hasValue || recommendationState.hasError,
        );
        _scheduleNotificationsBoot();
        if (ref.watch(pendingDeepLinkProvider) != null) {
          _schedulePendingDeepLinkOpen();
        }
        if (!_reviewPromptScheduled &&
            !_reviewPromptCheckInFlight &&
            meId.isNotEmpty &&
            ref.read(pendingDeepLinkProvider) == null) {
          unawaited(_scheduleReviewPrompt(meId));
        }

        return Scaffold(
          backgroundColor: AppColors.chaputCloudBlue,
          resizeToAvoidBottomInset: false,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const RepaintBoundary(
                child: AnimatedMeshBackground(
                  baseColor: AppColors.chaputCloudBlue,
                ),
              ),

              // 🌳 ALT DEKOR (SafeArea DIŞINDA) → tam en alta, tam sağ/sola oturur
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.95,
                    child: Image.asset(
                      'assets/images/tree_bg.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // ✅ UI katmanı (SafeArea içinde) → görselin üstünde kalır
              SafeArea(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ✅ Header + Search (üst)
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: SafeArea(
                        bottom: false,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Consumer(
                                        builder: (context, ref, _) {
                                          final meAsync = ref.watch(
                                            meControllerProvider,
                                          );

                                          return meAsync.when(
                                            loading: () =>
                                                const _HomeHeaderShimmer(),
                                            error: (_, __) =>
                                                const SizedBox(height: 44),
                                            data: (me) {
                                              final rawName =
                                                  me?.user.fullName ?? '';
                                              final fullName = formatFullName(
                                                rawName,
                                              );
                                              final unread = ref.watch(
                                                notificationCountControllerProvider,
                                              );
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      onTap: () {
                                                        HapticFeedback.selectionClick();
                                                        context.push(
                                                          Routes.notifications,
                                                        );
                                                      },
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.fromLTRB(
                                                              0,
                                                              3,
                                                              8,
                                                              3,
                                                            ),
                                                        child: Row(
                                                          children: [
                                                            Text(
                                                              context.t(
                                                                'home.welcome',
                                                              ),
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w300,
                                                                color: AppColors
                                                                    .chaputBlack
                                                                    .withOpacity(
                                                                      0.55,
                                                                    ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 6,
                                                            ),
                                                            Stack(
                                                              clipBehavior:
                                                                  Clip.none,
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .keyboard_arrow_down,
                                                                  size: 18,
                                                                  color: AppColors
                                                                      .chaputBlack
                                                                      .withOpacity(
                                                                        0.6,
                                                                      ),
                                                                ),
                                                                if (unread > 0)
                                                                  Positioned(
                                                                    right: -6,
                                                                    top: -6,
                                                                    child: Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            5,
                                                                        vertical:
                                                                            2,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: AppColors
                                                                            .chaputBlack,
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              10,
                                                                            ),
                                                                      ),
                                                                      child: Text(
                                                                        unread >
                                                                                99
                                                                            ? '99+'
                                                                            : unread.toString(),
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              10,
                                                                          fontWeight:
                                                                              FontWeight.w800,
                                                                          color:
                                                                              AppColors.chaputWhite,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    fullName.isEmpty
                                                        ? context.t('common.na')
                                                        : fullName,
                                                    maxLines: 1,
                                                    softWrap: false,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color:
                                                          AppColors.chaputBlack,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Sağ: avatar
                                    Consumer(
                                      builder: (context, ref, _) {
                                        final meAsync = ref.watch(
                                          meControllerProvider,
                                        );

                                        return meAsync.when(
                                          loading: () =>
                                              const _HomeAvatarShimmer(),
                                          error: (_, __) => const SizedBox(
                                            width: 40,
                                            height: 40,
                                          ),
                                          data: (me) {
                                            if (me == null) {
                                              return const SizedBox(
                                                width: 40,
                                                height: 40,
                                              );
                                            }
                                            final user = me.user;
                                            final preview = ProfilePreview(
                                              id: user.userId,
                                              username: user.username.isEmpty
                                                  ? null
                                                  : user.username,
                                              fullName: user.fullName,
                                              defaultAvatar:
                                                  user.defaultAvatar ?? '',
                                              profilePhotoKey:
                                                  user.profilePhotoKey,
                                              profilePhotoUrl:
                                                  user.profilePhotoUrl,
                                              isPublic: true,
                                            );

                                            return GestureDetector(
                                              onTap: () async {
                                                HapticFeedback.selectionClick();
                                                final route =
                                                    await Routes.profile(
                                                      user.userId,
                                                    );
                                                if (!context.mounted) return;
                                                context.push(
                                                  route,
                                                  extra: {
                                                    profilePreviewExtraKey:
                                                        preview,
                                                  },
                                                );
                                              },
                                              child: ProfileAvatarHero(
                                                preview: preview,
                                                width: 42,
                                                height: 42,
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // ✅ Search bar
                                Hero(
                                  tag: SearchOverlay.heroTag,
                                  child: Material(
                                    color: AppColors.chaputTransparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => Navigator.of(
                                        context,
                                      ).push(_SearchOverlayRoute()),
                                      child: Container(
                                        height: 46,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.chaputWhite
                                              .withOpacity(0.92),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.search, size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              context.t('search.hint'),
                                              style: TextStyle(
                                                color: AppColors.chaputBlack
                                                    .withOpacity(0.55),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 14),
                                _RecommendedUsersRail(
                                  showcaseKey: _recoShowcaseKey,
                                  viewerId: meId,
                                  onTargetReadyChanged: (isReady) {
                                    _setHomeRecommendationTargetReady(
                                      userId: meId,
                                      isReady: isReady,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ✅ EN ALT: Share bar sabit (foreground)
              Positioned(
                left: 16,
                right: 16,
                bottom: 0,
                child: Padding(
                  padding: context.responsive.bottomFixedPadding(base: 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Consumer(
                        builder: (context, ref, _) {
                          final meAsync = ref.watch(meControllerProvider);

                          return meAsync.when(
                            loading: () => const _ShareBarShimmer(),
                            error: (_, __) => const SizedBox(),
                            data: (me) {
                              if (me == null) return const SizedBox();

                              final username = me.user.username;
                              if (username.isEmpty) {
                                return const SizedBox();
                              }

                              final link = 'https://chaput.app/me/$username';

                              return ShareBar(
                                link: link,
                                title: context.t('home.share_title'),
                                subtitle: context.t('home.share_subtitle'),
                                showShareButton: false,
                              );
                            },
                          );
                        },
                      ),
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

class _RecommendedUsersRail extends ConsumerStatefulWidget {
  const _RecommendedUsersRail({
    required this.showcaseKey,
    required this.viewerId,
    required this.onTargetReadyChanged,
  });

  final GlobalKey showcaseKey;
  final String viewerId;
  final ValueChanged<bool> onTargetReadyChanged;

  @override
  ConsumerState<_RecommendedUsersRail> createState() =>
      _RecommendedUsersRailState();
}

class _RecommendedUsersRailState extends ConsumerState<_RecommendedUsersRail> {
  final Set<String> _dismissedIds = <String>{};
  bool? _reportedTargetReady;
  int _targetReadyReportEpoch = 0;

  @override
  void didUpdateWidget(covariant _RecommendedUsersRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewerId == widget.viewerId) return;
    _dismissedIds.clear();
    _reportedTargetReady = null;
    _targetReadyReportEpoch += 1;
  }

  void _reportTargetReady(bool isReady) {
    if (_reportedTargetReady == isReady) return;
    _reportedTargetReady = isReady;
    final epoch = ++_targetReadyReportEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || epoch != _targetReadyReportEpoch) return;
      widget.onTargetReadyChanged(isReady);
    });
  }

  @override
  void dispose() {
    _targetReadyReportEpoch += 1;
    super.dispose();
  }

  void _refreshRecommended() {
    HapticFeedback.selectionClick();
    unawaited(ref.read(recommendedUserControllerProvider.notifier).refresh());
  }

  void _dismissCard(String id) {
    setState(() => _dismissedIds.add(id));
  }

  @override
  Widget build(BuildContext context) {
    final recAsync = ref.watch(recommendedUserControllerProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = screenWidth < 390 ? screenWidth - 96 : 250.0;

    return recAsync.when(
      loading: () {
        _reportTargetReady(false);
        return const _RecommendedUsersRailShimmer();
      },
      error: (e, _) {
        _reportTargetReady(false);
        return _RecommendedUsersEmptyCard(
          icon: Icons.error_outline_rounded,
          message: context.t('home.reco_failed'),
          actionLabel: context.t('common.retry'),
          onActionTap: _refreshRecommended,
        );
      },
      data: (items) {
        final visibleItems = items
            .where((u) => !_dismissedIds.contains(u.id))
            .toList(growable: false);

        if (visibleItems.isEmpty) {
          _reportTargetReady(false);
          return _RecommendedUsersEmptyCard(
            icon: Icons.people_outline_rounded,
            message: context.t('home.reco_empty'),
            actionLabel: context.t('common.refresh'),
            onActionTap: () {
              setState(_dismissedIds.clear);
              _refreshRecommended();
            },
          );
        }

        _reportTargetReady(true);

        return SizedBox(
          height: 154,
          child: ListView.separated(
            clipBehavior: Clip.none,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: visibleItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final user = visibleItems[index];
              final card = RecommendedUserCard(
                user: _previewFromRecommendedUser(user),
                width: cardWidth,
                onDismiss: _dismissCard,
              );

              if (index == 0) {
                return Showcase.withWidget(
                  key: widget.showcaseKey,
                  targetPadding: EdgeInsets.zero,
                  targetBorderRadius: BorderRadius.circular(22),
                  targetShapeBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  tooltipPosition: TooltipPosition.bottom,
                  toolTipMargin: 8,
                  targetTooltipGap: 8,
                  container: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      try {
                        ShowcaseView.get().completed(widget.showcaseKey);
                      } catch (_) {}
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.chaputBlack.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('showcase.home_reco_title'),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.chaputWhite,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.t('showcase.home_reco_body'),
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.3,
                                color: AppColors.chaputWhite.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  child: card,
                );
              }

              return card;
            },
          ),
        );
      },
    );
  }
}

ProfilePreview _previewFromRecommendedUser(RecommendedUser user) {
  return ProfilePreview(
    id: user.id,
    username: user.username,
    fullName: user.fullName,
    defaultAvatar: user.defaultAvatar,
    profilePhotoKey: user.profilePhotoKey,
    profilePhotoUrl: user.profilePhotoUrl,
    isPublic: user.isPublic,
    requestPending: user.requestPending,
  );
}

class _RecommendedUsersEmptyCard extends StatelessWidget {
  const _RecommendedUsersEmptyCard({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onActionTap,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    return GlowShimmerCard(
      radius: 22,
      glowSigma: 24,
      glowOpacity: 0.55,
      enableBlur: false,
      child: Row(
        children: [
          Icon(icon, color: AppColors.chaputWhite70),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(onPressed: onActionTap, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _RecommendedUsersRailShimmer extends StatelessWidget {
  const _RecommendedUsersRailShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 174,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: 2,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => const SizedBox(
          width: 260,
          child: GlowShimmerCard(
            radius: 22,
            glowSigma: 24,
            glowOpacity: 0.55,
            enableBlur: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerCircle(size: 48),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerLine(width: 120, height: 12),
                          SizedBox(height: 8),
                          ShimmerLine(width: 86, height: 10),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    ShimmerBlock(width: 34, height: 34, radius: 14),
                  ],
                ),
                Spacer(),
                ShimmerBlock(height: 42, radius: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeaderShimmer extends StatelessWidget {
  const _HomeHeaderShimmer();

  @override
  Widget build(BuildContext context) {
    return const ShimmerLoading(
      child: SizedBox(
        height: 44,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerLine(width: 90, height: 10),
            SizedBox(height: 8),
            ShimmerLine(width: 160, height: 16),
          ],
        ),
      ),
    );
  }
}

class _HomeAvatarShimmer extends StatelessWidget {
  const _HomeAvatarShimmer();

  @override
  Widget build(BuildContext context) {
    return const ShimmerLoading(child: ShimmerCircle(size: 42));
  }
}

class _ShareBarShimmer extends StatelessWidget {
  const _ShareBarShimmer();

  @override
  Widget build(BuildContext context) {
    return const ShimmerLoading(child: ShimmerBlock(height: 52, radius: 18));
  }
}

class _SearchOverlayRoute extends PageRouteBuilder<void> {
  _SearchOverlayRoute()
    : super(
        opaque: false,
        barrierDismissible: true,
        barrierColor: AppColors.chaputTransparent,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SearchOverlay(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );
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

class _FeedbackPinchPreview extends StatefulWidget {
  const _FeedbackPinchPreview();

  @override
  State<_FeedbackPinchPreview> createState() => _FeedbackPinchPreviewState();
}

class _FeedbackPinchPreviewState extends State<_FeedbackPinchPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.chaputWhite.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.chaputWhite.withOpacity(0.08)),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_controller.value);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                _PinchDot(
                  alignment: Alignment.lerp(
                    const Alignment(0.82, -0.72),
                    const Alignment(0.18, -0.08),
                    t,
                  )!,
                  size: lerpDouble(26, 18, t)!,
                ),
                _PinchDot(
                  alignment: Alignment.lerp(
                    const Alignment(-0.82, 0.72),
                    const Alignment(-0.18, 0.08),
                    t,
                  )!,
                  size: lerpDouble(26, 18, t)!,
                ),
                Align(
                  child: Container(
                    width: lerpDouble(56, 34, t)!,
                    height: 1.5,
                    color: AppColors.chaputWhite.withOpacity(
                      lerpDouble(0.1, 0.22, t)!,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PinchDot extends StatelessWidget {
  const _PinchDot({required this.alignment, required this.size});

  final Alignment alignment;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.chaputWhite.withOpacity(0.08),
          border: Border.all(
            color: AppColors.chaputWhite.withOpacity(0.42),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
