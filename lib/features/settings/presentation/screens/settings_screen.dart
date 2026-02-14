import 'dart:ui';
import 'dart:async';

import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:chaput/features/settings/presentation/screens/photo_settings_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';
import 'package:chaput/core/ui/widgets/shimmer_skeleton.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/secure_storage_provider.dart';
import '../../../auth/data/auth_api.dart';
import '../../../helpers/string_helpers/format_full_name.dart';
import '../../../me/application/me_controller.dart';
import '../../application/account_controller.dart';
import '../../application/privacy_controller.dart';
import 'archive_chaputs_screen.dart';
import 'blocked_restricted_screen.dart';
import 'email_change_screen.dart';

import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:chaput/core/router/routes.dart';
import 'package:chaput/core/i18n/app_localizations.dart';


class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(meControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.chaputLightGrey,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: meAsync.when(
                  loading: () => const _SettingsShell(child: _LoadingCard()),
                  error: (_, __) => const _SettingsShell(child: _ErrorCard()),
                  data: (me) {
                    final user = me?.user;
                    final username = user?.username ?? '';
                    final usernameLabel = username.isEmpty ? context.t('common.na') : '@$username';
                    final fullName = user?.fullName ?? context.t('common.na');
                
                    final defaultAvatar = user?.defaultAvatar;
                    final profilePhotoUrl = user?.profilePhotoUrl;

                    final privacySt = ref.watch(privacyControllerProvider);

                    // backend: isPublic? -> private = !isPublic
                    final bool privateAccountValue = (privacySt.isPublic == null)
                        ? false // yüklenene kadar kapalı göster (istersen skeleton da yaparız)
                        : !(privacySt.isPublic!);

                    // switch disabled: yüklenmemişken veya request sırasında istersen disable edebilirsin
                    final bool privateSwitchEnabled = privacySt.isPublic != null && !privacySt.isLoading;


                    return _SettingsShell(
                      child: _SettingsContent(
                        title: formatFullName(fullName),
                        subtitle: usernameLabel,
                        avatarUrl: (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty)
                            ? profilePhotoUrl
                            : (defaultAvatar ?? ''),
                        isDefaultAvatar: profilePhotoUrl == null || profilePhotoUrl.isEmpty,
                        onBack: () => Navigator.of(context).pop(),
                        onOpenPhoto: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PhotoSettingsScreen()),
                          );
                        },
                        onOpenEmail: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const EmailChangeScreen()),
                          );
                        },
                        onOpenPrivacy: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const BlockedRestrictedScreen()),
                          );
                        },
                        onOpenArchive: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ArchiveChaputsScreen()),
                          );
                        },
                        onPauseAccount: () async {
                          if (username.isEmpty) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.t('settings.username_not_available'))),
                              );
                            }
                            return;
                          }

                          final ok = await _confirmUsernameDialog(
                            context,
                            expectedUsername: username,
                            title: context.t('settings.pause_title'),
                            description: context.t('settings.pause_desc'),
                            confirmLabel: context.t('settings.pause_confirm'),
                            isDestructive: false,
                          );
                          if (!ok) return;

                          try {
                            await ref.read(accountControllerProvider.notifier).freezeMe();

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.t('settings.pause_success'))),
                              );
                            }

                            await _logoutNow(context, ref);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.t('settings.pause_failed'))),
                              );
                            }
                          }
                        },

                        onCloseAccount: () async {
                          if (username.isEmpty) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.t('settings.username_not_available'))),
                              );
                            }
                            return;
                          }

                          final ok = await _confirmUsernameDialog(
                            context,
                            expectedUsername: username,
                            title: context.t('settings.close_title'),
                            description: context.t('settings.close_desc'),
                            confirmLabel: context.t('settings.close_confirm'),
                            isDestructive: true,
                          );
                          if (!ok) return;

                          try {
                            await ref.read(accountControllerProvider.notifier).deleteMeHard();

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.t('settings.close_success'))),
                              );
                            }

                            await _logoutNow(context, ref);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.t('settings.close_failed'))),
                              );
                            }
                          }
                        },
                        onLogout: () async {
                          final storage = ref.read(tokenStorageProvider);
                          final refresh = await storage.readRefreshToken();

                          if (refresh == null || refresh.isEmpty) {
                            if (context.mounted) context.go(Routes.onboarding);
                            return;
                          }

                          try {
                            final api = ref.read(authApiProvider);
                            await api.logout(refreshToken: refresh);

                            await storage.clear();
                            if (context.mounted) context.go(Routes.onboarding);
                          } on DioException {
                            await storage.clear();
                            if (context.mounted) context.go(Routes.onboarding);
                          } catch (_) {
                            await storage.clear();
                            if (context.mounted) context.go(Routes.onboarding);
                          }
                        },

                        privateAccountValue: privateAccountValue,
                        privateSwitchEnabled: privateSwitchEnabled,
                        onPrivateAccountChanged: privateSwitchEnabled
                            ? (v) {
                          unawaited(
                            ref.read(privacyControllerProvider.notifier).setPrivate(v)
                                .catchError((_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(context.t('settings.privacy_update_failed'))),
                                );
                              }
                            }),
                          );
                        }
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmUsernameDialog(
      BuildContext context, {
        required String expectedUsername,
        required String title,
        required String description,
        required String confirmLabel,
        bool isDestructive = false,
      }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return _UsernameConfirmDialog(
          expectedUsername: expectedUsername,
          title: title,
          description: description,
          confirmLabel: confirmLabel,
          isDestructive: isDestructive,
        );
      },
    );

    return ok == true;
  }

  Future<void> _logoutNow(BuildContext context, WidgetRef ref) async {
    final storage = ref.read(tokenStorageProvider);
    final refresh = await storage.readRefreshToken();

    try {
      if (refresh != null && refresh.isNotEmpty) {
        final api = ref.read(authApiProvider);
        await api.logout(refreshToken: refresh);
      }
    } catch (_) {
      // ignore
    }

    await storage.clear();
    if (context.mounted) context.go(Routes.onboarding);
  }
}

class _SettingsShell extends StatelessWidget {
  final Widget child;
  const _SettingsShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // soft background blocks
        Positioned(
          left: -60,
          top: 80,
          child: _SoftBlob(width: 240, height: 180),
        ),
        Positioned(
          right: -40,
          top: 260,
          child: _SoftBlob(width: 220, height: 170),
        ),
        Positioned(
          left: -40,
          bottom: 40,
          child: _SoftBlob(width: 260, height: 180),
        ),
        child,
      ],
    );
  }
}

class _UsernameConfirmDialog extends StatefulWidget {
  const _UsernameConfirmDialog({
    required this.expectedUsername,
    required this.title,
    required this.description,
    required this.confirmLabel,
    this.isDestructive = false,
  });

  final String expectedUsername;
  final String title;
  final String description;
  final String confirmLabel;
  final bool isDestructive;

  @override
  State<_UsernameConfirmDialog> createState() => _UsernameConfirmDialogState();
}

class _UsernameConfirmDialogState extends State<_UsernameConfirmDialog> {
  late final TextEditingController c;
  String? errorText;

  @override
  void initState() {
    super.initState();
    c = TextEditingController();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isDestructive ? AppColors.chaputRed : AppColors.chaputBlack;
    final badgeBg = widget.isDestructive
        ? AppColors.chaputLightRed
        : AppColors.chaputBlack.withOpacity(0.06);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      backgroundColor: AppColors.chaputWhite.withOpacity(0.98),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.isDestructive ? Icons.warning_rounded : Icons.lock_outline,
                      color: accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.description,
                style: TextStyle(
                  color: AppColors.chaputBlack.withOpacity(0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: c,
                decoration: InputDecoration(
                  labelText: context.t('settings.username_label'),
                  hintText: context.t('settings.username_hint'),
                  errorText: errorText,
                  filled: true,
                  fillColor: AppColors.chaputBlack.withOpacity(0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.chaputBlack,
                        side: BorderSide(color: AppColors.chaputBlack.withOpacity(0.12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        context.t('common.cancel'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final input = c.text.trim();
                        if (input != widget.expectedUsername) {
                          setState(() => errorText = context.t('settings.username_mismatch'));
                          return;
                        }
                        Navigator.of(context).pop(true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: AppColors.chaputWhite,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        widget.confirmLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _SoftBlob extends StatelessWidget {
  final double width;
  final double height;
  const _SoftBlob({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: width,
          height: height,
          color: AppColors.chaputWhite.withOpacity(0.35),
        ),
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  final String title;
  final String subtitle;

  final String avatarUrl;
  final bool isDefaultAvatar;

  final VoidCallback onBack;
  final VoidCallback onOpenPhoto;
  final VoidCallback onOpenEmail;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenArchive;
  final VoidCallback onPauseAccount;
  final VoidCallback onCloseAccount;
  final VoidCallback onLogout;

  final bool privateAccountValue;
  final ValueChanged<bool>? onPrivateAccountChanged;
  final bool privateSwitchEnabled;

  const _SettingsContent({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.isDefaultAvatar,
    required this.onBack,
    required this.onOpenPhoto,
    required this.onOpenEmail,
    required this.onOpenPrivacy,
    required this.onOpenArchive,
    required this.onPauseAccount,
    required this.onCloseAccount,
    required this.onLogout,
    required this.privateAccountValue,
    required this.onPrivateAccountChanged,
    required this.privateSwitchEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // top bar
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left, size: 30),
            ),
            const Spacer(),
          ],
        ),

        const SizedBox(height: 8),

        // main white card
        Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT — 2/3
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // name + verified
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          // username
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.chaputBlack.withOpacity(0.55),
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            context.t('settings.manage_desc'),
                            style: TextStyle(
                              color: AppColors.chaputBlack.withOpacity(0.60),
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // RIGHT — 1/3
                    Expanded(
                      flex: 1,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: LayoutBuilder(
                          builder: (context, c) {
                            final size = c.maxWidth.clamp(72.0, 110.0);
                            return _AvatarWithRing(
                              avatarUrl: avatarUrl,
                              isDefaultAvatar: isDefaultAvatar,
                              onTap: onOpenPhoto,
                              size: size,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                Text(
                  context.t('settings.section_living_setup'),
                  style: TextStyle(
                    color: AppColors.chaputBlack.withOpacity(0.60),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),

                _SettingsRow(
                  icon: Icons.photo_camera_outlined,
                  title: context.t('settings.row_profile_photo'),
                  subtitle: context.t('settings.row_profile_photo_sub'),
                  onTap: onOpenPhoto,
                ),
                const SizedBox(height: 8),
                _SettingsRow(
                  icon: Icons.alternate_email,
                  title: context.t('settings.row_email'),
                  subtitle: context.t('settings.row_email_sub'),
                  onTap: onOpenEmail,
                ),
                const SizedBox(height: 8),
                _SettingsRow(
                  icon: Icons.block_outlined,
                  title: context.t('settings.row_blocks'),
                  subtitle: context.t('settings.row_blocks_sub'),
                  onTap: onOpenPrivacy,
                ),
                const SizedBox(height: 8),
                _SettingsRow(
                  icon: Icons.archive_outlined,
                  title: context.t('settings.row_archived'),
                  subtitle: context.t('settings.row_archived_sub'),
                  onTap: onOpenArchive,
                ),

                const SizedBox(height: 18),

                Text(
                  context.t('settings.section_account_control'),
                  style: TextStyle(
                    color: AppColors.chaputBlack.withOpacity(0.60),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),

                _PrivateAccountRow(
                  value: privateAccountValue,
                  enabled: privateSwitchEnabled,
                  onChanged: onPrivateAccountChanged,
                ),
                const SizedBox(height: 12),

                Wrap(
                  children: [
                    Text(
                      context.t('settings.pause_prefix'),
                      style: TextStyle(
                        color: AppColors.chaputBlack.withOpacity(0.60),
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        fontSize: 13,
                      ),
                    ),
                    InkWell(
                      onTap: onPauseAccount,
                      child: Text(
                        context.t('settings.pause_link'),
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          color: AppColors.chaputGolden,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ),
                    Text(
                      context.t('settings.close_prefix'),
                      style: TextStyle(
                        color: AppColors.chaputBlack.withOpacity(0.60),
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        fontSize: 13,
                      ),
                    ),
                    InkWell(
                      onTap: onCloseAccount,
                      child: Text(
                        context.t('settings.close_link'),
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          color: AppColors.chaputErrorRed,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                    ),
                    Text(
                      context.t('settings.close_suffix'),
                      style: TextStyle(
                        color: AppColors.chaputBlack.withOpacity(0.60),
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(
                      context.t('settings.logout_button'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.chaputBlack,
                      foregroundColor: AppColors.chaputWhite,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),

              ],
            ),
          ),
      ],
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Dot(active: true),
        const SizedBox(width: 4),
        _Dot(active: false),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? AppColors.chaputWhite : AppColors.chaputWhite.withOpacity(0.45),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _AvatarWithRing extends StatelessWidget {
  final String avatarUrl;
  final bool isDefaultAvatar;
  final VoidCallback onTap;
  final double size; // <— eklendi

  const _AvatarWithRing({
    required this.avatarUrl,
    required this.isDefaultAvatar,
    required this.onTap,
    this.size = 96, // <— default
  });

  @override
  Widget build(BuildContext context) {
    final ringPadding = 3.0;
    final inner = size - (ringPadding * 2);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.all(ringPadding),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.chaputPink, AppColors.chaputOrange],
              ),
            ),
            child: ClipOval(
              child: ChaputCircleAvatar(
                width: inner,
                height: inner,
                radius: 999,
                borderWidth: 0,
                bgColor: AppColors.chaputBlack,
                isDefaultAvatar: isDefaultAvatar,
                imageUrl: avatarUrl,
              ),
            ),
          ),
          Positioned(
            right: 2,
            bottom: -6,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.chaputWhite,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                      color: AppColors.chaputBlack.withOpacity(0.12),
                    ),
                  ],
                ),
                child: const Icon(Icons.settings, size: 18, color: AppColors.chaputBlack),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chaputWhite,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.chaputWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.chaputBlack.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.chaputBlack.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: AppColors.chaputBlack),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.chaputBlack.withOpacity(0.55),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.chaputBlack.withOpacity(0.35)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final lineColor = AppColors.chaputBlack.withOpacity(0.08);

    Widget listRow() {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.chaputWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.chaputBlack.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            ShimmerBlock(
              width: 34,
              height: 34,
              radius: 12,
              color: lineColor,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerLine(width: 160, height: 12),
                  SizedBox(height: 6),
                  ShimmerLine(width: 120, height: 10),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ShimmerLoading(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.chaputWhite,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.chaputBlack.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                ShimmerCircle(size: 52, color: lineColor),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerLine(width: 180, height: 14),
                      SizedBox(height: 6),
                      ShimmerLine(width: 120, height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          listRow(),
          listRow(),
          listRow(),
          listRow(),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.t('settings.load_failed'),
        style: TextStyle(color: AppColors.chaputBlack.withOpacity(0.65), fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PrivateAccountRow extends StatelessWidget {
  const _PrivateAccountRow({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final opacity = enabled ? 1.0 : 0.55;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: AppColors.chaputWhite,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.chaputBlack.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.chaputBlack.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: AppColors.chaputBlack,
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('settings.private_account_title'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.t('settings.private_account_subtitle'),
                      style: TextStyle(
                        color: AppColors.chaputBlack.withOpacity(0.55),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Switch
              Switch.adaptive(
                value: value,
                onChanged: enabled ? onChanged : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
