import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chaput_api.dart';
import '../domain/chaput_message.dart';
import 'chaput_decision_controller.dart';

class ChaputMessagesArgs {
  ChaputMessagesArgs({
    required this.threadId,
    required this.profileId,
  });

  final String threadId;
  final String profileId;

  @override
  bool operator ==(Object other) {
    return other is ChaputMessagesArgs &&
        other.threadId == threadId &&
        other.profileId == profileId;
  }

  @override
  int get hashCode => Object.hash(threadId, profileId);
}

class ChaputMessagesState {
  const ChaputMessagesState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.items = const [],
    this.nextCursor,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final List<ChaputMessage> items; // newest first
  final String? nextCursor;

  ChaputMessagesState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    List<ChaputMessage>? items,
    String? nextCursor,
    bool clearError = false,
  }) {
    return ChaputMessagesState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      items: items ?? this.items,
      nextCursor: nextCursor ?? this.nextCursor,
    );
  }
}

final chaputMessagesControllerProvider = AutoDisposeNotifierProviderFamily<
    ChaputMessagesController,
    ChaputMessagesState,
    ChaputMessagesArgs>(ChaputMessagesController.new);

class ChaputMessagesController extends AutoDisposeFamilyNotifier<ChaputMessagesState, ChaputMessagesArgs> {
  ChaputApi get _api => ref.read(chaputApiProvider);
  String? _lastLoadCursor;

  @override
  ChaputMessagesState build(ChaputMessagesArgs arg) {
    _loadInitial(arg);
    return const ChaputMessagesState(isLoading: true);
  }

  Future<void> _loadInitial(ChaputMessagesArgs arg) async {
    try {
      final res = await _api.listMessages(
        threadIdHex: arg.threadId,
        profileIdHex: arg.profileId,
        limit: 30,
      );
      state = state.copyWith(
        isLoading: false,
        items: res.items,
        nextCursor: res.nextCursor,
        clearError: true,
      );
    } catch (e, st) {
      log('chaput messages load error: $e', stackTrace: st);
      state = state.copyWith(isLoading: false, error: 'load_failed');
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _loadInitial(arg);
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore) return;
    if (state.nextCursor == null || state.nextCursor!.isEmpty) return;
    if (_lastLoadCursor == state.nextCursor) return;
    _lastLoadCursor = state.nextCursor;

    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final res = await _api.listMessages(
        threadIdHex: arg.threadId,
        profileIdHex: arg.profileId,
        limit: 30,
        cursor: state.nextCursor,
      );
      final items = [...state.items, ...res.items];
      final nextCursor = (res.items.isEmpty || res.nextCursor == state.nextCursor) ? null : res.nextCursor;
      state = state.copyWith(
        isLoadingMore: false,
        items: _dedupe(items),
        nextCursor: nextCursor,
        clearError: true,
      );
    } catch (e, st) {
      log('chaput messages loadMore error: $e', stackTrace: st);
      state = state.copyWith(isLoadingMore: false, error: 'load_more_failed');
    }
  }

  void addLocalMessage(ChaputMessage message) {
    state = state.copyWith(items: [message, ...state.items]);
  }

  Future<void> toggleLike({
    required String messageId,
    required bool like,
    ChaputMessageLiker? me,
  }) async {
    final before = state.items;
    state = state.copyWith(items: _applyLikeOptimistic(before, messageId, like, me));
    if (messageId.length != 32) return;
    try {
      final res = await _api.likeMessage(messageIdHex: messageId, like: like);
      if (res.likeCount >= 0) {
        state = state.copyWith(
          items: _applyLikeServer(state.items, messageId, res.likeCount, res.likedByMe),
        );
      }
    } catch (e, st) {
      log('chaput like error: $e', stackTrace: st);
      state = state.copyWith(items: before);
    }
  }

  List<ChaputMessage> _applyLikeOptimistic(
    List<ChaputMessage> items,
    String messageId,
    bool like,
    ChaputMessageLiker? me,
  ) {
    return items.map((m) {
      if (m.id != messageId) return m;
      final wasLiked = m.likedByMe;
      final nextLiked = like;
      var nextCount = m.likeCount;
      if (like && !wasLiked) nextCount += 1;
      if (!like && wasLiked) nextCount = (nextCount - 1).clamp(0, 1 << 30);

      var nextTop = m.topLikers;
      if (me != null) {
        if (like) {
          if (!nextTop.any((u) => u.id == me.id)) {
            nextTop = [me, ...nextTop];
          }
        } else {
          nextTop = nextTop.where((u) => u.id != me.id).toList(growable: false);
        }
        if (nextTop.length > 3) {
          nextTop = nextTop.take(3).toList(growable: false);
        }
      }

      return _copyMessage(
        m,
        likeCount: nextCount,
        likedByMe: nextLiked,
        topLikers: nextTop,
      );
    }).toList(growable: false);
  }

  List<ChaputMessage> _applyLikeServer(
    List<ChaputMessage> items,
    String messageId,
    int likeCount,
    bool likedByMe,
  ) {
    return items.map((m) {
      if (m.id != messageId) return m;
      return _copyMessage(
        m,
        likeCount: likeCount,
        likedByMe: likedByMe,
      );
    }).toList(growable: false);
  }

  List<ChaputMessage> _dedupe(List<ChaputMessage> items) {
    final seen = <String>{};
    final out = <ChaputMessage>[];
    for (final it in items) {
      if (it.id.isEmpty) continue;
      if (seen.add(it.id)) out.add(it);
    }
    return out;
  }

  ChaputMessage _copyMessage(
    ChaputMessage m, {
    int? likeCount,
    bool? likedByMe,
    List<ChaputMessageLiker>? topLikers,
  }) {
    return ChaputMessage(
      id: m.id,
      senderId: m.senderId,
      kind: m.kind,
      body: m.body,
      createdAt: m.createdAt,
      replyToId: m.replyToId,
      replyToSenderId: m.replyToSenderId,
      replyToBody: m.replyToBody,
      likeCount: likeCount ?? m.likeCount,
      likedByMe: likedByMe ?? m.likedByMe,
      topLikers: topLikers ?? m.topLikers,
    );
  }
}
