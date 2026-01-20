import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../user/data/user_api.dart';
import '../../user/data/user_api_provider.dart';
import '../../user/domain/lite_user.dart';
import '../data/blocks_api.dart';
import '../data/restrictions_api.dart';
import '../domain/visibility_item.dart';

class VisibilityState {
  final bool isLoading;
  final String? error;

  final List<VisibilityItem> items; // merged & sorted
  final Map<String, LiteUser> usersById;

  // pagination state (şimdilik simple)
  final int nextBlocksAfter;
  final String? nextRestrictionsCursor;
  final bool hasMoreBlocks;
  final bool hasMoreRestrictions;

  const VisibilityState({
    this.isLoading = false,
    this.error,
    this.items = const [],
    this.usersById = const {},
    this.nextBlocksAfter = 0,
    this.nextRestrictionsCursor,
    this.hasMoreBlocks = true,
    this.hasMoreRestrictions = true,
  });

  VisibilityState copyWith({
    bool? isLoading,
    String? error,
    List<VisibilityItem>? items,
    Map<String, LiteUser>? usersById,
    int? nextBlocksAfter,
    String? nextRestrictionsCursor,
    bool? hasMoreBlocks,
    bool? hasMoreRestrictions,
  }) {
    return VisibilityState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      items: items ?? this.items,
      usersById: usersById ?? this.usersById,
      nextBlocksAfter: nextBlocksAfter ?? this.nextBlocksAfter,
      nextRestrictionsCursor: nextRestrictionsCursor ?? this.nextRestrictionsCursor,
      hasMoreBlocks: hasMoreBlocks ?? this.hasMoreBlocks,
      hasMoreRestrictions: hasMoreRestrictions ?? this.hasMoreRestrictions,
    );
  }
}

final visibilityControllerProvider =
AutoDisposeNotifierProvider<VisibilityController, VisibilityState>(
  VisibilityController.new,
);

class VisibilityController extends AutoDisposeNotifier<VisibilityState> {
  static const _pageSize = 20;

  BlocksApi get _blocks => ref.read(blocksApiProvider);
  RestrictionsApi get _restrictions => ref.read(restrictionsApiProvider);
  UserApi get _userApi => ref.read(userApiProvider);

  @override
  VisibilityState build() {
    // ilk load
    _loadInitial();
    return const VisibilityState(isLoading: true);
  }

  Future<void> _loadInitial() async {
    try {
      final blocksF = _blocks.list(after: 0, limit: _pageSize);
      final restrF = _restrictions.list(limit: _pageSize, cursor: null);

      final results = await Future.wait([blocksF, restrF]);

      final blocksRes = results[0] as ({List<Map<String, dynamic>> items, int nextAfter});
      final restrRes = results[1] as ({List<Map<String, dynamic>> items, String? nextCursor});

      final merged = <VisibilityItem>[
        ...blocksRes.items.map((e) => VisibilityItem(
          userId: e['user_id']?.toString() ?? '',
          createdAt: (e['created_at'] as num?)?.toInt() ?? 0,
          kind: VisibilityKind.blocked,
        )),
        ...restrRes.items.map((e) => VisibilityItem(
          userId: e['user_id']?.toString() ?? '',
          createdAt: (e['created_at'] as num?)?.toInt() ?? 0,
          kind: VisibilityKind.restricted,
        )),
      ].where((e) => e.userId.isNotEmpty).toList(growable: false);

      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // newest first

      final ids = merged.map((e) => e.userId).toSet().toList(growable: false);
      final users = await _hydrateUsers(ids);

      state = state.copyWith(
        isLoading: false,
        error: null,
        items: merged,
        usersById: users,
        nextBlocksAfter: blocksRes.nextAfter,
        nextRestrictionsCursor: restrRes.nextCursor,
        hasMoreBlocks: blocksRes.items.length == _pageSize,
        hasMoreRestrictions: restrRes.items.length == _pageSize && restrRes.nextCursor != null,
      );
    } catch (e, st) {
      log('visibility initial load error: $e', stackTrace: st);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Map<String, LiteUser>> _hydrateUsers(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final res = await _userApi.batchLite(userIds: userIds);
    final map = <String, LiteUser>{};
    for (final u in res.items) {
      map[u.id] = u;
    }
    return map;
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    await _loadInitial();
  }

  // “Load more” (şimdilik ikisini de çekmeye çalışır, gelenleri merge eder)
  Future<void> loadMore() async {
    if (state.isLoading) return;
    if (!state.hasMoreBlocks && !state.hasMoreRestrictions) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final futures = <Future>[];

      Future<({List<Map<String, dynamic>> items, int nextAfter})>? blocksF;
      Future<({List<Map<String, dynamic>> items, String? nextCursor})>? restrF;

      if (state.hasMoreBlocks) {
        blocksF = _blocks.list(after: state.nextBlocksAfter, limit: _pageSize);
        futures.add(blocksF);
      }
      if (state.hasMoreRestrictions) {
        restrF = _restrictions.list(limit: _pageSize, cursor: state.nextRestrictionsCursor);
        futures.add(restrF);
      }

      final results = await Future.wait(futures);

      // parse results robust
      ({List<Map<String, dynamic>> items, int nextAfter})? blocksRes;
      ({List<Map<String, dynamic>> items, String? nextCursor})? restrRes;

      for (final r in results) {
        if (r is ({List<Map<String, dynamic>> items, int nextAfter})) blocksRes = r;
        if (r is ({List<Map<String, dynamic>> items, String? nextCursor})) restrRes = r;
      }

      final added = <VisibilityItem>[];

      if (blocksRes != null) {
        added.addAll(blocksRes.items.map((e) => VisibilityItem(
          userId: e['user_id']?.toString() ?? '',
          createdAt: (e['created_at'] as num?)?.toInt() ?? 0,
          kind: VisibilityKind.blocked,
        )));
      }
      if (restrRes != null) {
        added.addAll(restrRes.items.map((e) => VisibilityItem(
          userId: e['user_id']?.toString() ?? '',
          createdAt: (e['created_at'] as num?)?.toInt() ?? 0,
          kind: VisibilityKind.restricted,
        )));
      }

      final all = [...state.items, ...added]
          .where((e) => e.userId.isNotEmpty)
          .toList(growable: false);

      // dedupe (aynı userId + kind + createdAt)
      final seen = <String>{};
      final deduped = <VisibilityItem>[];
      for (final it in all) {
        final key = '${it.userId}|${it.kind}|${it.createdAt}';
        if (seen.add(key)) deduped.add(it);
      }
      deduped.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final newIds = added.map((e) => e.userId).where((id) => !state.usersById.containsKey(id)).toSet().toList();
      final newUsers = await _hydrateUsers(newIds);

      state = state.copyWith(
        isLoading: false,
        error: null,
        items: deduped,
        usersById: {...state.usersById, ...newUsers},
        nextBlocksAfter: blocksRes?.nextAfter ?? state.nextBlocksAfter,
        nextRestrictionsCursor: restrRes?.nextCursor ?? state.nextRestrictionsCursor,
        hasMoreBlocks: blocksRes == null ? state.hasMoreBlocks : blocksRes.items.length == _pageSize,
        hasMoreRestrictions: restrRes == null
            ? state.hasMoreRestrictions
            : (restrRes.items.length == _pageSize && restrRes.nextCursor != null),
      );
    } catch (e, st) {
      log('visibility loadMore error: $e', stackTrace: st);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}