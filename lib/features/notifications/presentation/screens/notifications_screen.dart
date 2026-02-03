import 'dart:async';

import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../chaput/data/chaput_socket.dart';
import '../../../me/application/me_controller.dart';
import '../../application/notification_count_controller.dart';
import '../../application/notifications_controller.dart';
import '../../data/notification_api_provider.dart';
import '../../domain/notification_item.dart';
import '../../../user/domain/lite_user.dart';
import '../../../../core/router/routes.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  StreamSubscription<ChaputSocketEvent>? _socketSub;

  @override
  void initState() {
    super.initState();
    _bootSocket();
  }

  Future<void> _bootSocket() async {
    await ref.read(chaputSocketProvider).ensureConnected();
    _socketSub ??= ref.read(chaputSocketProvider).events.listen(_handleSocketEvent);
  }

  void _handleSocketEvent(ChaputSocketEvent ev) {
    if (ev.type != 'notif.created') return;
    final me = ref.read(meControllerProvider).valueOrNull;
    final meId = me?.user?.userId ?? '';
    if (meId.isEmpty) return;
    final raw = ev.data['notification'];
    var isForMe = false;
    if (raw is Map) {
      final notif = AppNotification.fromJson(raw.map((k, v) => MapEntry(k.toString(), v)));
      if (notif.userId.isEmpty) return;
      if (notif.userId != meId) return;
      isForMe = true;
      ref.read(notificationsControllerProvider.notifier).addFromSocket(notif);
      ref.read(notificationsControllerProvider.notifier).ensureActorLoaded(notif.actorId);
    }
    final unread = ev.data['unread_count'];
    if (isForMe) {
      if (unread is int) {
        ref.read(notificationCountControllerProvider.notifier).updateFromSocket(unread);
      } else if (unread is num) {
        ref.read(notificationCountControllerProvider.notifier).updateFromSocket(unread.toInt());
      }
    }
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _socketSub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(notificationsControllerProvider);
    final me = ref.watch(meControllerProvider).valueOrNull;
    final entries = _buildEntries(st.items);

    return Scaffold(
      backgroundColor: const Color(0xffEEF2F6),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('‹ Back', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => ref.read(notificationsControllerProvider.notifier).refresh(),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Bildirimler',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (st.isLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: st.error != null
                        ? Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Error: ${st.error}', style: const TextStyle(color: Colors.red)),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  onPressed: () => ref.read(notificationsControllerProvider.notifier).refresh(),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : (st.items.isEmpty && !st.isLoading)
                            ? const Center(
                                child: Text(
                                  'Hiç yok',
                                  style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black54),
                                ),
                              )
                            : NotificationListener<ScrollNotification>(
                                onNotification: (n) {
                                  if (n.metrics.pixels >= n.metrics.maxScrollExtent - 220) {
                                    ref.read(notificationsControllerProvider.notifier).loadMore();
                                  }
                                  return false;
                                },
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                  itemCount: entries.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, i) {
                                    final entry = entries[i];
                                    if (entry.header != null) {
                                      return Padding(
                                        padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                                        child: Text(
                                          entry.header!,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      );
                                    }

                                    final it = entry.item!;
                                    final actor = it.actorId != null ? st.usersById[it.actorId!] : null;
                                    return _NotificationRow(
                                      item: it,
                                      actor: actor,
                                      onTap: () => _handleTap(context, ref, it, me?.user.userId ?? ''),
                                      onApprove: it.type == 'follow_request'
                                          ? () => _approveFollow(ref, it)
                                          : null,
                                      onReject: it.type == 'follow_request'
                                          ? () => _rejectFollow(ref, it)
                                          : null,
                                    );
                                  },
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _approveFollow(WidgetRef ref, AppNotification it) async {
    final seq = it.payload['request_seq'];
    if (seq is! int && seq is! String) return;
    final seqNum = seq is int ? seq : int.tryParse(seq.toString());
    if (seqNum == null) return;
    final wasUnread = !it.isRead;
    bool ok = false;
    try {
      ok = await ref.read(notificationApiProvider).approveFollowRequest(seqNum);
    } catch (_) {
      // ignore
    } finally {
      if (ok) {
        ref.read(notificationsControllerProvider.notifier).replaceWithFollowed(it);
      } else {
        // On failure, remove follow request notification from UI
        ref.read(notificationsControllerProvider.notifier).removeLocal(it.id);
      }
      if (wasUnread) {
        ref.read(notificationCountControllerProvider.notifier).decrementIfUnread();
      }
      // Best effort: mark as read on server to keep counts consistent
      try {
        await ref.read(notificationsControllerProvider.notifier).markRead(it.id);
      } catch (_) {
        // ignore
      }
    }
  }

  Future<void> _rejectFollow(WidgetRef ref, AppNotification it) async {
    final seq = it.payload['request_seq'];
    if (seq is! int && seq is! String) return;
    final seqNum = seq is int ? seq : int.tryParse(seq.toString());
    if (seqNum == null) return;
    final wasUnread = !it.isRead;
    try {
      await ref.read(notificationApiProvider).rejectFollowRequest(seqNum);
    } catch (_) {
      // ignore
    } finally {
      ref.read(notificationsControllerProvider.notifier).removeLocal(it.id);
      if (wasUnread) {
        ref.read(notificationCountControllerProvider.notifier).decrementIfUnread();
      }
      try {
        await ref.read(notificationsControllerProvider.notifier).markRead(it.id);
      } catch (_) {
        // ignore
      }
    }
  }

  Future<void> _handleTap(BuildContext context, WidgetRef ref, AppNotification it, String myUserId) async {
    await ref.read(notificationsControllerProvider.notifier).markRead(it.id);
    ref.read(notificationCountControllerProvider.notifier).decrementIfUnread();

    if (it.type == 'chaput_started' ||
        it.type == 'chaput_message' ||
        it.type == 'chaput_revive' ||
        it.type == 'chaput_message_like') {
      if (myUserId.isEmpty) return;
      final threadId = it.threadId ?? it.payload['thread_id']?.toString();
      if (threadId == null || threadId.isEmpty) {
        context.push(await Routes.profile(myUserId));
        return;
      }
      final messageId = it.payload['message_id']?.toString();
      context.push(await Routes.profile(myUserId), extra: {
        'threadId': threadId,
        if (messageId != null && messageId.isNotEmpty) 'messageId': messageId,
      });
      return;
    }

    if (it.type == 'followed' || it.type == 'follow_approved' || it.type == 'follow_request') {
      final actorId = it.actorId;
      if (actorId == null || actorId.isEmpty) return;
      context.push(await Routes.profile(actorId));
    }
  }

  List<_NotifEntry> _buildEntries(List<AppNotification> items) {
    if (items.isEmpty) return const [];
    final followReqs = <AppNotification>[];
    final rest = <AppNotification>[];
    for (final it in items) {
      if (it.type == 'follow_request') {
        followReqs.add(it);
      } else {
        rest.add(it);
      }
    }

    final entries = <_NotifEntry>[];
    if (followReqs.isNotEmpty) {
      entries.add(const _NotifEntry.header('Takip istekleri'));
      for (final it in followReqs) {
        entries.add(_NotifEntry.item(it));
      }
    }

    String? lastLabel;
    for (final it in rest) {
      final label = _dateLabel(it.createdAt);
      if (label != null && label != lastLabel) {
        entries.add(_NotifEntry.header(label));
        lastLabel = label;
      }
      entries.add(_NotifEntry.item(it));
    }
    return entries;
  }

  String? _dateLabel(DateTime? dt) {
    if (dt == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Dün';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.item,
    required this.actor,
    required this.onTap,
    required this.onApprove,
    required this.onReject,
  });

  final AppNotification item;
  final LiteUser? actor;
  final VoidCallback onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final title = actor?.fullName ?? 'Bir kullanıcı';
    final username = actor?.username;
    final avatarUrl = (actor?.profilePhotoPath?.isNotEmpty == true)
        ? actor!.profilePhotoPath!
        : (actor?.defaultAvatar ?? '');
    final isDefault = actor?.profilePhotoPath == null || actor?.profilePhotoPath == '';

    final message = _buildMessage(item);

    final bubbleColor = item.isRead ? Colors.white : const Color(0xffE6ECF5);
    return Material(
      color: bubbleColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChaputCircleAvatar(
                imageUrl: avatarUrl,
                isDefaultAvatar: isDefault,
                width: 44,
                height: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: item.isRead ? FontWeight.w700 : FontWeight.w900,
                            ),
                          ),
                        ),
                        if (item.createdAt != null)
                          Text(
                            _timeAgo(item.createdAt!),
                            style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.45)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      username == null || username.isEmpty ? message : '$message • @$username',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.65)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!item.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xff2F6BFF),
                  ),
                )
              else
                const SizedBox(width: 8),
              if (onApprove != null || onReject != null) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onReject != null)
                      _ActionIconButton(
                        onPressed: onReject!,
                        background: const Color(0xffD9DEE6),
                        icon: Icons.close,
                        iconColor: Colors.black87,
                      ),
                    if (onApprove != null) ...[
                      const SizedBox(width: 8),
                      _ActionIconButton(
                        onPressed: onApprove!,
                        background: Colors.black,
                        icon: Icons.check,
                        iconColor: Colors.white,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _buildMessage(AppNotification n) {
    switch (n.type) {
      case 'followed':
        return 'Seni takip etti';
      case 'follow_request':
        return 'Takip isteği gönderdi';
      case 'follow_approved':
        return 'Takip isteğini onayladı';
      case 'chaput_started':
        return 'Sana chaput bağladı';
      case 'chaput_message':
        final body = n.payload['body']?.toString();
        return body == null || body.isEmpty ? 'Yeni mesaj' : body;
      case 'chaput_revive':
        return 'Chaputu arşivden kurtardı';
      case 'chaput_message_like':
        final body = n.payload['body']?.toString();
        return body == null || body.isEmpty ? 'Mesajını beğendi' : 'Mesajını beğendi: $body';
      default:
        return 'Bildirim';
    }
  }

  static String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}g';
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

class _NotifEntry {
  const _NotifEntry._(this.header, this.item);
  const _NotifEntry.header(this.header) : item = null;
  const _NotifEntry.item(this.item) : header = null;

  final String? header;
  final AppNotification? item;
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.onPressed,
    required this.background,
    required this.icon,
    required this.iconColor,
  });

  final VoidCallback onPressed;
  final Color background;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
  }
}
