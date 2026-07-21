import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/ui/widgets/glow_shimmer_card.dart';
import '../../../../core/ux/chaput_sound_service.dart';
import '../../../profile/application/profile_visit_history_controller.dart';
import '../../../profile/domain/profile_preview.dart';
import '../../../profile/presentation/widgets/profile_avatar_hero.dart';
import '../../../social/application/follow_controller.dart';
import '../../../social/application/follow_state.dart';

class RecommendedUserCard extends ConsumerStatefulWidget {
  const RecommendedUserCard({
    super.key,
    required this.user,
    required this.width,
    required this.onDismiss,
    this.onOpenProfile,
    this.heroEnabled = true,
  });

  final ProfilePreview user;
  final double width;
  final ValueChanged<String> onDismiss;
  final Future<void> Function(ProfilePreview user)? onOpenProfile;
  final bool heroEnabled;

  @override
  ConsumerState<RecommendedUserCard> createState() =>
      _RecommendedUserCardState();
}

class _RecommendedUserCardState extends ConsumerState<RecommendedUserCard> {
  void _showGlassToast(
    BuildContext context,
    String message, {
    IconData icon = Icons.hourglass_top_rounded,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          backgroundColor: AppColors.chaputTransparent,
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          duration: const Duration(seconds: 3),
          content: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.chaputBlack.withOpacity(0.78),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.chaputWhite.withOpacity(0.12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: AppColors.chaputWhite, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: AppColors.chaputWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }

  Future<void> _openProfile() async {
    final user = widget.user;
    HapticFeedback.selectionClick();

    final onOpenProfile = widget.onOpenProfile;
    if (onOpenProfile != null) {
      await onOpenProfile(user);
      return;
    }

    ref.read(profileVisitHistoryProvider.notifier).record(user);
    final route = await Routes.profile(user.id);
    if (!mounted) return;
    await context.push(route, extra: {profilePreviewExtraKey: user});
  }

  Future<void> _handleFollowTap(
    ProfilePreview user,
    FollowState followState,
  ) async {
    final username = user.username;
    if (username == null || username.isEmpty) return;
    final rateLimitedMessage = context.t('profile.follow_rate_limited');
    final recoFailedMessage = context.t('home.reco_failed');

    final isFollowing =
        followState is FollowIdle && followState.isFollowing == true;
    final requestPending =
        (followState is FollowIdle && followState.requestPending == true) ||
        user.requestPending;
    if (requestPending && !isFollowing) {
      return;
    }

    HapticFeedback.selectionClick();
    if (!isFollowing) {
      unawaited(
        ChaputSoundService.instance.play(
          ChaputSoundEffect.refreshRecommendedUser,
        ),
      );
    }

    try {
      final ctrl = ref.read(followControllerProvider(username).notifier);
      if (isFollowing) {
        await ctrl.unfollow();
        return;
      }

      await ctrl.follow();
      final latestState = ref.read(followControllerProvider(username));
      if (user.isPublic &&
          latestState is FollowIdle &&
          latestState.isFollowing == true &&
          mounted) {
        widget.onDismiss(user.id);
      }
    } on FollowActionException catch (e) {
      if (!mounted) return;
      if (e.code == 'follow_request_rate_limited') {
        _showGlassToast(context, rateLimitedMessage);
      } else {
        _showGlassToast(
          context,
          recoFailedMessage,
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final username = user.username;
    final followState = (username == null || username.isEmpty)
        ? const FollowIdle()
        : ref.watch(followControllerProvider(username));
    final isLoading = followState is FollowLoading;
    final isFollowing =
        followState is FollowIdle && followState.isFollowing == true;
    final requestPending =
        (followState is FollowIdle && followState.requestPending == true) ||
        user.requestPending;
    final canTapAction =
        !isLoading &&
        username != null &&
        username.isNotEmpty &&
        (!requestPending || isFollowing);

    final actionColor = requestPending
        ? AppColors.chaputMaterialBlue
        : (isFollowing ? AppColors.chaputGrey300 : AppColors.chaputBlack);
    final actionForeground = isFollowing
        ? AppColors.chaputBlack
        : AppColors.chaputWhite;
    final actionLabel = requestPending
        ? context.t('profile.follow_request_sent')
        : (isFollowing
              ? context.t('profile.unfollow')
              : context.t('profile.follow'));

    return SizedBox(
      width: widget.width,
      child: GlowShimmerCard(
        radius: 22,
        glowSigma: 0,
        glowOpacity: 0,
        enableBlur: false,
        glassOpacity: 0.96,
        enableInnerShimmer: false,
        padding: EdgeInsets.zero,
        child: Container(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _openProfile,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileAvatarHero(
                      preview: user,
                      width: 48,
                      height: 48,
                      enabled: widget.heroEnabled,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              username == null || username.isEmpty
                                  ? context.t('common.na')
                                  : '@$username',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.chaputBlack.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onDismiss(user.id);
                      },
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.chaputWhite.withOpacity(0.68),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canTapAction
                      ? () => _handleFollowTap(user, followState)
                      : null,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    backgroundColor: actionColor,
                    foregroundColor: actionForeground,
                    disabledBackgroundColor: actionColor,
                    disabledForegroundColor: actionForeground.withOpacity(0.92),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              actionForeground,
                            ),
                          ),
                        )
                      : Icon(
                          requestPending
                              ? Icons.schedule_rounded
                              : (isFollowing
                                    ? Icons.person_remove_alt_1_rounded
                                    : Icons.add_rounded),
                          size: 18,
                        ),
                  label: Text(
                    actionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
