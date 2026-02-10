import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chaput/core/constants/app_colors.dart';

class VideoBackground extends StatefulWidget {
  final Widget child;
  final double overlayOpacity;
  final String assetPath;

  const VideoBackground({
    super.key,
    required this.child,
    required this.assetPath,
    this.overlayOpacity = 0.45,
  });

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground> with WidgetsBindingObserver {
  late final VideoPlayerController _controller;
  late final Future<void> _init;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = VideoPlayerController.asset(widget.assetPath);
    _init = _controller.initialize().then((_) async {
      await _controller.setLooping(true);
      await _controller.setVolume(0.0);
      await _controller.play();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // iOS simulator bazen background/foreground geçişinde video duruyor
    if (state == AppLifecycleState.resumed) {
      if (_controller.value.isInitialized) _controller.play();
    } else if (state == AppLifecycleState.paused) {
      if (_controller.value.isInitialized) _controller.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Klavye/padding değişse bile video katmanı aynı kalsın
    final mq = MediaQuery.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        // ✅ Video'yu insets'ten bağımsız çiz
        MediaQuery(
          data: mq.copyWith(
            viewInsets: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
          ),
          child: FutureBuilder<void>(
            future: _init,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done || !_controller.value.isInitialized) {
                return const ColoredBox(color: AppColors.chaputBlack);
              }

              return FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              );
            },
          ),
        ),

        // ✅ Overlay dokunmayı bloklamasın
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: Container(color: AppColors.chaputBlack.withOpacity(widget.overlayOpacity)),
          ),
        ),

        // ✅ Üst içerik normal MediaQuery ile kalsın (klavye vs. burada yönetilir)
        widget.child,
      ],
    );
  }

}
