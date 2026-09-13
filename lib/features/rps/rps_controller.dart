import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chaput/data/chaput_socket.dart';
import '../../core/network/dio_provider.dart';
import '../me/application/me_controller.dart';

class RpsGame {
  const RpsGame({
    required this.available,
    required this.round,
    required this.status,
    this.gameId,
    this.ownMove,
    this.otherMove,
    this.outcome,
  });
  factory RpsGame.fromJson(Map<String, dynamic> json) => RpsGame(
    gameId: json['game_id']?.toString(),
    available: json['available'] == true,
    round: (json['round'] as num?)?.toInt() ?? 0,
    status: json['status']?.toString() ?? 'idle',
    ownMove: (json['own_move'] as num?)?.toInt(),
    otherMove: (json['other_move'] as num?)?.toInt(),
    outcome: json['outcome']?.toString(),
  );
  final String? gameId;
  final bool available;
  final int round;
  final String status;
  final int? ownMove;
  final int? otherMove;
  final String? outcome;
}

final rpsGameProvider = FutureProvider.autoDispose.family<RpsGame, String>((
  ref,
  opponent,
) async {
  ref.watch(meControllerProvider.select((value) => value.value?.user.userId));
  final subscription = ref.read(chaputSocketProvider).events.listen((event) {
    if (event.type == 'socket.connected' ||
        (event.type == 'rps.changed' &&
            event.data['opponent_id']?.toString().toLowerCase() ==
                opponent.toLowerCase())) {
      ref.invalidateSelf();
    }
  });
  ref.onDispose(() {
    subscription.cancel();
  });
  final response = await ref.read(dioProvider).get('/users/$opponent/rps');
  return RpsGame.fromJson(Map<String, dynamic>.from(response.data as Map));
});
