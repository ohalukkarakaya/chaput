import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'video_background_controller.dart';

class VideoBackground extends ConsumerWidget {
  final Widget child;
  final double overlayOpacity;
  final String? debugLabel;

  const VideoBackground({
    super.key,
    required this.child,
    this.overlayOpacity = 0.45,
    this.debugLabel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoController = ref.watch(videoBackgroundControllerProvider);

    return FutureBuilder(
      future: videoController.init(),
      builder: (context, snapshot) {
        // ✅ INIT FAIL -> ekrana hata yaz
        if (snapshot.hasError) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Video yüklenemedi:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              if (debugLabel != null)
                Positioned(
                  top: 48,
                  left: 16,
                  child: _DebugPill(text: debugLabel!),
                ),
              child,
            ],
          );
        }

        // ✅ LOADING -> “koyu gri” yerine daha anlamlı placeholder
        if (snapshot.connectionState != ConnectionState.done) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0B0B0D), Color(0xFF1A1A1F)],
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: 0.8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                     ],
                  ),
                ),
              ),
              if (debugLabel != null)
                Positioned(
                  top: 48,
                  left: 16,
                  child: _DebugPill(text: debugLabel!),
                ),
            ],
          );
        }

        final c = videoController.controller;

        // ✅ Defensive: initialize true değilse placeholder
        if (!c.value.isInitialized) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              const Center(
                child: Text('Video initialize olmadı', style: TextStyle(color: Colors.white70)),
              ),
              if (debugLabel != null)
                Positioned(
                  top: 48,
                  left: 16,
                  child: _DebugPill(text: debugLabel!),
                ),
            ],
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            // 🎥 Video
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            ),

            // 🌫 Overlay (okunurluk)
            Container(color: Colors.black.withOpacity(overlayOpacity)),

            if (debugLabel != null)
              Positioned(
                top: 48,
                left: 16,
                child: _DebugPill(text: debugLabel!),
              ),

            // UI
            child,
          ],
        );
      },
    );
  }
}

class _DebugPill extends StatelessWidget {
  final String text;
  const _DebugPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }
}