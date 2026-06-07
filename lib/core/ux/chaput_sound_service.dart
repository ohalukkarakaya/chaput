import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

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
  final AudioPlayer _cardSwipePlayer = AudioPlayer(
    playerId: 'chaput_card_swipe_motion',
  );
  bool _typingPlaying = false;
  bool _cardSwipePlaying = false;
  bool _cardSwipeUpdateScheduled = false;
  bool _cardSwipeUpdateDirty = false;
  int _cardSwipeGeneration = 0;
  double _cardSwipeTargetRate = 1;
  double _cardSwipeTargetVolume = 0;

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

  void updateCardSwipeMotion({
    required double progress,
    required double pagesPerSecond,
  }) {
    final normalizedProgress = ((progress - 0.02) / 0.62).clamp(0, 1);
    final normalizedSpeed = ((pagesPerSecond - 0.03) / 2.6).clamp(0, 1);

    _cardSwipeTargetRate = (0.56 + normalizedSpeed * 1.14)
        .clamp(0.56, 1.7)
        .toDouble();
    _cardSwipeTargetVolume =
        (0.14 + normalizedProgress * 0.28 + normalizedSpeed * 0.38)
            .clamp(0.12, 0.8)
            .toDouble();

    _cardSwipeUpdateDirty = true;
    if (_cardSwipeUpdateScheduled) return;
    _cardSwipeUpdateScheduled = true;
    unawaited(_applyCardSwipeMotion());
  }

  Future<void> _applyCardSwipeMotion() async {
    try {
      while (_cardSwipeUpdateDirty) {
        _cardSwipeUpdateDirty = false;
        final generation = _cardSwipeGeneration;
        final rate = _cardSwipeTargetRate;
        final volume = _cardSwipeTargetVolume;
        if (!_cardSwipePlaying) {
          await _cardSwipePlayer.setPlayerMode(PlayerMode.mediaPlayer);
          await _cardSwipePlayer.setReleaseMode(ReleaseMode.loop);
          await _cardSwipePlayer.setVolume(volume);
          try {
            await _cardSwipePlayer.setPlaybackRate(rate);
          } catch (_) {}
          await _cardSwipePlayer.play(
            AssetSource(ChaputSoundEffect.cardSwipe.assetPath),
          );
          _cardSwipePlaying = true;
        } else {
          await _cardSwipePlayer.setVolume(volume);
          try {
            await _cardSwipePlayer.setPlaybackRate(rate);
          } catch (_) {}
        }
        if (generation != _cardSwipeGeneration) {
          _cardSwipePlaying = false;
          try {
            await _cardSwipePlayer.stop();
          } catch (_) {}
          return;
        }
      }
    } catch (_) {
      _cardSwipePlaying = false;
    } finally {
      _cardSwipeUpdateScheduled = false;
      if (_cardSwipeUpdateDirty) {
        _cardSwipeUpdateScheduled = true;
        unawaited(_applyCardSwipeMotion());
      }
    }
  }

  Future<void> stopCardSwipeMotion() async {
    _cardSwipeGeneration += 1;
    _cardSwipeUpdateDirty = false;
    _cardSwipeTargetVolume = 0;
    if (!_cardSwipePlaying) return;
    _cardSwipePlaying = false;
    try {
      await _cardSwipePlayer.stop();
    } catch (_) {}
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
