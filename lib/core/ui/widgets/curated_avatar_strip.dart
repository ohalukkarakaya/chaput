import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../chaput_circle_avatar/chaput_circle_avatar.dart';

class CuratedAvatarStrip extends StatelessWidget {
  /// En az 5 öneririm (görsel gibi)
  /// items[centerIndex] ortadaki büyük avatar olur.
  final List<CuratedAvatarItem> items;

  /// Yükseklik (görselde ~120-140 gibi)
  final double height;

  /// Ortadaki avatar index’i
  final int centerIndex;

  const CuratedAvatarStrip({
    super.key,
    required this.items,
    this.height = 130,
    this.centerIndex = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return SizedBox(height: height);

    // Pattern: merkez büyük, çevre küçük (görselin düzeni)
    // x: soldan yüzde, y: yukarıdan px, size: px, rot: derece
    final pattern = <_AvatarSlot>[
      // sol uç (küçük)
      const _AvatarSlot(xPct: 0.06, y: 56, size: 42, rotDeg: -10, opacity: 0.92),
      // sol orta (orta)
      const _AvatarSlot(xPct: 0.18, y: 38, size: 50, rotDeg: -6, opacity: 0.95),
      // merkez (büyük)
      const _AvatarSlot(xPct: 0.38, y: 18, size: 86, rotDeg: 0, opacity: 1.0),
      // sağ orta (orta)
      const _AvatarSlot(xPct: 0.62, y: 42, size: 52, rotDeg: 6, opacity: 0.95),
      // sağ uç (küçük)
      const _AvatarSlot(xPct: 0.78, y: 54, size: 44, rotDeg: 10, opacity: 0.92),
      // ekstra sağ (mini)
      const _AvatarSlot(xPct: 0.90, y: 50, size: 40, rotDeg: 12, opacity: 0.88),
    ];

    // items sayısı pattern’den az/çok olabilir:
    // - azsa: pattern’in ilk N slot’unu kullan
    // - çoksa: fazla item’ları yok say (MVP)
    final slots = pattern.take(items.length).toList();

    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;

          // Ortadaki avatar her zaman en önde görünsün diye children sırası:
          // önce küçükler, en son merkez.
          final indexed = List.generate(slots.length, (i) => i);

          indexed.sort((a, b) {
            final sa = slots[a].size;
            final sb = slots[b].size;
            return sa.compareTo(sb); // küçük önce, büyük sonra
          });

          return Stack(
            clipBehavior: Clip.none,
            children: [
              for (final i in indexed)
                _buildAvatar(
                  w: w,
                  slot: slots[i],
                  item: items[i],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatar({
    required double w,
    required _AvatarSlot slot,
    required CuratedAvatarItem item,
  }) {
    final x = (w * slot.xPct).clamp(0.0, math.max(0.0, w - slot.size));
    final y = slot.y.clamp(0.0, math.max(0.0, height - slot.size));

    return Positioned(
      left: x.toDouble(),
      top: y.toDouble(),
      child: Opacity(
        opacity: slot.opacity,
        child: Transform.rotate(
          angle: slot.rotDeg * math.pi / 180,
          child: ChaputCircleAvatar(
            isDefaultAvatar: item.isDefaultAvatar,
            imageUrl: item.imageUrl,
            width: slot.size,
            height: slot.size,
            radius: 999,
          ),
        ),
      ),
    );
  }
}

class CuratedAvatarItem {
  final bool isDefaultAvatar;
  final String imageUrl;

  const CuratedAvatarItem({
    required this.isDefaultAvatar,
    required this.imageUrl,
  });
}

class _AvatarSlot {
  final double xPct;
  final double y;
  final double size;
  final double rotDeg;
  final double opacity;

  const _AvatarSlot({
    required this.xPct,
    required this.y,
    required this.size,
    required this.rotDeg,
    required this.opacity,
  });
}