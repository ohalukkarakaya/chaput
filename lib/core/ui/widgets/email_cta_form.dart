import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../i18n/app_localizations.dart';
import 'glass_cta_button.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

class EmailCtaForm extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final String? buttonText;
  final bool isLoading;
  final Future<void> Function() onSubmit;
  final bool enabled;

  const EmailCtaForm({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.hint,
    this.buttonText,
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
                color: AppColors.chaputWhite.withOpacity(0.72),
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(
                  color: AppColors.chaputWhite.withOpacity(0.55),
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
                  hintText: hint ?? context.t('common.email'),
                  hintStyle: TextStyle(
                    color: AppColors.chaputBlack.withOpacity(0.45),
                  ),
                  prefixIcon: Icon(
                    Icons.mail_outline,
                    color: AppColors.chaputBlack.withOpacity(0.55),
                  ),
                  prefixIconConstraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                style: const TextStyle(
                  color: AppColors.chaputBlack,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        GlassCtaButton(
          text: buttonText ?? context.t('common.continue'),
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
