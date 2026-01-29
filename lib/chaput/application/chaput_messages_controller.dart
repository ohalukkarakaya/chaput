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

  List<ChaputMessage> _dedupe(List<ChaputMessage> items) {
    final seen = <String>{};
    final out = <ChaputMessage>[];
    for (final it in items) {
      if (it.id.isEmpty) continue;
      if (seen.add(it.id)) out.add(it);
    }
    return out;
  }
}
