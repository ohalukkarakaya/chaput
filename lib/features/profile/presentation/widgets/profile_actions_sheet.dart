import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/recommended_users/application/recommended_user_controller.dart';
import '../../../../features/social/application/block_controller.dart';
import '../../../../features/social/application/restrictions_controller.dart';
import '../../../../features/social/application/ui_restriction_override_provider.dart';
import 'sheet_handle.dart';
import 'package:chaput/core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

class ProfileActionsButton extends StatelessWidget {
  const ProfileActionsButton({
    super.key,
    required this.username,
    required this.userId,
    required this.iRestrictedHim,
  });

  final String username;
  final String userId;
  final bool iRestrictedHim;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      radius: 20,
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.chaputTransparent,
          builder: (_) => ProfileActionsSheet(
            username: username,
            userId: userId,
            iRestrictedHim: iRestrictedHim,
          ),
        );
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.chaputBlack.withOpacity(0.08),
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
    required this.username,
    required this.userId,
    required this.iRestrictedHim,
  });

  final String username;
  final String userId;
  final bool iRestrictedHim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final blockSt = ref.watch(blockControllerProvider);
    final restrictSt = ref.watch(restrictionsControllerProvider);

    final busy = blockSt is BlockActionLoading || restrictSt is RestrictLoading;
    final bool restrictDisabled = busy || iRestrictedHim;

    return Container(
      padding: EdgeInsets.only(
        top: 8,
        bottom: bottomInset > 0 ? bottomInset : 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.chaputWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),

          ProfileActionTile(
            icon: Icons.remove_circle_outline,
            title: iRestrictedHim ? context.t('profile_actions.restrict_already') : context.t('profile_actions.restrict'),
            subtitle: iRestrictedHim
                ? context.t('profile_actions.restrict_already_desc')
                : context.t('profile_actions.restrict_desc'),
            enabled: !restrictDisabled,
            onTap: () async {
              ref.read(uiRestrictedOverrideProvider(userId).notifier).state = true;
              Navigator.pop(context);
              try {
                final restrictedNow = await ref
                    .read(restrictionsControllerProvider.notifier)
                    .toggle(userId);
                if (restrictedNow != true) {
                  ref.read(uiRestrictedOverrideProvider(userId).notifier).state = null;
                }
              } catch (_) {
                ref.read(uiRestrictedOverrideProvider(userId).notifier).state = null;
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
                    final rootNav = Navigator.of(context, rootNavigator: true);

                    rootNav.pop();

                    try {
                      await ref.read(recommendedUserControllerProvider.notifier).refresh();

                      await ref.read(blockControllerProvider.notifier).blockUser(username);

                      rootNav.pop();
                    } catch (_) {}
                  },
          ),
        ],
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
    final color = !enabled ? AppColors.chaputGrey : (destructive ? AppColors.chaputMaterialRed : AppColors.chaputBlack);

    return ListTile(
      enabled: enabled,
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: enabled ? AppColors.chaputBlack.withOpacity(0.6) : AppColors.chaputGrey,
        ),
      ),
      onTap: enabled ? onTap : null,
    );
  }
}
