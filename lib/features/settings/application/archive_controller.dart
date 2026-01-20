import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../user/data/user_api.dart';
import '../../user/data/user_api_provider.dart';
import '../../user/domain/lite_user.dart';
import '../data/archive_api.dart';
import '../domain/archive_chaput.dart';

class ArchiveState {
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  final List<ArchiveChaput> items;
  final Map<String, LiteUser> usersById;

  final String? nextCursor;

  // revive busy
  final String? revivingChaputId;

  const ArchiveState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.items = const [],
    this.usersById = const {},
    this.nextCursor,
    this.revivingChaputId,
  });

  ArchiveState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    List<ArchiveChaput>? items,
    Map<String, LiteUser>? usersById,
    String? nextCursor,
    String? revivingChaputId,
  }) {
    return ArchiveState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      items: items ?? this.items,
      usersById: usersById ?? this.usersById,
      nextCursor: nextCursor ?? this.nextCursor,
      revivingChaputId: revivingChaputId,
    );
  }
}

final archiveControllerProvider =
AutoDisposeNotifierProvider<ArchiveController, ArchiveState>(
  ArchiveController.new,
);

class ArchiveController extends AutoDisposeNotifier<ArchiveState> {
  static const _pageSize = 20;

  ArchiveApi get _api => ref.read(archiveApiProvider);
  UserApi get _userApi => ref.read(userApiProvider);

  @override
  ArchiveState build() {
    _loadInitial();
    return const ArchiveState(isLoading: true);
  }

  String _mapError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      final s = (data is Map) ? (data['error']?.toString() ?? '') : data?.toString() ?? '';
      if (s.contains('unauthorized')) return 'Oturum hatası. Tekrar giriş yapman gerekebilir.';
      if (s.contains('not_found')) return 'Bulunamadı.';
      if (s.contains('forbidden')) return 'Bu işlem için yetkin yok.';
      if (s.contains('not_archived')) return 'Bu chaput zaten arşivde değil.';
      if (s.contains('db_error')) return 'Sunucu hatası. Tekrar dene.';
      final code = e.response?.statusCode;
      return 'Hata ($code). Tekrar dene.';
    }
    final s = e.toString();
    if (s.contains('unauthorized')) return 'Oturum hatası.';
    return 'Bir şey ters gitti. Tekrar dene.';
  }

  Future<Map<String, LiteUser>> _hydrateUsers(List<String> ids) async {
    if (ids.isEmpty) return {};
    final res = await _userApi.batchLite(userIds: ids);
    final out = <String, LiteUser>{};
    for (final u in res.items) {
      out[u.id] = u;
    }
    return out;
  }

  Future<void> _loadInitial() async {
    try {
      final res = await _api.listArchived(limit: _pageSize, cursor: null);

      // newest first (created_at desc)
      final items = [...res.items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final authorIds = items.map((e) => e.authorId).toSet().toList(growable: false);
      final users = await _hydrateUsers(authorIds);

      state = state.copyWith(
        isLoading: false,
        error: null,
        items: items,
        usersById: users,
        nextCursor: res.nextCursor,
      );
    } catch (e, st) {
      log('archive initial load error: $e', stackTrace: st);
      state = state.copyWith(isLoading: false, error: _mapError(e));
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    await _loadInitial();
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore) return;
    if (state.nextCursor == null) return;

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final res = await _api.listArchived(limit: _pageSize, cursor: state.nextCursor);

      final added = res.items;
      final all = [...state.items, ...added];

      // dedupe by chaput id
      final seen = <String>{};
      final deduped = <ArchiveChaput>[];
      for (final c in all) {
        if (seen.add(c.id)) deduped.add(c);
      }
      deduped.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final newAuthorIds = added
          .map((e) => e.authorId)
          .where((id) => !state.usersById.containsKey(id))
          .toSet()
          .toList(growable: false);

      final newUsers = await _hydrateUsers(newAuthorIds);

      state = state.copyWith(
        isLoadingMore: false,
        items: deduped,
        usersById: {...state.usersById, ...newUsers},
        nextCursor: res.nextCursor,
      );
    } catch (e, st) {
      log('archive loadMore error: $e', stackTrace: st);
      state = state.copyWith(isLoadingMore: false, error: _mapError(e));
    }
  }

  Future<bool> revive(String chaputId) async {
    if (state.revivingChaputId != null) return false;

    state = state.copyWith(revivingChaputId: chaputId, error: null);

    try {
      await _api.reviveChaput(chaputIdHex: chaputId);

      // ✅ 200 -> listeden kaldır
      final nextItems = state.items.where((e) => e.id != chaputId).toList(growable: false);

      state = state.copyWith(
        revivingChaputId: null,
        items: nextItems,
      );
      return true;
    } catch (e) {
      state = state.copyWith(revivingChaputId: null, error: _mapError(e));
      return false;
    }
  }
}