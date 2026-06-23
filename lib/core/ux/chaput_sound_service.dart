import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

final AudioContext _chaputSfxAudioContext = AudioContext(
  iOS: AudioContextIOS(
    category: AVAudioSessionCategory.playback,
    options: {
      AVAudioSessionOptions.mixWithOthers,
    },
  ),
  android: AudioContextAndroid(
    contentType: AndroidContentType.sonification,
    usageType: AndroidUsageType.assistanceSonification,
    audioFocus: AndroidAudioFocus.none,
  ),
);

enum ChaputSoundEffect {
  cardSwipe('sounds/chaput_card_swiping.mp3'),
  copyProfileLink('sounds/chaput_copy_profile_link.mp3'),
  refreshRecommendedUser('sounds/chaput_refresh_recomended_user.mp3'),
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

  Future<AudioPlayer> _createPlayer(String playerId) async {
    final player = AudioPlayer(playerId: playerId);
    await player.setAudioContext(_chaputSfxAudioContext);
    return player;
  }

  Future<void> play(ChaputSoundEffect effect, {double playbackRate = 1}) async {
    try {
      var player = _effectPlayers[effect];

      if (player == null) {
        player = await _createPlayer('chaput_${effect.name}');
        _effectPlayers[effect] = player;
      }

      await player.setAudioContext(_chaputSfxAudioContext);
      await player.setReleaseMode(ReleaseMode.stop);

      try {
        await player.setPlaybackRate(
          playbackRate.clamp(0.75, 1.35).toDouble(),
        );
      } catch (_) {}

      await player.stop();
      await player.play(
        AssetSource(effect.assetPath),
        mode: PlayerMode.lowLatency,
      );
    } catch (e, st) {
      debugPrint('ChaputSoundService play failed: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Future<void> startTypingLoop() async {
    if (_typingPlaying) return;
    _typingPlaying = true;

    try {
      await _typingPlayer.setAudioContext(_chaputSfxAudioContext);
      await _typingPlayer.setReleaseMode(ReleaseMode.loop);
      await _typingPlayer.play(
        AssetSource(_typingAsset),
        mode: PlayerMode.lowLatency,
      );
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