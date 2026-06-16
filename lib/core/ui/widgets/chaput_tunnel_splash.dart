import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ChaputTunnelSplash extends StatelessWidget {
  const ChaputTunnelSplash({
    super.key,
    this.progress = 0,
    this.backgroundColor = const Color(0xFF000000),
    this.panelColor = const Color(0xFFF4F4F5),
    this.accentColor = const Color(0xFFF7DC10),
  });

  final double progress;
  final Color backgroundColor;
  final Color panelColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.expand(
        child: CustomPaint(
          isComplex: true,
          willChange: progress > 0,
          painter: _ChaputTunnelSplashPainter(
            progress: progress.clamp(0.0, 1.0),
            backgroundColor: backgroundColor,
            panelColor: panelColor,
            accentColor: accentColor,
          ),
        ),
      ),
    );
  }
}

class _ChaputTunnelSplashPainter extends CustomPainter {
  const _ChaputTunnelSplashPainter({
    required this.progress,
    required this.backgroundColor,
    required this.panelColor,
    required this.accentColor,
  });

  static const double _panelRatio = 545.38 / 852.246;
  static const double _accentRatio = 380.114 / 852.246;
  static const double _coreRatio = 181.794 / 852.246;

  static const double _panelRadiusRatio = 0.17;
  static const double _accentRadiusRatio = 0.18;
  static const double _coreRadiusRatio = 0.19;

  final double progress;
  final Color backgroundColor;
  final Color panelColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = backgroundColor);

    final center = rect.center;
    final baseExtent = math.min(size.shortestSide * 0.34, 150.0);
    final travel = Curves.easeInQuart.transform(progress) * 8.9;
    final fadeTail = Curves.easeIn.transform(
      ((progress - 0.90) / 0.10).clamp(0.0, 1.0),
    );

    if (progress <= 0.0001) {
      _drawPortal(canvas, center, baseExtent, 1.0);
      return;
    }

    final tunnelReveal = Curves.easeOutCubic.transform(
      (progress / 0.08).clamp(0.0, 1.0),
    );

    for (var index = 8; index >= 0; index--) {
      final depth = index + 1.0 - travel;
      if (depth <= 0.09) continue;

      final scale = math.pow(1 / depth, 1.52).toDouble();
      final extent = baseExtent * scale;
      if (extent <= 0.5) continue;

      var opacity = ((1 / (depth + 0.32)) * 0.92 * (1 - fadeTail)).clamp(
        0.0,
        1.0,
      );

      if (index != 0) {
        opacity *= tunnelReveal;
      }

      if (opacity <= 0.002) continue;

      _drawPortal(canvas, center, extent, opacity);
    }

    final lateTunnel = Curves.easeInCubic.transform(
      ((progress - 0.58) / 0.42).clamp(0.0, 1.0),
    );
    if (lateTunnel > 0) {
      final panelExtent = ui.lerpDouble(
        baseExtent * _panelRatio,
        size.height * 2.4,
        lateTunnel,
      )!;
      final accentExtent = ui.lerpDouble(
        baseExtent * _accentRatio,
        size.height * 2.05,
        lateTunnel,
      )!;
      final finalOpacity = (0.34 * (1 - fadeTail)).clamp(0.0, 0.34);

      _drawBand(
        canvas,
        _rrect(center, panelExtent, _panelRadiusRatio),
        _rrect(center, accentExtent, _accentRadiusRatio),
        panelColor.withValues(alpha: finalOpacity),
      );
      _drawBand(
        canvas,
        _rrect(center, accentExtent, _accentRadiusRatio),
        _rrect(
          center,
          ui.lerpDouble(
            baseExtent * _coreRatio,
            size.longestSide * 2.1,
            lateTunnel,
          )!,
          _coreRadiusRatio,
        ),
        accentColor.withValues(alpha: finalOpacity * 0.92),
      );
    }
  }

  void _drawPortal(
    Canvas canvas,
    Offset center,
    double extent,
    double opacity,
  ) {
    final panelOuter = _rrect(center, extent * _panelRatio, _panelRadiusRatio);
    final accentOuter = _rrect(
      center,
      extent * _accentRatio,
      _accentRadiusRatio,
    );
    final coreOuter = _rrect(center, extent * _coreRatio, _coreRadiusRatio);

    _drawBand(
      canvas,
      panelOuter,
      accentOuter,
      panelColor.withValues(alpha: opacity),
    );
    _drawBand(
      canvas,
      accentOuter,
      coreOuter,
      accentColor.withValues(alpha: opacity * 0.96),
    );
  }

  void _drawBand(Canvas canvas, RRect outer, RRect inner, Color color) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(outer)
      ..addRRect(inner);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..isAntiAlias = true
        ..color = color,
    );
  }

  RRect _rrect(Offset center, double extent, double radiusRatio) {
    return RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: extent, height: extent),
      Radius.circular(extent * radiusRatio),
    );
  }

  @override
  bool shouldRepaint(covariant _ChaputTunnelSplashPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.panelColor != panelColor ||
        oldDelegate.accentColor != accentColor;
  }
}
