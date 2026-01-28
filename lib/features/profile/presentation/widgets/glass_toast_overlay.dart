import 'dart:ui';

import 'package:flutter/material.dart';

class GlassToastOverlay extends StatefulWidget {
  const GlassToastOverlay({
    super.key,
    required this.message,
    required this.icon,
    required this.bottom,
    required this.onDone,
    required this.duration,
  });

  final String message;
  final IconData icon;
  final double bottom;
  final VoidCallback onDone;
  final Duration duration;

  @override
  State<GlassToastOverlay> createState() => _GlassToastOverlayState();
}

class _GlassToastOverlayState extends State<GlassToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
      reverseDuration: const Duration(milliseconds: 120),
    );

    _fade = CurvedAnimation(
      parent: _c,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _slide = Tween<double>(begin: 10, end: 0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );

    _c.forward();

    Future.delayed(widget.duration, () async {
      if (!mounted) return;
      await _c.reverse();
      if (!mounted) return;
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned(
              left: 14,
              right: 14,
              bottom: widget.bottom,
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) {
                  return Opacity(
                    opacity: _fade.value,
                    child: Transform.translate(
                      offset: Offset(0, _slide.value),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.10),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      widget.icon,
                                      color: Colors.white.withOpacity(0.92),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      widget.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
