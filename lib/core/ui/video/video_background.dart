import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:chaput/core/constants/app_colors.dart';

class VideoBackground extends StatefulWidget {
  final Widget child;
  final double overlayOpacity;
  // assetPath kept for API compatibility; video is no longer used.
  final String? assetPath;

  const VideoBackground({
    super.key,
    required this.child,
    this.assetPath,
    this.overlayOpacity = 0.45,
  });

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Blob> _blobs;
  Size _lastSize = Size.zero;
  List<Offset> _grain = const [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();

    _blobs = [
      _Blob(
        color: const Color(0xFF0B1E40),
        center: const Offset(0.15, 0.22),
        radius: 0.58,
        amplitude: const Offset(0.08, 0.12),
        speed: 0.65,
        phase: 0.0,
      ),
      _Blob(
        color: const Color(0xFF1B3F7A),
        center: const Offset(0.82, 0.18),
        radius: 0.46,
        amplitude: const Offset(0.12, 0.08),
        speed: 0.55,
        phase: 1.6,
      ),
      _Blob(
        color: const Color(0xFF0E2C66),
        center: const Offset(0.58, 0.78),
        radius: 0.62,
        amplitude: const Offset(0.1, 0.1),
        speed: 0.45,
        phase: 2.7,
      ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _ensureGrain(size);

        return Stack(
          fit: StackFit.expand,
          children: [
            // ✅ Arka plan blob animasyonu (insets'ten bağımsız)
            MediaQuery(
              data: mq.copyWith(
                viewInsets: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
              ),
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _BlobPainter(
                        t: _controller.value,
                        blobs: _blobs,
                      ),
                      isComplex: true,
                      willChange: true,
                    );
                  },
                ),
              ),
            ),

            // ✅ Frosted glass blur (arkaplana) + hafif tint
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      color: AppColors.chaputBlack.withOpacity(widget.overlayOpacity),
                    ),
                  ),
                ),
              ),
            ),

            // ✅ Grain overlay (statik, hafif)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: CustomPaint(
                  painter: _GrainPainter(points: _grain),
                  isComplex: false,
                  willChange: false,
                ),
              ),
            ),

            // ✅ Üst içerik normal MediaQuery ile kalsın (klavye vs. burada yönetilir)
            widget.child,
          ],
        );
      },
    );
  }

  void _ensureGrain(Size size) {
    if (size == _lastSize && _grain.isNotEmpty) return;
    _lastSize = size;
    final rand = Random(7);
    final area = size.width * size.height;
    final count = (area / 900).clamp(420, 1400).round();
    _grain = List.generate(
      count,
      (_) => Offset(
        rand.nextDouble() * size.width,
        rand.nextDouble() * size.height,
      ),
    );
  }
}

class _Blob {
  final Color color;
  final Offset center;
  final double radius;
  final Offset amplitude;
  final double speed;
  final double phase;

  const _Blob({
    required this.color,
    required this.center,
    required this.radius,
    required this.amplitude,
    required this.speed,
    required this.phase,
  });
}

class _BlobPainter extends CustomPainter {
  final double t;
  final List<_Blob> blobs;

  const _BlobPainter({
    required this.t,
    required this.blobs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    final time = t * 2 * pi;

    for (final blob in blobs) {
      final dx = (blob.center.dx + blob.amplitude.dx * sin(time * blob.speed + blob.phase)) * size.width;
      final dy = (blob.center.dy + blob.amplitude.dy * cos(time * blob.speed + blob.phase)) * size.height;
      final radius = blob.radius * shortest;
      final blurSigma = radius * 0.35;

      final paint = Paint()
        ..color = blob.color.withOpacity(0.82)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.blobs != blobs;
  }
}

class _GrainPainter extends CustomPainter {
  final List<Offset> points;

  const _GrainPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF).withOpacity(0.05)
      ..strokeWidth = 1;

    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
