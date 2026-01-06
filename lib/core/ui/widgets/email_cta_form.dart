import 'dart:ui';

import 'package:flutter/material.dart';

import 'glass_cta_button.dart';

class EmailCtaForm extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String buttonText;
  final bool isLoading;
  final Future<void> Function() onSubmit;
  final bool enabled;

  const EmailCtaForm({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.label = 'Email',
    this.hint = 'email',
    this.buttonText = 'Continue',
    this.isLoading = false,
    this.enabled = true,
  });

  static const double _radius = 18;
  static const double _fieldHeight = 56;
  static const double _buttonHeight = 56;

  @override
  Widget build(BuildContext context) {
    final canTap = !isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        // ✅ White input
        ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              height: _fieldHeight,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // 👇 beyaz cam hissi
                color: Colors.white.withOpacity(0.72),
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(
                  color: Colors.white.withOpacity(0.55),
                ),
              ),
              child: TextField(
                controller: controller,
                enabled: enabled,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) async {
                  if (!enabled) return;
                  await onSubmit();
                },
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: Colors.black.withOpacity(0.45),
                  ),
                  prefixIcon: Icon(
                    Icons.mail_outline,
                    color: Colors.black.withOpacity(0.55),
                  ),
                  prefixIconConstraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        GlassCtaButton(
          text: buttonText,
          isLoading: isLoading,
          enabled: !isLoading,
          height: _buttonHeight,
          radius: _radius,
          onTap: onSubmit,
        ),
      ],
    );
  }
}