import 'package:flutter/material.dart';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/video/video_background.dart';
import '../../../../core/ui/widgets/glass_email_input.dart';

import '../../../../core/router/routes.dart';
import '../../data/internal_users_api.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const double _logoSize = 32; // UI'da görünen dp
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final email = _emailController.text.trim();

    final isValid = email.contains('@') && email.contains('.com');
    if (!isValid) {
      HapticFeedback.heavyImpact();
      return;
    }

    try {
      final api = ref.read(internalUsersApiProvider);
      final result = await api.lookupEmail(email);

      switch (result) {
        case EmailLookupResult.userNotFound:
        // user yok -> register
          context.pushReplacement(Routes.register);
          return;

        case EmailLookupResult.userFoundComplete:
        // user var -> login
          HapticFeedback.selectionClick(); // küçük onay
          context.pushReplacement(Routes.login);
          return;

        case EmailLookupResult.userFoundNeedsProfileSetup:
        // MVP: profil setup ekranı yoksa register'a yönlendir
          context.pushReplacement(Routes.register);
          return;
      }
    } on DioException {
      HapticFeedback.heavyImpact();
    } catch (_) {
      HapticFeedback.heavyImpact();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: VideoBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Sol üst logo
              Positioned(
                top: 12,
                left: 16,
                child: Hero(
                    tag: 'chaput_logo',
                    child: _Logo(size: _logoSize)
                ),
              ),

              // Alt email input + ok butonu
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  child: GlassEmailInput(
                    controller: _emailController,
                    hintText: 'Email',
                    onSubmit: _onSubmit,
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

class _Logo extends StatelessWidget {
  final double size;
  const _Logo({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/chaput_logo_256px_h.png',
        fit: BoxFit.contain,
      ),
    );
  }
}