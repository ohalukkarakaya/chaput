import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/share/chaput_share_links.dart';
import '../../../../features/recommended_users/application/recommended_user_controller.dart';
import '../../../../features/social/application/block_controller.dart';
import '../../../../features/social/application/restrictions_controller.dart';
import '../../../../features/social/application/ui_restriction_override_provider.dart';
import '../../../feedback/presentation/feedback_launcher.dart';
import '../../../../core/router/routes.dart';
import 'sheet_handle.dart';
import 'package:chaput/core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/ui/responsive/chaput_responsive.dart';

class ProfileActionsButton extends StatelessWidget {
  const ProfileActionsButton({
    super.key,
    required this.username,
    required this.userId,
    required this.iRestrictedHim,
    this.onSheetVisibilityChanged,
  });

  final String username;
  final String userId;
  final bool iRestrictedHim;
  final ValueChanged<bool>? onSheetVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      radius: 20,
      onTap: () async {
        HapticFeedback.selectionClick();
        onSheetVisibilityChanged?.call(true);
        try {
          await showModalBottomSheet<void>(
            context: context,
            backgroundColor: AppColors.chaputTransparent,
            builder: (_) => ProfileActionsSheet(
              hostContext: context,
              username: username,
              userId: userId,
              iRestrictedHim: iRestrictedHim,
            ),
          );
        } finally {
          onSheetVisibilityChanged?.call(false);
        }
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.chaputBlack.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.more_vert,
          size: 18,
          color: AppColors.chaputBlack,
        ),
      ),
    );
  }
}

class ProfileActionsSheet extends ConsumerWidget {
  const ProfileActionsSheet({
    super.key,
    required this.hostContext,
    required this.username,
    required this.userId,
    required this.iRestrictedHim,
  });

  final BuildContext hostContext;
  final String username;
  final String userId;
  final bool iRestrictedHim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = context.responsive.bottomSheetInnerPadding();

    final blockSt = ref.watch(blockControllerProvider);
    final restrictSt = ref.watch(restrictionsControllerProvider);

    final busy = blockSt is BlockActionLoading || restrictSt is RestrictLoading;
    final nextRestricted = !iRestrictedHim;

    return Material(
      color: AppColors.chaputWhite,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(top: 8, bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),

            ProfileActionTile(
              icon: Icons.ios_share_rounded,
              title: context.t('profile_actions.share'),
              subtitle: context.t('profile_actions.share_desc'),
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
                SharePlus.instance.share(
                  ShareParams(
                    text: ChaputShareLinks.profile(username),
                    subject: context.t('share.subject'),
                  ),
                );
              },
            ),

            ProfileActionTile(
              icon: Icons.bug_report_outlined,
              title: context.t('settings.row_feedback'),
              subtitle: context.t('settings.row_feedback_sub'),
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
                Future.microtask(
                  () => showAppFeedbackSheet(
                    hostContext,
                    ref,
                    triggerSource: 'profile_actions_menu',
                  ),
                );
              },
            ),

            ProfileActionTile(
              icon: Icons.remove_circle_outline,
              title: iRestrictedHim
                  ? context.t('profile_actions.unrestrict')
                  : context.t('profile_actions.restrict'),
              subtitle: iRestrictedHim
                  ? context.t('profile_actions.unrestrict_desc')
                  : context.t('profile_actions.restrict_desc'),
              enabled: !busy,
              onTap: () async {
                ref.read(uiRestrictedOverrideProvider(userId).notifier).state =
                    nextRestricted;
                Navigator.pop(context);
                try {
                  final restrictedNow = await ref
                      .read(restrictionsControllerProvider.notifier)
                      .toggle(userId);
                  ref
                          .read(uiRestrictedOverrideProvider(userId).notifier)
                          .state =
                      restrictedNow;
                } catch (_) {
                  ref
                          .read(uiRestrictedOverrideProvider(userId).notifier)
                          .state =
                      null;
                }
              },
            ),

            ProfileActionTile(
              icon: Icons.block,
              title: context.t('profile_actions.block'),
              subtitle: context.t('profile_actions.block_desc'),
              destructive: true,
              onTap: busy
                  ? () {}
                  : () async {
                      final router = GoRouter.of(context);
                      final rootNav = Navigator.of(
                        context,
                        rootNavigator: true,
                      );

                      rootNav.pop();

                      try {
                        await ref
                            .read(blockControllerProvider.notifier)
                            .blockUser(username);

                        router.go(Routes.home);

                        unawaited(
                          ref
                              .read(recommendedUserControllerProvider.notifier)
                              .refresh(),
                        );
                      } catch (_) {}
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileActionTile extends StatelessWidget {
  const ProfileActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? AppColors.chaputGrey
        : (destructive ? AppColors.chaputMaterialRed : AppColors.chaputBlack);

    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: color),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: enabled
              ? AppColors.chaputBlack.withValues(alpha: 0.6)
              : AppColors.chaputGrey,
        ),
      ),
      onTap: enabled ? onTap : null,
    );
  }
}
