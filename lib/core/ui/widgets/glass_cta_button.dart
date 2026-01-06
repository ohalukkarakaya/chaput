import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCtaButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final bool enabled;
  final double height;
  final double radius;
  final Future<void> Function() onTap;

  const GlassCtaButton({
    super.key,
    required this.text,
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
    this.height = 56,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !isLoading;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canTap ? () async => onTap() : null,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(canTap ? 0.50 : 0.32),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: isLoading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}