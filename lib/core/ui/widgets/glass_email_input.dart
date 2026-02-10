import 'dart:ui';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../i18n/app_localizations.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

class GlassEmailInput extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final Future<void> Function() onSubmit;
  final double radius;

  const GlassEmailInput({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.hintText,
    this.radius = 18,
  });

  static const double _fieldHeight = 44; // input + button aynı yükseklik

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.chaputBlack.withOpacity(0.35),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.chaputWhite.withOpacity(0.14)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: _fieldHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(color: AppColors.chaputWhite),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      debugPrint('⌨️ TextField submitted');
                      await onSubmit();
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: hintText ?? context.t('common.email'),
                      hintStyle: const TextStyle(color: AppColors.chaputWhite54),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GlassSquareIconButton(
                size: _fieldHeight,
                radius: (radius - 4).clamp(0, 999),
                icon: Icons.arrow_forward_ios_rounded,
                onTap: () => onSubmit(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassSquareIconButton extends StatelessWidget {
  final double size;
  final double radius;
  final IconData icon;
  final Future<void> Function() onTap;

  const GlassSquareIconButton({
    super.key,
    required this.size,
    required this.radius,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Material(
        color: AppColors.chaputTransparent,
        child: InkWell(
          onTap: () async {
            debugPrint('➡️ GlassArrowButton tapped'); // DEBUG
            await onTap();
          },
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppColors.chaputBlack.withOpacity(0.45),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: AppColors.chaputWhite.withOpacity(0.18)),
              ),
              child: Center(
                child: Icon(icon, size: 16, color: AppColors.chaputWhite),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
