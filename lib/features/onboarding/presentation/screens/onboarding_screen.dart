import 'package:flutter/material.dart';

import '../../../../core/ui/video/video_background.dart';
import '../../../../core/ui/widgets/glass_email_input.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const double _logoSize = 32; // UI'da görünen dp
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final email = _emailController.text.trim();
    // TODO: email validate + next step (login/signup)
    debugPrint('Email submitted: $email');
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