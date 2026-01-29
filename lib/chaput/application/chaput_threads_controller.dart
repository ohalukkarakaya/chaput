import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/user/data/user_api_provider.dart';
import '../../features/user/domain/lite_user.dart';
import '../data/chaput_api.dart';
import '../domain/chaput_thread.dart';
import 'chaput_decision_controller.dart';

class ChaputThreadsArgs {
  ChaputThreadsArgs({
    required this.profileId,
    required this.viewerId,
    required this.ownerId,
    required this.restricted,
  });

  final String profileId;
  final String viewerId;
  final String ownerId;
  final bool restricted;

  @override
  bool operator ==(Object other) {
    return other is ChaputThreadsArgs &&
        other.profileId == profileId &&
        other.viewerId == viewerId &&
        other.ownerId == ownerId &&
        other.restricted == restricted;
  }

  @override
  int get hashCode => Object.hash(profileId, viewerId, ownerId, restricted);
}

class ChaputThreadsState {
  const ChaputThreadsState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.items = const [],
    this.usersById = const {},
    this.nextCursor,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final List<ChaputThreadItem> items;
  final Map<String, LiteUser> usersById;
  final String? nextCursor;

  ChaputThreadsState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    List<ChaputThreadItem>? items,
    Map<String, LiteUser>? usersById,
    String? nextCursor,
    bool clearError = false,
  }) {
    return ChaputThreadsState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      items: items ?? this.items,
      usersById: usersById ?? this.usersById,
      nextCursor: nextCursor ?? this.nextCursor,
    );
  }

  static const empty = ChaputThreadsState();
}

final chaputThreadsControllerProvider =
    AutoDisposeNotifierProviderFamily<ChaputThreadsController, ChaputThreadsState, ChaputThreadsArgs>(
  ChaputThreadsController.new,
);

class ChaputThreadsController extends AutoDisposeFamilyNotifier<ChaputThreadsState, ChaputThreadsArgs> {
  ChaputApi get _api => ref.read(chaputApiProvider);

  @override
  ChaputThreadsState build(ChaputThreadsArgs arg) {
    _loadInitial(arg);
    return ChaputThreadsState(isLoading: true);
  }

  Future<void> _loadInitial(ChaputThreadsArgs arg) async {
    try {
      final res = await _api.listThreads(profileIdHex: arg.profileId, limit: 20);
      final items = _reorder(res.items, arg);
      final users = await _hydrateUsers(items);
      state = state.copyWith(
        isLoading: false,
        items: items,
        usersById: users,
        nextCursor: res.nextCursor,
        clearError: true,
      );
    } catch (e, st) {
      log('chaput threads load error: $e', stackTrace: st);
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

    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final res = await _api.listThreads(
        profileIdHex: arg.profileId,
        limit: 20,
        cursor: state.nextCursor,
      );
      final all = [...state.items, ...res.items];
      final deduped = _dedupe(all);
      final reordered = _reorder(deduped, arg);
      final users = await _hydrateUsers(res.items, existing: state.usersById);
      state = state.copyWith(
        isLoadingMore: false,
        items: reordered,
        usersById: {...state.usersById, ...users},
        nextCursor: res.nextCursor,
        clearError: true,
      );
    } catch (e, st) {
      log('chaput threads loadMore error: $e', stackTrace: st);
      state = state.copyWith(isLoadingMore: false, error: 'load_more_failed');
    }
  }

  void updateThreadKind(String threadId, String kind) {
    if (threadId.isEmpty) return;
    final nextItems = state.items
        .map((t) => t.threadId == threadId ? t.copyWith(kind: kind) : t)
        .toList(growable: false);
    state = state.copyWith(items: nextItems);
  }

  void updateThreadState({
    required String threadId,
    required String newState,
    DateTime? pendingExpiresAt,
  }) {
    if (threadId.isEmpty) return;
    final nextItems = state.items
        .map((t) => t.threadId == threadId ? t.copyWith(state: newState, pendingExpiresAt: pendingExpiresAt) : t)
        .toList(growable: false);
    state = state.copyWith(items: nextItems);
  }

  List<ChaputThreadItem> _dedupe(List<ChaputThreadItem> items) {
    final seen = <String>{};
    final out = <ChaputThreadItem>[];
    for (final it in items) {
      if (it.threadId.isEmpty) continue;
      if (seen.add(it.threadId)) out.add(it);
    }
    return out;
  }

  List<ChaputThreadItem> _reorder(List<ChaputThreadItem> items, ChaputThreadsArgs arg) {
    if (items.isEmpty) return items;
    final owner = arg.ownerId;
    final viewer = arg.viewerId;

    final ourThread = items.where((t) =>
        (t.userAId == owner && t.userBId == viewer) || (t.userAId == viewer && t.userBId == owner)).toList();
    if (arg.restricted) {
      return ourThread;
    }

    final specials = items.where((t) => t.kind == 'SPECIAL' && !ourThread.contains(t)).toList();
    final rest = items.where((t) => !ourThread.contains(t) && !specials.contains(t)).toList();
    int byCreatedDesc(ChaputThreadItem a, ChaputThreadItem b) {
      final ta = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    }
    specials.sort(byCreatedDesc);
    rest.sort(byCreatedDesc);

    final ordered = <ChaputThreadItem>[];
    ordered.addAll(ourThread);
    ordered.addAll(specials);
    ordered.addAll(rest);
    return ordered;
  }

  Future<Map<String, LiteUser>> _hydrateUsers(
    List<ChaputThreadItem> items, {
    Map<String, LiteUser> existing = const {},
  }) async {
    final ids = <String>{};
    for (final t in items) {
      if (!existing.containsKey(t.userAId)) ids.add(t.userAId);
      if (!existing.containsKey(t.userBId)) ids.add(t.userBId);
    }
    if (ids.isEmpty) return {};

    final api = ref.read(userApiProvider);
    final res = await api.batchLite(userIds: ids.toList(growable: false));
    final map = <String, LiteUser>{};
    for (final u in res.items) {
      map[u.id] = u;
    }
    return map;
  }

  void addUsers(Map<String, LiteUser> users) {
    if (users.isEmpty) return;
    state = state.copyWith(usersById: {...state.usersById, ...users});
  }

  void addThreadOptimistic(ChaputThreadItem item, ChaputThreadsArgs arg) {
    if (item.threadId.isEmpty) return;
    final all = [item, ...state.items];
    final deduped = _dedupe(all);
    final reordered = _reorder(deduped, arg);
    state = state.copyWith(items: reordered);
  }
}
