import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/constants/app_colors.dart';

class TreeSilhouetteShimmer extends StatelessWidget {
  final double size;

  const TreeSilhouetteShimmer({
    super.key,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.chaputWhite.withOpacity(0.18),
      highlightColor: AppColors.chaputWhite.withOpacity(0.6),
      period: const Duration(milliseconds: 1200),
      child: CustomPaint(
        size: Size.square(size),
        painter: _TreeSilhouettePainter(
          color: AppColors.chaputWhite.withOpacity(0.7),
        ),
      ),
    );
  }
}

class _TreeSilhouettePainter extends CustomPainter {
  final Color color;

  const _TreeSilhouettePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final minSide = min(w, h);

    // Canopy
    final canopyR = minSide * 0.33;
    canvas.drawCircle(Offset(w * 0.5, h * 0.33), canopyR, paint);
    canvas.drawCircle(Offset(w * 0.32, h * 0.38), canopyR * 0.75, paint);
    canvas.drawCircle(Offset(w * 0.68, h * 0.38), canopyR * 0.75, paint);

    // Trunk
    final trunkWidth = w * 0.18;
    final trunkHeight = h * 0.4;
    final trunkRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.52, h * 0.74),
        width: trunkWidth,
        height: trunkHeight,
      ),
      Radius.circular(trunkWidth * 0.45),
    );
    canvas.drawRRect(trunkRect, paint);

    // Subtle branch
    final branchPath = Path()
      ..moveTo(w * 0.52, h * 0.6)
      ..quadraticBezierTo(w * 0.7, h * 0.55, w * 0.78, h * 0.5)
      ..lineTo(w * 0.74, h * 0.54)
      ..quadraticBezierTo(w * 0.64, h * 0.6, w * 0.52, h * 0.66)
      ..close();
    canvas.drawPath(branchPath, paint);
  }

  @override
  bool shouldRepaint(covariant _TreeSilhouettePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
