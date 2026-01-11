import 'dart:ui';
import 'package:flutter/material.dart';

/// ✅ Glass + shimmer border + glow
/// Kullanım:
/// GlowShimmerCard(
///   radius: 22,
///   child: ...
/// )
class GlowShimmerCard extends StatefulWidget {
  const GlowShimmerCard({
    super.key,
    required this.child,

    // shape
    this.radius = 22,
    this.padding = const EdgeInsets.all(16),

    // glass
    this.blurSigma = 16,
    this.glassColor = Colors.white,
    this.glassOpacity = 0.18,

    // shimmer/border
    this.borderWidth = 1.8,
    this.duration = const Duration(milliseconds: 1400),

    // glow
    this.glowSigma = 22,
    this.glowOpacity = 0.55,
  });

  final Widget child;

  final double radius;
  final EdgeInsets padding;

  final double blurSigma;
  final Color glassColor;
  final double glassOpacity;

  final double borderWidth;
  final Duration duration;

  final double glowSigma;
  final double glowOpacity;

  @override
  State<GlowShimmerCard> createState() => _GlowShimmerCardState();
}

class _GlowShimmerCardState extends State<GlowShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.radius);

    // Shimmer gradient renkleri (mor/pembe neon)
    const shimmerColors = [
      Color(0x00FFFFFF),
      Color(0xFFB86BFF),
      Color(0xFF7C3AED),
      Color(0xFFFF4DFF),
      Color(0xFFB86BFF),
      Color(0x00FFFFFF),
    ];

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        // 0..1
        final t = _c.value;

        // shimmer'ı sağa kaydır
        final begin = Alignment(-1.2 + 2.4 * t, -1);
        final end = Alignment(1.2 + 2.4 * t, 1);

        final gradient = LinearGradient(
          begin: begin,
          end: end,
          colors: shimmerColors,
          stops: const [0.00, 0.20, 0.45, 0.60, 0.80, 1.00],
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // ✅ Glow (dış ışık)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BorderPainter(
                    radius: widget.radius,
                    stroke: widget.borderWidth,
                    gradient: gradient,
                    blurSigma: widget.glowSigma,
                    glowOpacity: widget.glowOpacity,
                    isGlow: true,
                  ),
                ),
              ),
            ),

            // ✅ Glass body (blur)
            ClipRRect(
              borderRadius: r,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: widget.blurSigma,
                  sigmaY: widget.blurSigma,
                ),
                child: Container(
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    borderRadius: r,
                    color: widget.glassColor.withOpacity(widget.glassOpacity),
                  ),
                  child: widget.child,
                ),
              ),
            ),

            // ✅ Sharp shimmer border
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _BorderPainter(
                    radius: widget.radius,
                    stroke: widget.borderWidth,
                    gradient: gradient,
                    blurSigma: 0,
                    glowOpacity: 1.0,
                    isGlow: false,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BorderPainter extends CustomPainter {
  _BorderPainter({
    required this.radius,
    required this.stroke,
    required this.gradient,
    required this.blurSigma,
    required this.glowOpacity,
    required this.isGlow,
  });

  final double radius;
  final double stroke;
  final Gradient gradient;
  final double blurSigma;
  final double glowOpacity;
  final bool isGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // border'ı içeriden çiz (taşma azalsın)
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(stroke / 2),
      Radius.circular(radius),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..shader = gradient.createShader(rect)
      ..color = Colors.white.withOpacity(glowOpacity);

    if (blurSigma > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
    }

    // Glow daha “yumuşak” dursun diye bir tık daha transparan
    if (isGlow) {
      paint.color = Colors.white.withOpacity(glowOpacity);
    }

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _BorderPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.stroke != stroke ||
        oldDelegate.blurSigma != blurSigma ||
        oldDelegate.glowOpacity != glowOpacity ||
        oldDelegate.gradient != gradient;
  }
}
