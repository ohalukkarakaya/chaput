import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/network/dio_provider.dart';
import '../notifications/application/notifications_controller.dart';
import '../notifications/application/notification_count_controller.dart';
import 'rps_controller.dart';

const rpsEmojis = ['✊', '✋', '✌️'];

class RpsControl extends ConsumerStatefulWidget {
  const RpsControl({
    super.key,
    required this.opponentId,
    this.notificationRound,
    this.notificationId,
    this.notificationLayout,
  });
  final String opponentId;
  final int? notificationRound;
  final String? notificationId;
  final Widget Function(BuildContext, String, Widget)? notificationLayout;

  @override
  ConsumerState<RpsControl> createState() => _RpsControlState();
}

class _RpsControlState extends ConsumerState<RpsControl> {
  bool _expanded = false;
  bool _busy = false;
  int? _expandedRound;

  Future<void> _play(RpsGame game, int move) async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    try {
      await ref
          .read(dioProvider)
          .post(
            '/users/${widget.opponentId}/rps',
            data: {
              'move': move,
              'round': game.round,
              if (widget.notificationId != null)
                'notification_id': widget.notificationId,
              if (game.gameId != null) 'game_id': game.gameId,
            },
          );
      if (!mounted) return;
      setState(() => _expanded = false);
      ref.invalidate(rpsGameProvider(widget.opponentId));
      if (ref.exists(notificationsControllerProvider)) {
        ref.invalidate(notificationsControllerProvider);
      }
      ref.invalidate(notificationCountControllerProvider);
    } catch (error) {
      if (!mounted) return;
      ref.invalidate(rpsGameProvider(widget.opponentId));
      final stale = error is DioException && error.response?.statusCode == 409;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t(stale ? 'rps.updated' : 'rps.error')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = rpsGameProvider(widget.opponentId);
    ref.listen(provider, (previous, next) {
      final before = previous?.value;
      final after = next.value;
      if (before?.status != 'complete' &&
          before != null &&
          after?.status == 'complete') {
        HapticFeedback.mediumImpact();
      }
    });
    final asyncGame = ref.watch(provider);
    final game = asyncGame.value;
    if (asyncGame.hasError || game == null || !game.available) {
      return const SizedBox.shrink();
    }
    // Old notification cards cannot submit a move for a later round.
    if (widget.notificationRound != null &&
        (widget.notificationRound != game.round || game.status != 'invited')) {
      return const SizedBox.shrink();
    }
    final choosing =
        game.status == 'invited' ||
        (_expanded && _expandedRound == game.round && game.status != 'waiting');
    final tone = game.status == 'waiting'
        ? const Color(0xFF93722B)
        : choosing || game.status == 'idle'
        ? const Color(0xFF456F99)
        : switch (game.outcome) {
            'won' => const Color(0xFF377E65),
            'lost' => const Color(0xFFA75E60),
            _ => const Color(0xFF716D92),
          };
    final disabled = _busy || asyncGame.isLoading;
    Widget content;
    if (choosing) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.notificationRound != null &&
              widget.notificationLayout == null) ...[
            Text(
              context.t(game.status == 'invited' ? 'rps.invite' : 'rps.choose'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                if (widget.notificationLayout != null)
                  _NotificationAction(
                    label: context.t('rps.move.$i'),
                    onTap: disabled ? null : () => _play(game, i),
                    child: Text(
                      rpsEmojis[i],
                      style: const TextStyle(fontSize: 21),
                    ),
                  )
                else
                  _GlassAction(
                    color: tone,
                    label: context.t('rps.move.$i'),
                    onTap: disabled ? null : () => _play(game, i),
                    child: SizedBox(
                      width: 44,
                      child: Center(
                        child: Text(
                          rpsEmojis[i],
                          style: const TextStyle(fontSize: 23),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ],
      );
    } else {
      final waiting = game.status == 'waiting';
      final complete = game.status == 'complete';
      final label = waiting
          ? context.t('rps.waiting')
          : complete
          ? context.t(
              widget.notificationRound != null
                  ? 'rps.rematch'
                  : 'rps.${game.outcome}',
            )
          : context.t('rps.play');
      content = _GlassAction(
        color: tone,
        label: complete ? '$label. ${context.t('rps.rematch')}' : label,
        onTap: disabled || waiting
            ? null
            : () {
                HapticFeedback.selectionClick();
                setState(() {
                  _expanded = true;
                  _expandedRound = game.round;
                });
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else if (complete)
                const Icon(Icons.replay_rounded, size: 19, color: Colors.white)
              else
                Text(
                  waiting && game.ownMove != null
                      ? rpsEmojis[game.ownMove!]
                      : '✊ ✋ ✌️',
                  style: const TextStyle(fontSize: 20),
                ),
              if (waiting || complete) ...[
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (widget.notificationLayout != null) {
      return widget.notificationLayout!(
        context,
        context.t('rps.invite'),
        content,
      );
    }
    return Align(
      alignment: widget.notificationRound != null
          ? Alignment.centerLeft
          : Alignment.centerRight,
      widthFactor: 1,
      child: AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: Alignment.centerRight,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: KeyedSubtree(
            key: ValueKey('${game.status}:$choosing:${game.outcome}'),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _GlassAction extends StatelessWidget {
  const _GlassAction({
    required this.color,
    required this.label,
    required this.child,
    this.onTap,
  });
  final Color color;
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Tooltip(
      message: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: .76),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: .24)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: .66),
                  color.withValues(alpha: .86),
                ],
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: SizedBox(height: 44, child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _NotificationAction extends StatelessWidget {
  const _NotificationAction({
    required this.label,
    required this.child,
    this.onTap,
  });
  final String label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    enabled: onTap != null,
    child: Tooltip(
      message: label,
      child: Material(
        color: const Color(0xFFE0E5EC),
        shape: const CircleBorder(side: BorderSide(color: Color(0x80FFFFFF))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 36, height: 36, child: Center(child: child)),
        ),
      ),
    ),
  );
}
