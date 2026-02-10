import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:chaput/core/constants/app_colors.dart';

class BlackGlass extends StatelessWidget {
  const BlackGlass({
    super.key,
    required this.child,
    this.radius = 18,
    this.blur = 12,
    this.opacity = 0.55,
    this.borderOpacity = 0.12,
    this.borderWidth = 1,
    this.clipOval = false,
  });

  final Widget child;
  final double radius;
  final double blur;
  final double opacity;
  final double borderOpacity;
  final double borderWidth;
  final bool clipOval;

  @override
  Widget build(BuildContext context) {
    final box = BoxDecoration(
      color: AppColors.chaputBlack.withOpacity(opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: AppColors.chaputWhite.withOpacity(borderOpacity),
        width: borderWidth,
      ),
    );

    final content = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: DecoratedBox(decoration: box, child: child),
    );

    if (clipOval) {
      return ClipOval(child: content);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: content,
    );
  }
}
