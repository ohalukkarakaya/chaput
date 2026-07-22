import 'dart:math' as math;

import 'package:flutter/material.dart';

class EmptyStateIllustration extends StatelessWidget {
  const EmptyStateIllustration({
    super.key,
    required this.assetPath,
    this.minWidth = 150,
    this.maxWidth = 230,
  });

  final String assetPath;
  final double minWidth;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screenWidth;
        final targetWidth = math.min(
          maxWidth,
          math.max(minWidth, screenWidth * 0.52),
        );
        final width = math.min(
          targetWidth,
          math.max(96.0, availableWidth - 32),
        );

        return Center(
          child: Image.asset(
            assetPath,
            width: width,
            height: width,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            excludeFromSemantics: true,
          ),
        );
      },
    );
  }
}
