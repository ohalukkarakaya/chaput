import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A paint-only overlay: it never intercepts tree gestures or rebuilds chat.
class TreeUnlockMist extends StatelessWidget {
  const TreeUnlockMist({super.key, required this.progress});

  final ValueListenable<double> progress;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _MistPainter(progress)),
      ),
    );
  }
}

class _MistPainter extends CustomPainter {
  _MistPainter(this.progress) : super(repaint: progress);

  final ValueListenable<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1 || size.isEmpty) return;
    final spread = Curves.easeOutCubic.transform(t);
    final veil = math.pow(math.sin(t * math.pi), 0.7).toDouble();
    final center = Offset(size.width * 0.5, size.height * 0.46);
    final unit = math.min(size.width, size.height);
    final paint = Paint();

    // Soft overlapping wisps drift outward and upward as the color returns.
    // Radial gradients keep the edges soft without a full-screen blur layer.
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi * 2 / 12;
      final drift = unit * (0.13 + spread * 0.42);
      final position =
          center +
          Offset(
            math.cos(angle + t * 0.25) * drift,
            math.sin(angle) * drift * 0.65 - unit * spread * 0.22,
          );
      final radius = unit * (0.23 + spread * 0.09);
      final color = i.isEven
          ? const Color(0xFF323B42)
          : const Color(0xFFCCDAD6);
      paint.shader = RadialGradient(
        colors: [
          color.withValues(alpha: veil * (1 - t) * 0.3),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: position, radius: radius));
      canvas.drawCircle(position, radius, paint);
    }

    // A few warm motes emerge from the clearing mist, then fade away.
    paint.shader = null;
    final glow = math.sin(math.pi * t) * t * 0.85;
    for (var i = 0; i < 14; i++) {
      final angle = i * 2.39996;
      final distance = unit * (0.1 + (i % 5) * 0.035 + spread * 0.22);
      final position =
          center +
          Offset(
            math.cos(angle) * distance,
            math.sin(angle) * distance * 0.8 - unit * t * 0.25,
          );
      final radius = 1.2 + (i % 3) * 0.5;
      paint.color = const Color(0xFFFFE5A3).withValues(alpha: glow * 0.15);
      canvas.drawCircle(position, radius * 3.5, paint);
      paint.color = const Color(0xFFFFF2CE).withValues(alpha: glow);
      canvas.drawCircle(position, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MistPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
