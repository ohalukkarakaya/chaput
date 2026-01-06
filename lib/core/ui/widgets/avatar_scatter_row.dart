import 'dart:math';
import 'package:flutter/material.dart';

import '../chaput_circle_avatar/chaput_circle_avatar.dart';

class AvatarScatterRow extends StatelessWidget {
  final List<AvatarScatterItem> items;

  /// Bu seed aynı kaldıkça aynı dizilim oluşur (random ama sabit).
  final int seed;

  /// Widget yüksekliği
  final double height;

  /// Avatarların ekrana "yayılma" genişliği (Stack genişliği)
  /// null ise parent width kullanır.
  final double? width;

  /// Genel yoğunluk / spacing hissi
  final double horizontalPadding;

  const AvatarScatterRow({
    super.key,
    required this.items,
    required this.seed,
    this.height = 120,
    this.width,
    this.horizontalPadding = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width ?? double.infinity,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth.isFinite ? c.maxWidth : (width ?? 360.0);
          final rng = Random(seed);

          // avatarlar soldan sağa yayılacak.
          // basitçe: eşit aralık + ufak jitter.
          final usableW = max(0.0, w - horizontalPadding * 2);
          final step = items.isEmpty ? usableW : (usableW / items.length);

          final children = <Widget>[];

          for (var i = 0; i < items.length; i++) {
            final item = items[i];

            // Size: baseSize etrafında random varyasyon
            final size = (item.baseSize + rng.nextDouble() * item.sizeJitter)
                .clamp(item.minSize, item.maxSize);

            // X: step bazlı, hafif jitter
            final baseX = horizontalPadding + (i * step);
            final jitterX = (rng.nextDouble() * 18) - 9; // -9..+9
            final x = (baseX + jitterX).clamp(0.0, max(0.0, w - size));

            // Y: ortalama bir baseline, yukarı-aşağı jitter
            final baseline = (height - size) * 0.55;
            final jitterY = (rng.nextDouble() * item.yJitter) - (item.yJitter / 2);
            final y = (baseline + jitterY).clamp(0.0, max(0.0, height - size));

            // Rotation: -max..+max
            final rot = ((rng.nextDouble() * 2) - 1) * item.maxRotationRad;

            // Opacity: hafif depth hissi
            final opacity = (item.opacity + rng.nextDouble() * 0.12).clamp(0.25, 1.0);

            children.add(
              Positioned(
                left: x.toDouble(),
                top: y.toDouble(),
                child: Opacity(
                  opacity: opacity,
                  child: Transform.rotate(
                    angle: rot,
                    child: ChaputCircleAvatar(
                      isDefaultAvatar: item.isDefaultAvatar,
                      imageUrl: item.imageUrl,
                      width: size,
                      height: size,
                      radius: 999,
                    ),
                  ),
                ),
              ),
            );
          }

          return Stack(
            clipBehavior: Clip.none,
            children: children,
          );
        },
      ),
    );
  }
}

class AvatarScatterItem {
  final bool isDefaultAvatar;
  final String imageUrl;

  /// Boyut ayarları
  final double baseSize;
  final double sizeJitter;
  final double minSize;
  final double maxSize;

  /// Yukarı-aşağı jitter (px)
  final double yJitter;

  /// Max rotation (radyan) — 0.25 ~ 14 derece gibi
  final double maxRotationRad;

  /// Baz opacity (depth)
  final double opacity;

  const AvatarScatterItem({
    required this.isDefaultAvatar,
    required this.imageUrl,
    this.baseSize = 44,
    this.sizeJitter = 18,
    this.minSize = 28,
    this.maxSize = 74,
    this.yJitter = 34,
    this.maxRotationRad = 0.28,
    this.opacity = 0.9,
  });
}
