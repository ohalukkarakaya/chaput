import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../chaput/application/chaput_decision_controller.dart';
import '../../../../chaput/application/chaput_messages_controller.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../chaput/domain/chaput_message.dart';
import '../../../../chaput/domain/chaput_thread.dart';
import '../../../user/domain/lite_user.dart';
import '../../../../core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'black_glass.dart';
import 'sheet_handle.dart';

class ChaputThreadSheet extends ConsumerWidget {
  const ChaputThreadSheet({
    super.key,
    required this.threads,
    required this.usersById,
    required this.typingUsersByThread,
    this.viewerUser,
    required this.viewerId,
    required this.ownerId,
    required this.profileId,
    required this.pageController,
    required this.sheetController,
    required this.initialExtent,
    required this.onExtentChanged,
    required this.onPageChanged,
    required this.onOpenProfile,
    required this.onSendMessage,
    required this.onMakeHidden,
    required this.canMakeHidden,
    required this.onOpenWhisperPaywall,
    required this.replyOverlay,
    required this.whisperCredits,
    required this.onReplyMessage,
  });

  final List<ChaputThreadItem> threads;
  final Map<String, LiteUser> usersById;
  final Map<String, List<LiteUser>> typingUsersByThread;
  final LiteUser? viewerUser;
  final String viewerId;
  final String ownerId;
  final String profileId;
  final PageController pageController;
  final DraggableScrollableController sheetController;
  final double initialExtent;
  final ValueChanged<double> onExtentChanged;
  final ValueChanged<int> onPageChanged;
  final void Function(String userId, String threadId) onOpenProfile;
  final Future<void> Function(ChaputThreadItem thread, String body, bool whisper) onSendMessage;
  final Future<void> Function(ChaputThreadItem thread) onMakeHidden;
  final bool canMakeHidden;
  final VoidCallback onOpenWhisperPaywall;
  final double replyOverlay;
  final int whisperCredits;
  final void Function(ChaputThreadItem thread, ChaputMessage message) onReplyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (threads.isEmpty) return const SizedBox.shrink();

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (n) {
        onExtentChanged(n.extent);
        return false;
      },
      child: DraggableScrollableSheet(
        initialChildSize: initialExtent,
        minChildSize: 0.12,
        maxChildSize: 0.95,
        snap: true,
        snapSizes: const [0.12, 0.33, 0.95],
        controller: sheetController,
        builder: (ctx, scrollCtrl) {
          return LayoutBuilder(
            builder: (ctx, constraints) {
              return SingleChildScrollView(
                controller: scrollCtrl,
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: PageView.builder(
                    controller: pageController,
                    onPageChanged: onPageChanged,
                    itemCount: threads.length,
                    itemBuilder: (ctx, index) {
                      final thread = threads[index];
                      final isParticipant = thread.userAId == viewerId || thread.userBId == viewerId;
                      final otherId = thread.userAId == ownerId
                          ? thread.userBId
                          : thread.userBId == ownerId
                              ? thread.userAId
                              : (thread.userAId == viewerId ? thread.userBId : thread.userAId);
                      final ownerUser = usersById[ownerId];
                      final otherUser =
                          usersById[otherId] ?? (viewerUser != null && otherId == viewerUser!.id ? viewerUser : null);

                      final child = _SheetPage(
                        thread: thread,
                        ownerUser: ownerUser,
                        otherUser: otherUser,
                        viewerUser: viewerUser,
                        viewerId: viewerId,
                        isParticipant: isParticipant,
                        profileId: profileId,
                        onOpenProfile: onOpenProfile,
                        onSendMessage: onSendMessage,
                        onMakeHidden: onMakeHidden,
                        canMakeHidden: canMakeHidden,
                        onOpenWhisperPaywall: onOpenWhisperPaywall,
                        replyOverlay: replyOverlay,
                        whisperCredits: whisperCredits,
                        onReplyMessage: onReplyMessage,
                        typingUsersByThread: typingUsersByThread,
                      );

                      return AnimatedBuilder(
                        animation: pageController,
                        builder: (ctx, _) {
                          double page = pageController.initialPage.toDouble();
                          if (pageController.hasClients) {
                            page = pageController.page ?? pageController.initialPage.toDouble();
                          }
                          final delta = (page - index).abs().clamp(0.0, 1.0);
                          final scale = 1.0 - (delta * 0.08);
                          final opacity = 1.0 - (delta * 0.25);
                          return Transform.scale(
                            scale: scale,
                            alignment: Alignment.bottomCenter,
                            child: Opacity(
                              opacity: opacity,
                              child: child,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SheetPage extends StatelessWidget {
  const _SheetPage({
    required this.thread,
    required this.ownerUser,
    required this.otherUser,
    required this.viewerUser,
    required this.viewerId,
    required this.isParticipant,
    required this.profileId,
    required this.onOpenProfile,
    required this.onSendMessage,
    required this.onMakeHidden,
    required this.canMakeHidden,
    required this.onOpenWhisperPaywall,
    required this.replyOverlay,
    required this.whisperCredits,
    required this.onReplyMessage,
    required this.typingUsersByThread,
  });

  final ChaputThreadItem thread;
  final LiteUser? ownerUser;
  final LiteUser? otherUser;
  final LiteUser? viewerUser;
  final String viewerId;
  final bool isParticipant;
  final String profileId;
  final void Function(String userId, String threadId) onOpenProfile;
  final Future<void> Function(ChaputThreadItem thread, String body, bool whisper) onSendMessage;
  final Future<void> Function(ChaputThreadItem thread) onMakeHidden;
  final bool canMakeHidden;
  final VoidCallback onOpenWhisperPaywall;
  final double replyOverlay;
  final int whisperCredits;
  final void Function(ChaputThreadItem thread, ChaputMessage message) onReplyMessage;
  final Map<String, List<LiteUser>> typingUsersByThread;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final compact = constraints.maxHeight < 180;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.80),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: compact
                  ? SizedBox(
                      height: constraints.maxHeight,
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          if (constraints.maxHeight >= 80) ...[
                            const SizedBox(height: 6),
                            const SheetHandle(),
                          ],
                          Expanded(
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topLeft,
                                child: SizedBox(
                                  width: constraints.maxWidth,
                                  child: _ThreadHeader(
                                    ownerUser: ownerUser,
                                    otherUser: otherUser,
                                    isHidden: thread.kind == 'HIDDEN',
                                    isParticipant: isParticipant,
                                    otherName: (thread.kind == 'HIDDEN' && !isParticipant)
                                        ? 'Gizli Kullanıcı'
                                        : (otherUser?.fullName ?? ''),
                                    otherUsername:
                                        (thread.kind == 'HIDDEN' && !isParticipant) ? null : otherUser?.username,
                                    onOpenProfile: onOpenProfile,
                                    threadId: thread.threadId,
                                    showHideAction: isParticipant && thread.kind == 'NORMAL',
                                    canMakeHidden: canMakeHidden,
                                    onMakeHidden: () => onMakeHidden(thread),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        const SizedBox(height: 6),
                        const SheetHandle(),
                        Expanded(
                          child: _ThreadPage(
                            thread: thread,
                            ownerUser: ownerUser,
                            otherUser: otherUser,
                            viewerUser: viewerUser,
                            viewerId: viewerId,
                            isParticipant: isParticipant,
                            profileId: profileId,
                            onOpenProfile: onOpenProfile,
                            onSendMessage: onSendMessage,
                            onMakeHidden: onMakeHidden,
                            canMakeHidden: canMakeHidden,
                            onOpenWhisperPaywall: onOpenWhisperPaywall,
                            replyOverlay: replyOverlay,
                            whisperCredits: whisperCredits,
                            onReplyMessage: onReplyMessage,
                            typingUsers: typingUsersByThread[thread.threadId] ?? const [],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _ThreadPage extends ConsumerWidget {
  const _ThreadPage({
    required this.thread,
    required this.ownerUser,
    required this.otherUser,
    required this.viewerUser,
    required this.viewerId,
    required this.isParticipant,
    required this.profileId,
    required this.onOpenProfile,
    required this.onSendMessage,
    required this.onMakeHidden,
    required this.canMakeHidden,
    required this.onOpenWhisperPaywall,
    required this.replyOverlay,
    required this.whisperCredits,
    required this.onReplyMessage,
    required this.typingUsers,
  });

  final ChaputThreadItem thread;
  final LiteUser? ownerUser;
  final LiteUser? otherUser;
  final LiteUser? viewerUser;
  final String viewerId;
  final bool isParticipant;
  final String profileId;
  final void Function(String userId, String threadId) onOpenProfile;
  final Future<void> Function(ChaputThreadItem thread, String body, bool whisper) onSendMessage;
  final Future<void> Function(ChaputThreadItem thread) onMakeHidden;
  final bool canMakeHidden;
  final VoidCallback onOpenWhisperPaywall;
  final double replyOverlay;
  final int whisperCredits;
  final void Function(ChaputThreadItem thread, ChaputMessage message) onReplyMessage;
  final List<LiteUser> typingUsers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ChaputMessagesArgs(threadId: thread.threadId, profileId: profileId);
    final messagesState = ref.watch(chaputMessagesControllerProvider(args));
    final isHidden = thread.kind == 'HIDDEN';
    final viewerIsStarter = thread.starterId == viewerId;
    final isPending = thread.state == 'PENDING';

    final otherName = (isHidden && !isParticipant) ? 'Gizli Kullanıcı' : (otherUser?.fullName ?? '');
    final otherUsername = (isHidden && !isParticipant) ? null : otherUser?.username;
    final canReply = isParticipant && (!isPending || !viewerIsStarter);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final height = constraints.maxHeight;
        final showMessages = height >= 200;

        final pendingWidget = (isParticipant && isPending && viewerIsStarter)
            ? _PendingNotice(pendingUntil: thread.pendingExpiresAt)
            : (isParticipant && isPending && !viewerIsStarter)
                ? const _PendingReplyHint()
                : null;

        const headerHeight = 64.0;
        const spacing = 8.0;
        const composerHeight = 0.0;
        final pendingHeight = pendingWidget != null ? 22.0 : 0.0;
        final bottomPad = composerHeight + pendingHeight + (pendingWidget != null ? spacing : 0) + replyOverlay;
        final topPad = headerHeight + spacing;
        final hasTyping = typingUsers.isNotEmpty;

        return SizedBox(
          height: height,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _ThreadHeader(
                  ownerUser: ownerUser,
                  otherUser: otherUser,
                  isHidden: isHidden,
                  isParticipant: isParticipant,
                  otherName: otherName,
                  otherUsername: otherUsername,
                  onOpenProfile: onOpenProfile,
                  threadId: thread.threadId,
                  showHideAction: isParticipant && thread.kind == 'NORMAL',
                  canMakeHidden: canMakeHidden,
                  onMakeHidden: () => onMakeHidden(thread),
                ),
              ),
              if (showMessages)
                Positioned(
                  left: 0,
                  right: 0,
                  top: topPad,
                  bottom: bottomPad,
                  child: _MessagesList(
                    state: messagesState,
                    viewerId: viewerId,
                    ownerUser: ownerUser,
                    otherUser: otherUser,
                    viewerUser: viewerUser,
                    isHidden: isHidden,
                    isParticipant: isParticipant,
                    canReply: canReply,
                    onReply: (m) => onReplyMessage(thread, m),
                    onToggleLike: (m, like) {
                      final me = viewerUser == null
                          ? null
                          : ChaputMessageLiker(
                              id: viewerUser!.id,
                              username: viewerUser!.username,
                              fullName: viewerUser!.fullName,
                              defaultAvatar: viewerUser!.defaultAvatar,
                              profilePhotoKey: viewerUser!.profilePhotoKey,
                              profilePhotoUrl: viewerUser!.profilePhotoUrl,
                            );
                      ref
                          .read(chaputMessagesControllerProvider(args).notifier)
                          .toggleLike(messageId: m.id, like: like, me: me);
                    },
                    onLoadMore: () => ref.read(chaputMessagesControllerProvider(args).notifier).loadMore(),
                  ),
                ),
              if (pendingWidget != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: composerHeight,
                  child: pendingWidget,
                ),
              if (showMessages && hasTyping)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: bottomPad + 6,
                  child: _TypingIndicator(users: typingUsers),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.ownerUser,
    required this.otherUser,
    required this.isHidden,
    required this.isParticipant,
    required this.otherName,
    required this.otherUsername,
    required this.onOpenProfile,
    required this.threadId,
    required this.showHideAction,
    required this.canMakeHidden,
    required this.onMakeHidden,
  });

  final LiteUser? ownerUser;
  final LiteUser? otherUser;
  final bool isHidden;
  final bool isParticipant;
  final String otherName;
  final String? otherUsername;
  final void Function(String userId, String threadId) onOpenProfile;
  final String threadId;
  final bool showHideAction;
  final bool canMakeHidden;
  final VoidCallback onMakeHidden;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          _AvatarStack(
            ownerUser: ownerUser,
            otherUser: otherUser,
            hideOther: isHidden && !isParticipant,
            onTap: (id) {
              if (!(isHidden && !isParticipant)) {
                onOpenProfile(id, threadId);
              }
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  otherName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (otherUsername != null && otherUsername!.isNotEmpty)
                  Text(
                    '@$otherUsername',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          if (showHideAction)
            GestureDetector(
              onTap: onMakeHidden,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: canMakeHidden ? Colors.white : Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  'Gizle',
                  style: TextStyle(
                    color: canMakeHidden ? Colors.black : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          if (!showHideAction && isHidden)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Icon(
                Icons.lock,
                size: 14,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({
    required this.ownerUser,
    required this.otherUser,
    required this.hideOther,
    required this.onTap,
  });

  final LiteUser? ownerUser;
  final LiteUser? otherUser;
  final bool hideOther;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final owner = ownerUser;
    final other = otherUser;

    return GestureDetector(
      onTap: () {
        if (!hideOther && other != null) onTap(other.id);
      },
      child: SizedBox(
        width: 58,
        height: 44,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              child: _SmallAvatar(
                user: owner,
                forceDefault: false,
              ),
            ),
            Positioned(
              right: 0,
              child: _SmallAvatar(
                user: other,
                forceDefault: hideOther,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  const _SmallAvatar({
    required this.user,
    required this.forceDefault,
  });

  final LiteUser? user;
  final bool forceDefault;

  @override
  Widget build(BuildContext context) {
    final u = user;
    if (u == null) {
      return const SizedBox(width: 36, height: 36);
    }

    final hasPhoto = u.profilePhotoPath != null && u.profilePhotoPath!.isNotEmpty;
    final isDefault = forceDefault || !hasPhoto;
    final imageUrl = isDefault ? u.defaultAvatar : u.profilePhotoPath!;

    return SizedBox(
      width: 36,
      height: 36,
      child: BlackGlass(
        radius: 18,
        borderOpacity: 0.25,
        opacity: 0.4,
        child: Center(
          child: ChatComposerAvatar(
            avatarUrl: imageUrl,
            isDefaultAvatar: isDefault,
          ),
        ),
      ),
    );
  }
}

class ChatComposerAvatar extends StatelessWidget {
  const ChatComposerAvatar({
    super.key,
    required this.avatarUrl,
    required this.isDefaultAvatar,
  });

  final String avatarUrl;
  final bool isDefaultAvatar;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.white.withOpacity(0.05),
      backgroundImage: null,
      child: SizedBox(
        width: 32,
        height: 32,
        child: ChaputCircleAvatar(
          isDefaultAvatar: isDefaultAvatar,
          imageUrl: avatarUrl,
          width: 32,
          height: 32,
          radius: 32,
          borderWidth: 0,
        ),
      ),
    );
  }
}

class _MessagesList extends StatefulWidget {
  const _MessagesList({
    required this.state,
    required this.viewerId,
    required this.ownerUser,
    required this.otherUser,
    required this.viewerUser,
    required this.isHidden,
    required this.isParticipant,
    required this.canReply,
    required this.onReply,
    required this.onToggleLike,
    required this.onLoadMore,
  });

  final ChaputMessagesState state;
  final String viewerId;
  final LiteUser? ownerUser;
  final LiteUser? otherUser;
  final LiteUser? viewerUser;
  final bool isHidden;
  final bool isParticipant;
  final bool canReply;
  final ValueChanged<ChaputMessage> onReply;
  final void Function(ChaputMessage message, bool like) onToggleLike;
  final VoidCallback onLoadMore;

  @override
  State<_MessagesList> createState() => _MessagesListState();
}

class _MessagesListState extends State<_MessagesList> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};
  bool _loadTriggered = false;
  String? _pendingJumpId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (widget.state.isLoading || widget.state.isLoadingMore) return;
    if (widget.state.nextCursor == null || widget.state.nextCursor!.isEmpty) return;
    final pos = _scrollController.position;
    final nearTop = pos.pixels >= pos.maxScrollExtent - 40;
    if (nearTop && !_loadTriggered) {
      _loadTriggered = true;
      widget.onLoadMore();
    }
    if (pos.pixels < pos.maxScrollExtent - 160) {
      _loadTriggered = false;
    }
  }

  GlobalKey _keyForMessage(String id) {
    if (id.isEmpty) return GlobalKey();
    return _messageKeys.putIfAbsent(id, () => GlobalKey());
  }

  void _jumpToMessage(String id) {
    final key = _messageKeys[id];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        alignment: 0.3,
      );
      _pendingJumpId = null;
      return;
    }
    if (widget.state.nextCursor != null && widget.state.nextCursor!.isNotEmpty) {
      _pendingJumpId = id;
      widget.onLoadMore();
    }
  }

  void _tryPendingJump() {
    final id = _pendingJumpId;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToMessage(id);
    });
  }

  void _openLikesFocus(ChaputMessage message, bool isMine, bool isParticipant) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'likes',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, a1, a2) {
        return _MessageLikesDialog(
          message: message,
          isMine: isMine,
          isParticipant: isParticipant,
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        return Opacity(
          opacity: anim.value,
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.state.items;
    if (widget.state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Henüz mesaj yok',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontWeight: FontWeight.w700),
        ),
      );
    }

    final groups = _groupMessages(items);
    final dayLabels = _buildDayLabels(context, groups);
    _tryPendingJump();

    final viewerNorm = widget.viewerId.toLowerCase();

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      itemCount: groups.length,
      itemBuilder: (ctx, i) {
        final g = groups[i];
        final isMine = g.senderId.toLowerCase() == viewerNorm;
        final senderUser = _resolveUser(g.senderId);
        final forceDefault = widget.isHidden && !widget.isParticipant && senderUser == widget.otherUser;
        final label = dayLabels[i];
        return _MessageGroupBubble(
          group: g,
          isMine: isMine,
          senderUser: senderUser,
          forceDefaultAvatar: forceDefault,
          isParticipant: widget.isParticipant,
          dayLabel: label,
          resolveUser: _resolveUser,
          canReply: widget.canReply,
          onReply: widget.onReply,
          onToggleLike: widget.onToggleLike,
          onShowLikes: (m) => _openLikesFocus(m, isMine, widget.isParticipant),
          onReplyTap: _jumpToMessage,
          messageKeyFor: _keyForMessage,
        );
      },
    );
  }

  List<String?> _buildDayLabels(BuildContext context, List<_MessageGroup> groups) {
    final labels = List<String?>.filled(groups.length, null, growable: false);
    for (int i = 0; i < groups.length; i++) {
      final g = groups[i];
      final dt = g.items.isNotEmpty
          ? (g.items.last.createdAt ?? g.items.first.createdAt)
          : null;
      final key = _dayKey(dt);
      final nextKey = (i + 1) < groups.length
          ? _dayKey(groups[i + 1].items.isNotEmpty
              ? (groups[i + 1].items.last.createdAt ?? groups[i + 1].items.first.createdAt)
              : null)
          : null;
      if (key != null && key != nextKey) {
        labels[i] = _formatDayLabel(context, dt!);
      }
    }
    return labels;
  }

  String? _dayKey(DateTime? dt) {
    if (dt == null) return null;
    final d = dt.toLocal();
    return '${d.year}-${d.month}-${d.day}';
  }

  String _formatDayLabel(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(that).inDays;
    if (diffDays == 0) return context.t('chat_today');
    if (diffDays == 1) return context.t('chat_yesterday');

    final monthName = context.t('month_${local.month}');
    if (local.year != now.year) {
      return context.t('chat_date_day_month_year', params: {
        'day': '${local.day}',
        'month': monthName,
        'year': '${local.year}',
      });
    }
    return context.t('chat_date_day_month', params: {
      'day': '${local.day}',
      'month': monthName,
    });
  }

  List<_MessageGroup> _groupMessages(List<ChaputMessage> items) {
    final groups = <_MessageGroup>[];
    const gapMinutes = 5;
    _MessageGroup? current;

    for (int i = 0; i < items.length; i++) {
      final msg = items[i];
      final prev = i > 0 ? items[i - 1] : null;
      final sameSender = prev != null && prev.senderId.toLowerCase() == msg.senderId.toLowerCase();
      final gapOk = prev?.createdAt != null && msg.createdAt != null
          ? prev!.createdAt!.difference(msg.createdAt!).abs().inMinutes <= gapMinutes
          : false;

      if (current == null || !sameSender || !gapOk) {
        current = _MessageGroup(senderId: msg.senderId, items: [msg]);
        groups.add(current);
      } else {
        current.items.add(msg);
      }
    }
    return groups;
  }

  LiteUser? _resolveUser(String id) {
    if (widget.ownerUser != null && widget.ownerUser!.id == id) return widget.ownerUser;
    if (widget.otherUser != null && widget.otherUser!.id == id) return widget.otherUser;
    if (widget.viewerUser != null && widget.viewerUser!.id == id) return widget.viewerUser;
    return null;
  }
}

class _MessageGroup {
  _MessageGroup({required this.senderId, required this.items});
  final String senderId;
  final List<ChaputMessage> items;
}

class _MessageGroupBubble extends StatelessWidget {
  const _MessageGroupBubble({
    required this.group,
    required this.isMine,
    required this.senderUser,
    required this.forceDefaultAvatar,
    required this.isParticipant,
    required this.dayLabel,
    required this.resolveUser,
    required this.canReply,
    required this.onReply,
    required this.onToggleLike,
    required this.onShowLikes,
    required this.onReplyTap,
    required this.messageKeyFor,
  });

  final _MessageGroup group;
  final bool isMine;
  final LiteUser? senderUser;
  final bool forceDefaultAvatar;
  final bool isParticipant;
  final String? dayLabel;
  final LiteUser? Function(String id) resolveUser;
  final bool canReply;
  final ValueChanged<ChaputMessage> onReply;
  final void Function(ChaputMessage message, bool like) onToggleLike;
  final ValueChanged<ChaputMessage> onShowLikes;
  final ValueChanged<String> onReplyTap;
  final GlobalKey Function(String id) messageKeyFor;

  @override
  Widget build(BuildContext context) {
    final orderedItems = group.items.reversed.toList(growable: false);
    final bubbleColumn = Column(
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < orderedItems.length; i++)
          _MessageBubble(
            key: messageKeyFor(orderedItems[i].id),
            message: orderedItems[i],
            isMine: isMine,
            isLastInGroup: i == orderedItems.length - 1,
            isParticipant: isParticipant,
            replyAuthor: _resolveReplyAuthor(orderedItems[i]),
            canReply: canReply,
            onReply: onReply,
            onToggleLike: onToggleLike,
            onShowLikes: onShowLikes,
            onReplyTap: onReplyTap,
          ),
      ],
    );

    final labelWidget = dayLabel == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.16)),
                ),
                child: Text(
                  dayLabel!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          );

    if (isMine) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              labelWidget,
              bubbleColumn,
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labelWidget,
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _GroupAvatar(user: senderUser, forceDefault: forceDefaultAvatar),
                const SizedBox(width: 8),
                Flexible(child: bubbleColumn),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _resolveReplyAuthor(ChaputMessage message) {
    final senderId = message.replyToSenderId;
    if (senderId == null || senderId.isEmpty) return '';
    final u = resolveUser(senderId);
    return u?.fullName ?? '';
  }
}

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.user, required this.forceDefault});

  final LiteUser? user;
  final bool forceDefault;

  @override
  Widget build(BuildContext context) {
    final u = user;
    if (u == null) {
      return const SizedBox(width: 28, height: 28);
    }
    final hasPhoto = u.profilePhotoPath != null && u.profilePhotoPath!.isNotEmpty;
    final isDefault = forceDefault || !hasPhoto;
    final imageUrl = isDefault ? u.defaultAvatar : u.profilePhotoPath!;
    return SizedBox(
      width: 28,
      height: 28,
      child: ChaputCircleAvatar(
        isDefaultAvatar: isDefault,
        imageUrl: imageUrl,
        width: 28,
        height: 28,
        radius: 28,
        borderWidth: 0,
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.isLastInGroup,
    required this.isParticipant,
    required this.replyAuthor,
    required this.canReply,
    required this.onReply,
    required this.onToggleLike,
    required this.onShowLikes,
    required this.onReplyTap,
    this.enableActions = true,
  });

  final ChaputMessage message;
  final bool isMine;
  final bool isLastInGroup;
  final bool isParticipant;
  final String replyAuthor;
  final bool canReply;
  final ValueChanged<ChaputMessage> onReply;
  final void Function(ChaputMessage message, bool like) onToggleLike;
  final ValueChanged<ChaputMessage> onShowLikes;
  final ValueChanged<String> onReplyTap;
  final bool enableActions;

  @override
  Widget build(BuildContext context) {
    final isWhisperHidden = message.kind == 'WHISPER_HIDDEN';
    final isWhisper = message.kind == 'WHISPER';
    final whisperBg = AppColors.chaputLightBlue;
    final whisperFg = Colors.black;
    final bg = isWhisper
        ? whisperBg
        : (isMine ? Colors.white : Colors.white.withOpacity(0.12));
    final fg = isWhisper ? whisperFg : (isMine ? Colors.black : Colors.white);

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(isMine ? 14 : (isLastInGroup ? 4 : 14)),
      bottomRight: Radius.circular(isMine ? (isLastInGroup ? 4 : 14) : 14),
    );

    final masked = '*' * (message.body.isEmpty ? 6 : message.body.length.clamp(4, 18));
    final displayText = (!isParticipant && (isWhisper || isWhisperHidden)) ? masked : message.body;
    final timeText = _formatTime(message.createdAt);
    final hasReply = message.replyToId != null &&
        message.replyToId!.isNotEmpty &&
        message.replyToBody != null &&
        message.replyToBody!.isNotEmpty;
    final hasLikes = message.likeCount > 0;
    final replyLabel = replyAuthor.isNotEmpty ? replyAuthor : 'Yanıt';
    final showTicks = isMine && timeText != null;
    final tickColor = message.readByOther ? Colors.lightBlueAccent : fg.withOpacity(0.45);
    final tickIcon = message.delivered ? Icons.done_all : Icons.check;

    final maxWidth = MediaQuery.of(context).size.width * 0.72;
    final replyBg = isMine ? Colors.black.withOpacity(0.18) : Colors.white.withOpacity(0.2);
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isWhisperHidden ? Colors.white.withOpacity(0.08) : bg,
        borderRadius: radius,
        border: Border.all(color: Colors.white.withOpacity(isMine ? 0.0 : 0.06)),
      ),
      child: IntrinsicWidth(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasReply)
                GestureDetector(
                  onTap: () {
                    final id = message.replyToId;
                    if (id != null && id.isNotEmpty) onReplyTap(id);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: replyBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.16)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                replyLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: fg.withOpacity(0.92),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                message.replyToBody ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: fg.withOpacity(0.7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Text(
                displayText,
                style: TextStyle(
                  color: isWhisperHidden ? Colors.white.withOpacity(0.7) : fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasLikes || timeText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasLikes)
                          _LikeStack(
                            likers: message.topLikers,
                            likeCount: message.likeCount,
                            onTap: () => onShowLikes(message),
                          ),
                        if (hasLikes && timeText != null) const SizedBox(width: 6),
                        if (timeText != null)
                          Text(
                            timeText,
                            style: TextStyle(
                              color: (isWhisperHidden ? Colors.white.withOpacity(0.45) : fg.withOpacity(0.45)),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (showTicks) ...[
                          const SizedBox(width: 4),
                          Icon(
                            tickIcon,
                            size: 12,
                            color: tickColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    Widget child = isWhisperHidden
        ? ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: bubble,
            ),
          )
        : bubble;

    child = Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      widthFactor: 1,
      child: child,
    );

    if (enableActions) {
      child = GestureDetector(
        onDoubleTap: () => onToggleLike(message, !message.likedByMe),
        onLongPress: () => onShowLikes(message),
        child: child,
      );
    }

    if (enableActions && canReply) {
      return Dismissible(
        key: ValueKey('reply_${message.id}'),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) async {
          onReply(message);
          return false;
        },
        background: const _ReplySwipeBackground(),
        child: child,
      );
    }

    return child;
  }

  String? _formatTime(DateTime? dt) {
    if (dt == null) return null;
    final d = dt.toLocal();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _LikeStack extends StatelessWidget {
  const _LikeStack({
    required this.likers,
    required this.likeCount,
    required this.onTap,
  });

  final List<ChaputMessageLiker> likers;
  final int likeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final top = likers.take(3).toList(growable: false);
    final overflow = (likeCount - top.length).clamp(0, 999);
    final size = 16.0;
    final overlap = 10.0;

    final stackWidth = (top.isEmpty ? 0 : (size + (top.length - 1) * overlap)) + (overflow > 0 ? size + 6 : 0);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: stackWidth.toDouble(),
        height: size,
        child: Stack(
          children: [
            for (int i = 0; i < top.length; i++)
              Positioned(
                left: i * overlap,
                child: _TinyAvatar(user: top[i], size: size),
              ),
            if (overflow > 0)
              Positioned(
                left: top.length * overlap + 4,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '+$overflow',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TinyAvatar extends StatelessWidget {
  const _TinyAvatar({required this.user, required this.size});

  final ChaputMessageLiker user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = user.profilePhotoPath != null && user.profilePhotoPath!.isNotEmpty;
    final isDefault = !hasPhoto;
    final imageUrl = isDefault ? user.defaultAvatar : user.profilePhotoPath!;
    return SizedBox(
      width: size,
      height: size,
      child: ChaputCircleAvatar(
        isDefaultAvatar: isDefault,
        imageUrl: imageUrl,
        width: size,
        height: size,
        radius: size,
        borderWidth: 0.5,
      ),
    );
  }
}

class _ReplySwipeBackground extends StatelessWidget {
  const _ReplySwipeBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 18),
      child: Icon(Icons.reply_rounded, color: Colors.white.withOpacity(0.7), size: 20),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.users});

  final List<LiteUser> users;

  @override
  Widget build(BuildContext context) {
    final shown = users.take(2).toList(growable: false);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < shown.length; i++)
          Padding(
            padding: EdgeInsets.only(right: i == shown.length - 1 ? 6 : 4),
            child: ChaputCircleAvatar(
              width: 18,
              height: 18,
              radius: 18,
              borderWidth: 0,
              isDefaultAvatar: shown[i].profilePhotoKey == null || shown[i].profilePhotoKey!.isEmpty,
              imageUrl: (shown[i].profilePhotoPath == null || shown[i].profilePhotoPath!.isEmpty)
                  ? shown[i].defaultAvatar
                  : shown[i].profilePhotoPath!,
            ),
          ),
        Text(
          '${shown.length} ${context.t('chat_typing')}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.65),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MessageLikesDialog extends ConsumerStatefulWidget {
  const _MessageLikesDialog({
    required this.message,
    required this.isMine,
    required this.isParticipant,
  });

  final ChaputMessage message;
  final bool isMine;
  final bool isParticipant;

  @override
  ConsumerState<_MessageLikesDialog> createState() => _MessageLikesDialogState();
}

class _MessageLikesDialogState extends ConsumerState<_MessageLikesDialog> {
  final List<ChaputMessageLiker> _items = [];
  final ScrollController _ctrl = ScrollController();
  String? _cursor;
  bool _loading = true;
  bool _loadingMore = false;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_handleScroll);
    _load();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_handleScroll);
    _ctrl.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_loading || _loadingMore) return;
    if (_cursor == null || _cursor!.isEmpty) return;
    if (!_ctrl.hasClients) return;
    final pos = _ctrl.position;
    final nearEnd = pos.pixels >= pos.maxScrollExtent - 60;
    if (nearEnd && !_triggered) {
      _triggered = true;
      _load(more: true);
    }
    if (pos.pixels < pos.maxScrollExtent - 160) {
      _triggered = false;
    }
  }

  Future<void> _load({bool more = false}) async {
    if (more) {
      setState(() => _loadingMore = true);
    } else {
      setState(() => _loading = true);
    }
    try {
      final api = ref.read(chaputApiProvider);
      final res = await api.listMessageLikes(
        messageIdHex: widget.message.id,
        limit: 30,
        cursor: more ? _cursor : null,
      );
      setState(() {
        if (more) {
          _items.addAll(res.items);
        } else {
          _items
            ..clear()
            ..addAll(res.items);
        }
        _cursor = res.nextCursor;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: w * 0.86,
                height: h * 0.65,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.82),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Column(
                  children: [
                    _MessageBubble(
                      message: widget.message,
                      isMine: widget.isMine,
                      isLastInGroup: true,
                      isParticipant: widget.isParticipant,
                      replyAuthor: '',
                      canReply: false,
                      onReply: (_) {},
                      onToggleLike: (_, __) {},
                      onShowLikes: (_) {},
                      onReplyTap: (_) {},
                      enableActions: false,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator(color: Colors.white))
                          : _items.isEmpty
                              ? Center(
                                  child: Text(
                                    context.t('chat_no_likes'),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  controller: _ctrl,
                                  itemCount: _items.length + (_loadingMore ? 1 : 0),
                                  separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.08)),
                                  itemBuilder: (ctx, i) {
                                    if (i >= _items.length) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10),
                                        child: Center(
                                          child: CircularProgressIndicator(color: Colors.white),
                                        ),
                                      );
                                    }
                                    final u = _items[i];
                                    final hasPhoto = u.profilePhotoPath != null && u.profilePhotoPath!.isNotEmpty;
                                    final isDefault = !hasPhoto;
                                    final imageUrl = isDefault ? u.defaultAvatar : u.profilePhotoPath!;
                                    return Row(
                                      children: [
                                        ChaputCircleAvatar(
                                          isDefaultAvatar: isDefault,
                                          imageUrl: imageUrl,
                                          width: 34,
                                          height: 34,
                                          radius: 34,
                                          borderWidth: 0,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                u.fullName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              if (u.username != null && u.username!.isNotEmpty)
                                                Text(
                                                  '@${u.username}',
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.6),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingNotice extends StatelessWidget {
  const _PendingNotice({required this.pendingUntil});
  final DateTime? pendingUntil;

  @override
  Widget build(BuildContext context) {
    final until = pendingUntil;
    final text = until != null
        ? 'Karşı tarafın yanıtı için ${_formatRemaining(until)} kaldı.'
        : 'Karşı tarafın yanıtı bekleniyor.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.65), fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
    );
  }

  String _formatRemaining(DateTime until) {
    final diff = until.toUtc().difference(DateTime.now().toUtc());
    final mins = diff.inMinutes;
    if (mins <= 0) return '0 dk';
    final hours = diff.inHours;
    if (hours >= 1) return '${hours} saat';
    return '${mins} dk';
  }
}

class _PendingReplyHint extends StatelessWidget {
  const _PendingReplyHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Text(
        'Cevap vermezsen bu chaput arşive gidebilir.',
        style: TextStyle(color: Colors.white.withOpacity(0.65), fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
