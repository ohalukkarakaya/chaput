import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:flutter/material.dart';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/storage/secure_storage_provider.dart';
import '../../../../core/ui/video/video_background.dart';
import '../../../../core/ui/widgets/avatar_scatter_row.dart';
import '../../../../core/ui/widgets/curated_avatar_strip.dart';
import '../../../../core/ui/widgets/email_cta_form.dart';


import '../../../../core/router/routes.dart';
import '../../../../core/ui/widgets/fading_video_header.dart';
import '../../data/internal_users_api.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
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
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: VideoBackground(
        overlayOpacity: 0.45,
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // ✅ Alt içerik (metin + form) her zaman en altta
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + keyboard, // ✅ klavye açılınca yukarı taşır
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // ✅ sadece ihtiyacı kadar yer kaplasın
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Hoş Geldin 👋',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Gecikme, arkadaşların seni bekliyor!',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.80),
                            fontSize: 16,
                            height: 1.35,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 18),

                        SafeArea(
                          bottom: true,
                          child: EmailCtaForm(
                            controller: _emailController,
                            hint: 'Email',
                            buttonText: 'Continue',
                            onSubmit: _onSubmit,
                          ),
                        ),
                      ],
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

/// Görselin altı asla kesilmesin:
/// - BoxFit.cover kullanıyoruz
/// - Alignment.bottomCenter ile altı sabitliyoruz
/// Böylece taşan kısım ÜSTTEN kırpılır.
class _TopCroppedHeaderImage extends StatelessWidget {
  final String assetPath;

  const _TopCroppedHeaderImage({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Image.asset(
          assetPath,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
        ),
      ),
    );
  }
}