import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../constants/app_colors.dart';

class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({
    super.key,
    required this.child,
    this.enabled = true,
    this.baseColor,
    this.highlightColor,
    this.period = const Duration(milliseconds: 1600),
    this.direction = ShimmerDirection.ltr,
  });

  final Widget child;
  final bool enabled;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration period;
  final ShimmerDirection direction;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    final resolvedBase = baseColor ?? AppColors.chaputBlack.withOpacity(0.08);
    final resolvedHighlight =
        highlightColor ?? AppColors.chaputWhite.withOpacity(0.65);

    return Shimmer.fromColors(
      baseColor: resolvedBase,
      highlightColor: resolvedHighlight,
      period: period,
      direction: direction,
      child: child,
    );
  }
}

class ShimmerBlock extends StatelessWidget {
  const ShimmerBlock({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
    this.color,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double height;
  final double radius;
  final Color? color;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? AppColors.chaputBlack.withOpacity(0.08),
          shape: shape,
          borderRadius: shape == BoxShape.circle
              ? null
              : BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ShimmerLine extends StatelessWidget {
  const ShimmerLine({
    super.key,
    this.width,
    this.height = 10,
    this.radius = 999,
    this.color,
  });

  final double? width;
  final double height;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ShimmerBlock(
        width: width,
        height: height,
        radius: radius,
        color: color,
      ),
    );
  }
}

class ShimmerCircle extends StatelessWidget {
  const ShimmerCircle({
    super.key,
    required this.size,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ShimmerBlock(
      width: size,
      height: size,
      shape: BoxShape.circle,
      color: color,
    );
  }
}

class ShimmerUserCard extends StatelessWidget {
  const ShimmerUserCard({
    super.key,
    this.avatarSize = 42,
    this.padding = const EdgeInsets.all(12),
    this.radius = 16,
    this.backgroundColor,
    this.line1Factor = 0.62,
    this.line2Factor = 0.42,
    this.showTrailing = false,
    this.trailingWidth = 56,
    this.trailingHeight = 22,
  });

  final double avatarSize;
  final EdgeInsets padding;
  final double radius;
  final Color? backgroundColor;
  final double line1Factor;
  final double line2Factor;
  final bool showTrailing;
  final double trailingWidth;
  final double trailingHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.chaputWhite.withOpacity(0.92),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        children: [
          ShimmerCircle(size: avatarSize),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: line1Factor,
                  child: const ShimmerLine(height: 12),
                ),
                const SizedBox(height: 6),
                FractionallySizedBox(
                  widthFactor: line2Factor,
                  child: const ShimmerLine(height: 10),
                ),
              ],
            ),
          ),
          if (showTrailing) ...[
            const SizedBox(width: 12),
            ShimmerBlock(
              width: trailingWidth,
              height: trailingHeight,
              radius: 999,
              color: AppColors.chaputBlack.withOpacity(0.12),
            ),
          ],
        ],
      ),
    );
  }
}
