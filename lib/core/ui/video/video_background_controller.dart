import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

final videoBackgroundControllerProvider =
Provider<VideoBackgroundController>((ref) {
  final controller = VideoBackgroundController();
  ref.onDispose(controller.dispose);
  return controller;
});

class VideoBackgroundController {
  VideoPlayerController? _controller;

  VideoPlayerController get controller => _controller!;

  Future<void> init() async {
    if (_controller != null) return;

    _controller = VideoPlayerController.asset(
      'assets/videos/chaput_bg.M4V',
    );

    await _controller!.initialize();
    _controller!
      ..setLooping(true)
      ..setVolume(0)
      ..play();
  }

  void dispose() {
    _controller?.dispose();
  }
}