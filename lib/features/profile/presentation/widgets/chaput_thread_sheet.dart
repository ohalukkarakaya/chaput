import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../chaput/application/chaput_messages_controller.dart';
import '../../../../core/constants/app_colors.dart';
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
  });

  final List<ChaputThreadItem> threads;
  final Map<String, LiteUser> usersById;
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ChaputMessagesArgs(threadId: thread.threadId, profileId: profileId);
    final messagesState = ref.watch(chaputMessagesControllerProvider(args));
    final isHidden = thread.kind == 'HIDDEN';
    final viewerIsStarter = thread.starterId == viewerId;
    final isPending = thread.state == 'PENDING';

    final otherName = (isHidden && !isParticipant) ? 'Gizli Kullanıcı' : (otherUser?.fullName ?? '');
    final otherUsername = (isHidden && !isParticipant) ? null : otherUser?.username;

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

    final isDefault = forceDefault || u.profilePhotoKey == null || u.profilePhotoKey!.isEmpty;
    final imageUrl = isDefault ? u.defaultAvatar : u.profilePhotoKey!;

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

class _MessagesList extends StatelessWidget {
  const _MessagesList({
    required this.state,
    required this.viewerId,
    required this.ownerUser,
    required this.otherUser,
    required this.viewerUser,
    required this.isHidden,
    required this.isParticipant,
    required this.onLoadMore,
  });

  final ChaputMessagesState state;
  final String viewerId;
  final LiteUser? ownerUser;
  final LiteUser? otherUser;
  final LiteUser? viewerUser;
  final bool isHidden;
  final bool isParticipant;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final items = state.items;
    if (state.isLoading) {
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
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is! ScrollEndNotification) return false;
        if (state.isLoadingMore) return false;
        if (state.nextCursor == null || state.nextCursor!.isEmpty) return false;
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 20) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        itemCount: groups.length,
        itemBuilder: (ctx, i) {
          final g = groups[i];
          final isMine = g.senderId == viewerId;
          final senderUser = _resolveUser(g.senderId);
          final forceDefault = isHidden && !isParticipant && senderUser == otherUser;
          return _MessageGroupBubble(
            group: g,
            isMine: isMine,
            senderUser: senderUser,
            forceDefaultAvatar: forceDefault,
            isParticipant: isParticipant,
          );
        },
      ),
    );
  }

  List<_MessageGroup> _groupMessages(List<ChaputMessage> items) {
    final groups = <_MessageGroup>[];
    const gapMinutes = 5;
    _MessageGroup? current;

    for (int i = 0; i < items.length; i++) {
      final msg = items[i];
      final prev = i > 0 ? items[i - 1] : null;
      final sameSender = prev != null && prev.senderId == msg.senderId;
      final gapOk = prev?.createdAt != null && msg.createdAt != null
          ? prev!.createdAt!.difference(msg.createdAt!).inMinutes <= gapMinutes
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
    if (ownerUser != null && ownerUser!.id == id) return ownerUser;
    if (otherUser != null && otherUser!.id == id) return otherUser;
    if (viewerUser != null && viewerUser!.id == id) return viewerUser;
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
  });

  final _MessageGroup group;
  final bool isMine;
  final LiteUser? senderUser;
  final bool forceDefaultAvatar;
  final bool isParticipant;

  @override
  Widget build(BuildContext context) {
    final orderedItems = group.items.reversed.toList(growable: false);
    final bubbleColumn = Column(
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < orderedItems.length; i++)
          _MessageBubble(
            message: orderedItems[i],
            isMine: isMine,
            isLastInGroup: i == orderedItems.length - 1,
            isParticipant: isParticipant,
          ),
      ],
    );

    if (isMine) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(margin: const EdgeInsets.symmetric(vertical: 4), child: bubbleColumn),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _GroupAvatar(user: senderUser, forceDefault: forceDefaultAvatar),
            const SizedBox(width: 8),
            bubbleColumn,
          ],
        ),
      ),
    );
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
    final isDefault = forceDefault || u.profilePhotoKey == null || u.profilePhotoKey!.isEmpty;
    final imageUrl = isDefault ? u.defaultAvatar : u.profilePhotoKey!;
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
    required this.message,
    required this.isMine,
    required this.isLastInGroup,
    required this.isParticipant,
  });

  final ChaputMessage message;
  final bool isMine;
  final bool isLastInGroup;
  final bool isParticipant;

  @override
  Widget build(BuildContext context) {
    final isWhisperHidden = message.kind == 'WHISPER_HIDDEN';
    final isWhisper = message.kind == 'WHISPER';
    final whisperBg = isMine ? AppColors.chaputLightBlue : const Color(0xFF1B4B43);
    final whisperFg = isMine ? Colors.black : Colors.white;
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

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isWhisperHidden ? Colors.white.withOpacity(0.08) : bg,
        borderRadius: radius,
        border: Border.all(color: Colors.white.withOpacity(isMine ? 0.0 : 0.06)),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: isWhisperHidden ? Colors.white.withOpacity(0.7) : fg,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (isWhisperHidden) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: bubble,
        ),
      );
    }

    return bubble;
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
