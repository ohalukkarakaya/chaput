import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class FadingVideoHeader extends StatefulWidget {
  final String assetPath;
  final double height;
  final Color fadeToColor;

  /// Fade’in ne kadar aşağıdan başlayacağı (0..1)
  /// 0.55 => videonun alt %45’inde fade başlar gibi düşün.
  final double fadeStart;

  const FadingVideoHeader({
    super.key,
    required this.assetPath,
    required this.height,
    required this.fadeToColor,
    this.fadeStart = 0.60,
  });

  @override
  State<FadingVideoHeader> createState() => _FadingVideoHeaderState();
}

class _FadingVideoHeaderState extends State<FadingVideoHeader> {
  late final VideoPlayerController _c;
  late final Future<void> _init;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.asset(widget.assetPath);
    _init = _c.initialize().then((_) async {
      await _c.setLooping(true);
      await _c.setVolume(0.0); // onboarding: sessiz daha iyi
      await _c.play();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: FutureBuilder<void>(
        future: _init,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done || !_c.value.isInitialized) {
            // placeholder
            return DecoratedBox(
              decoration: BoxDecoration(
                color: widget.fadeToColor,
              ),
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          // Video + bottom fade
          return ClipRect(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [
                    0.0,
                    widget.fadeStart.clamp(0.0, 1.0),
                    1.0,
                  ],
                  colors: const [
                    Colors.white, // full visible
                    Colors.white, // still visible
                    Colors.transparent, // fade out
                  ],
                ).createShader(rect);
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ✅ Altı koru: taşarsa üstten kessin
                  FittedBox(
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      width: _c.value.size.width,
                      height: _c.value.size.height,
                      child: VideoPlayer(_c),
                    ),
                  ),

                  // ✅ Fade bittikten sonra altta arka plan rengin tam otursun diye
                  // Çok ince bir renk “wash” (opsiyonel ama güzel durur)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: widget.height * 0.22,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            widget.fadeToColor.withOpacity(0.0),
                            widget.fadeToColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}