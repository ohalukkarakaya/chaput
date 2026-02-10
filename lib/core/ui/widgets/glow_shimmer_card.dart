import 'dart:ui';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// ✅ Glass + shimmer border + glow
/// ✅ Shimmer döngüsü bitince X ms bekler, sonra yeniden başlar.
class GlowShimmerCard extends StatefulWidget {
  const GlowShimmerCard({
    super.key,
    required this.child,

    // shape
    this.radius = 22,
    this.padding = const EdgeInsets.all(16),

    // glass
    this.enableBlur = true,
    this.blurSigma = 16,
    this.glassColor = AppColors.chaputWhite,
    this.glassOpacity = 0.18,

    // shimmer/border
    this.borderWidth = 1.8,
    this.duration = const Duration(milliseconds: 1900),

    /// ✅ NEW: animasyon bittiğinde bekleme (min 500ms istemiştin)
    this.gap = const Duration(milliseconds: 2500),

    // glow
    this.glowSigma = 22,
    this.glowOpacity = 0.55,

    this.enableInnerShimmer = true,
    this.innerShimmerOpacity = 0.10,
    this.innerShimmerSoftness = 0.55,
  });

  final Widget child;

  final double radius;
  final EdgeInsets padding;

  final bool enableBlur;
  final double blurSigma;
  final Color glassColor;
  final double glassOpacity;

  final double borderWidth;
  final Duration duration;

  /// ✅ NEW
  final Duration gap;

  final double glowSigma;
  final double glowOpacity;

  final bool enableInnerShimmer;
  final double innerShimmerOpacity; // 0.06 - 0.14 güzel aralık
  final double innerShimmerSoftness; // 0.35 - 0.75

  @override
  State<GlowShimmerCard> createState() => _GlowShimmerCardState();
}

class _GlowShimmerCardState extends State<GlowShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  Duration get _cycleDuration => widget.duration + widget.gap;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _cycleDuration)..repeat();
  }

  @override
  void didUpdateWidget(covariant GlowShimmerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration || oldWidget.gap != widget.gap) {
      _c
        ..duration = _cycleDuration
        ..repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.radius);

    const shimmerColors = [
      AppColors.chaputTransparent,
      AppColors.chaputViolet,
      AppColors.chaputDeepPurple,
      AppColors.chaputMagenta,
      AppColors.chaputViolet,
      AppColors.chaputTransparent,
    ];

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final totalMs = _cycleDuration.inMilliseconds.toDouble().clamp(1, double.infinity);
        final activeMs = widget.duration.inMilliseconds.toDouble().clamp(1, totalMs);

        // 0..totalMs
        final elapsedMs = _c.value * totalMs;

        // ✅ animasyon kısmındaysak akar, gap kısmındaysak donar
        final double t = (elapsedMs <= activeMs)
            ? (elapsedMs / activeMs) // 0..1
            : 1.0; // gap boyunca son pozisyonda sabit

        // İstersen bu range'i daha sakin yapmak için (-0.85/1.7) kullanabilirsin.
        final begin = Alignment(-1.2 + 2.4 * t, -1);
        final end = Alignment(1.2 + 2.4 * t, 1);

        final gradient = LinearGradient(
          begin: begin,
          end: end,
          colors: shimmerColors,
          stops: const [0.00, 0.20, 0.45, 0.60, 0.80, 1.00],
        );

        final body = Container(
          decoration: BoxDecoration(
            borderRadius: r,
            color: widget.glassColor.withOpacity(widget.glassOpacity),
          ),
          child: Stack(
            children: [
              Padding(
                padding: widget.padding,
                child: widget.child,
              ),

              // ✅ INNER SHIMMER
              if (widget.enableInnerShimmer)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: widget.innerShimmerOpacity,
                      child: ShaderMask(
                        blendMode: BlendMode.srcATop,
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            begin: begin,
                            end: end,
                            colors: shimmerColors.map((c) {
                              return c.withOpacity(
                                (c.opacity) * widget.innerShimmerSoftness,
                              );
                            }).toList(),
                            stops: const [0.00, 0.20, 0.45, 0.60, 0.80, 1.00],
                          ).createShader(bounds);
                        },
                        child: Container(color: AppColors.chaputWhite),
                      ),
                    ),
                  ),
                ),
            ],
          ),
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

            // ✅ Glass body (blur opsiyonel)
            ClipRRect(
              borderRadius: r,
              child: widget.enableBlur
                  ? BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: widget.blurSigma,
                  sigmaY: widget.blurSigma,
                ),
                child: body,
              )
                  : body,
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

    final rrect = RRect.fromRectAndRadius(
      rect.deflate(stroke / 2),
      Radius.circular(radius),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..shader = gradient.createShader(rect)
      ..color = AppColors.chaputWhite.withOpacity(glowOpacity);

    if (blurSigma > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
    }

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _BorderPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.stroke != stroke ||
        oldDelegate.blurSigma != blurSigma ||
        oldDelegate.glowOpacity != glowOpacity ||
        oldDelegate.gradient != gradient ||
        oldDelegate.isGlow != isGlow;
  }
}
