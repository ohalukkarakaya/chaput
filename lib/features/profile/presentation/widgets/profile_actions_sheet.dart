import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/recommended_users/application/recommended_user_controller.dart';
import '../../../../features/social/application/block_controller.dart';
import '../../../../features/social/application/restrictions_controller.dart';
import '../../../../features/social/application/ui_restriction_override_provider.dart';
import 'sheet_handle.dart';

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
          backgroundColor: Colors.transparent,
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
          color: Colors.black.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.more_vert,
          size: 18,
          color: Colors.black,
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
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),

          ProfileActionTile(
            icon: Icons.remove_circle_outline,
            title: iRestrictedHim ? 'Zaten kısıtlı' : 'Kısıtla',
            subtitle: iRestrictedHim
                ? 'Bu kullanıcıyı zaten kısıtladın'
                : 'Bu kullanıcının etkileşimleri sınırlandırılır',
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
            title: 'Engelle',
            subtitle: 'Bu kullanıcı seni göremez ve etkileşemez',
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
    final color = !enabled ? Colors.grey : (destructive ? Colors.red : Colors.black);

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
          color: enabled ? Colors.black.withOpacity(0.6) : Colors.grey,
        ),
      ),
      onTap: enabled ? onTap : null,
    );
  }
}
