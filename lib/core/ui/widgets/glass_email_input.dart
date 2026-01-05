import 'dart:ui';
import 'package:flutter/material.dart';

class GlassEmailInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Future<void> Function() onSubmit;
  final double radius;

  const GlassEmailInput({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.hintText = 'email',
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
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
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
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      debugPrint('⌨️ TextField submitted');
                      await onSubmit();
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: hintText,
                      hintStyle: const TextStyle(color: Colors.white54),
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
        color: Colors.transparent,
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
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: Center(
                child: Icon(icon, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}