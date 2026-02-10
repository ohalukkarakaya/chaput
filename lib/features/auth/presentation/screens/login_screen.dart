import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/video/video_background.dart';
import '../../application/auth_controller.dart';
import '../widgets/auth_text_field.dart';
import 'package:chaput/core/constants/app_colors.dart';
import 'package:chaput/core/i18n/app_localizations.dart';


class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _u = TextEditingController();
  final _p = TextEditingController();

  @override
  void dispose() {
    _u.dispose();
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (prev, next) {
      next.whenOrNull(
        error: (e, st) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${context.t('auth.login_failed')}: $e')),
          );
        },
      );
    });

    return Scaffold(
      body: VideoBackground(
        assetPath: 'assets/videos/chaput_bg.M4V',
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Text(
                  context.t('app.name'),
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: AppColors.chaputWhite),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  context.t('auth.tagline'),
                  style: const TextStyle(color: AppColors.chaputWhite70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // login form burada
              ],
            ),
          ),
        ),
      ),
    );

  }
}
