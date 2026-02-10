import 'dart:math';

import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class AnimatedMeshBackground extends StatefulWidget {
  const AnimatedMeshBackground({
    super.key,
    required this.baseColor,
  });

  final Color baseColor;

  @override
  State<AnimatedMeshBackground> createState() => _AnimatedMeshBackgroundState();
}

class _AnimatedMeshBackgroundState extends State<AnimatedMeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10), // yavaş = daha az dikkat + daha az yük
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Arkaplan dokunsal değil, hit-test almasın
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value; // 0..1
          // Çok küçük hareketler: “liquid” hissi
          final a1 = 0.15 + 0.03 * sin(t * 2 * pi);
          final a2 = 0.12 + 0.03 * sin((t + 0.33) * 2 * pi);
          final a3 = 0.10 + 0.03 * sin((t + 0.66) * 2 * pi);

          final p1 = Alignment(
            -0.75 + 0.25 * cos(t * 2 * pi),
            -0.8,
          );

          final p2 = Alignment(
            0.85,
            -0.2 + 0.25 * sin((t + 0.4) * 2 * pi),
          );

          final p3 = Alignment(
            -0.2 + 0.25 * sin((t + 0.2) * 2 * pi),
            0.95,
          );

          return DecoratedBox(
            decoration: BoxDecoration(color: widget.baseColor),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1) Yumuşak mavi blob
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: p1,
                      radius: 1.2,
                      colors: [
                        AppColors.chaputSkyBlue.withOpacity(a1),
                        AppColors.chaputTransparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
                // 2) Mor/pembe blob
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: p2,
                      radius: 1.15,
                      colors: [
                        AppColors.chaputLavender.withOpacity(a2),
                        AppColors.chaputTransparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
                // 3) Mint/teal blob
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: p3,
                      radius: 1.25,
                      colors: [
                        AppColors.chaputMint.withOpacity(a3),
                        AppColors.chaputTransparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),

                // Hafif vignette (buzlu cam hissini güçlendirir)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.chaputWhite.withOpacity(0.00),
                        AppColors.chaputBlack.withOpacity(0.05),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
