import 'package:audioplayers/audioplayers.dart';

enum ChaputSoundEffect {
  cardSwipe('sounds/chaput_card_swiping.mp3'),
  copyProfileLink('sounds/chaput_copy_profile_link.mp3'),
  sendMessage('sounds/chaput_send_message.mp3');

  const ChaputSoundEffect(this.assetPath);

  final String assetPath;
}

class ChaputSoundService {
  ChaputSoundService._();

  static final ChaputSoundService instance = ChaputSoundService._();

  static const _typingAsset = 'sounds/chaput_typing.mp3';

  final Map<ChaputSoundEffect, AudioPlayer> _effectPlayers = {};
  final AudioPlayer _typingPlayer = AudioPlayer(playerId: 'chaput_typing_loop');
  bool _typingPlaying = false;

  Future<void> play(ChaputSoundEffect effect, {double playbackRate = 1}) async {
    try {
      final player = _effectPlayers.putIfAbsent(effect, () {
        return AudioPlayer(playerId: 'chaput_${effect.name}');
      });
      await player.setReleaseMode(ReleaseMode.stop);
      try {
        await player.setPlaybackRate(playbackRate.clamp(0.75, 1.35).toDouble());
      } catch (_) {}
      await player.stop();
      await player.play(
        AssetSource(effect.assetPath),
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {
      // UX sounds are best-effort and must never block the primary action.
    }
  }

  Future<void> startTypingLoop() async {
    if (_typingPlaying) return;
    _typingPlaying = true;
    try {
      await _typingPlayer.setReleaseMode(ReleaseMode.loop);
      await _typingPlayer.play(AssetSource(_typingAsset));
    } catch (_) {
      _typingPlaying = false;
    }
  }

  Future<void> stopTypingLoop() async {
    if (!_typingPlaying) return;
    _typingPlaying = false;
    try {
      await _typingPlayer.stop();
    } catch (_) {}
  }
}
