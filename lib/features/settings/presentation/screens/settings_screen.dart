import 'dart:ui';

import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:chaput/features/settings/presentation/screens/photo_settings_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/secure_storage_provider.dart';
import '../../../auth/data/auth_api.dart';
import '../../../helpers/string_helpers/format_full_name.dart';
import '../../../me/application/me_controller.dart';
import 'archive_chaputs_screen.dart';
import 'blocked_restricted_screen.dart';
import 'email_change_screen.dart';

import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:chaput/core/router/routes.dart';

final privateAccountSwitchProvider = StateProvider.autoDispose<bool>((ref) => false);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(meControllerProvider);

    return Scaffold(
      backgroundColor: const Color(0xffEEF2F6),
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
                    final username = user?.username ?? '—';
                    final fullName = user?.fullName ?? '—';
                
                    final defaultAvatar = user?.defaultAvatar;
                    final profilePhotoUrl = user?.profilePhotoUrl;

                    final isPrivateUi = ref.watch(privateAccountSwitchProvider);

                    return _SettingsShell(
                      child: _SettingsContent(
                        title: formatFullName(fullName),
                        subtitle: '@$username',
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
                        onPauseAccount: () {},
                        onCloseAccount: () {},
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

                        privateAccountValue: isPrivateUi,
                        onPrivateAccountChanged: (v) {
                          ref.read(privateAccountSwitchProvider.notifier).state = v;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Private account: $v (UI only)')),
                          );
                        },

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
          color: Colors.white.withOpacity(0.35),
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
  final ValueChanged<bool> onPrivateAccountChanged;

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
                              color: Colors.black.withOpacity(0.55),
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'Manage your account settings here. You can update your profile, privacy preferences, and archived items anytime.',
                            style: TextStyle(
                              color: Colors.black.withOpacity(0.60),
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
                  'Living setup',
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.60),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),

                _SettingsRow(
                  icon: Icons.photo_camera_outlined,
                  title: 'Profile photo',
                  subtitle: 'Change or remove your photo',
                  onTap: onOpenPhoto,
                ),
                const SizedBox(height: 8),
                _SettingsRow(
                  icon: Icons.alternate_email,
                  title: 'Email',
                  subtitle: 'Change your email address',
                  onTap: onOpenEmail,
                ),
                const SizedBox(height: 8),
                _SettingsRow(
                  icon: Icons.block_outlined,
                  title: 'Blocks & restrictions',
                  subtitle: 'See blocked/restricted users',
                  onTap: onOpenPrivacy,
                ),
                const SizedBox(height: 8),
                _SettingsRow(
                  icon: Icons.archive_outlined,
                  title: 'Archived chaputs',
                  subtitle: 'Revive from archive',
                  onTap: onOpenArchive,
                ),

                const SizedBox(height: 18),

                Text(
                  'Account Control',
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.60),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),

                _PrivateAccountRow(
                  value: privateAccountValue,          // şimdilik hep kapalı
                  enabled: true,        // şimdilik disabled (kontroller sonra)
                  onChanged: onPrivateAccountChanged
                ),
                const SizedBox(height: 12),

                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Colors.black.withOpacity(0.60),
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      fontSize: 13,
                    ),
                    children: [
                      const TextSpan(text: 'You can pause your account if you need a break '),

                      TextSpan(
                        text: 'from here',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          color: Color(0xffF4B400), // sarı
                          fontWeight: FontWeight.w800,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = onPauseAccount,
                      ),

                      const TextSpan(text: ', or close it permanently '),

                      TextSpan(
                        text: 'from here',
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                          color: Color(0xffE53935), // kırmızı
                          fontWeight: FontWeight.w800,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = onCloseAccount,
                      ),

                      const TextSpan(text: '.'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text(
                      'Logout Safely',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
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
        color: active ? Colors.white : Colors.white.withOpacity(0.45),
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
                colors: [Color(0xffFF4D8D), Color(0xffFF8A00)],
              ),
            ),
            child: ClipOval(
              child: ChaputCircleAvatar(
                width: inner,
                height: inner,
                radius: 999,
                borderWidth: 0,
                bgColor: Colors.black,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                      color: Colors.black.withOpacity(0.12),
                    ),
                  ],
                ),
                child: const Icon(Icons.settings, size: 18, color: Colors.black),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: Colors.black),
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
                        color: Colors.black.withOpacity(0.55),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.black.withOpacity(0.35)),
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
    return const Center(
      child: SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2),
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
        'Could not load settings',
        style: TextStyle(color: Colors.black.withOpacity(0.65), fontWeight: FontWeight.w700),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Private account',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Only approved followers can see your content',
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.55),
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