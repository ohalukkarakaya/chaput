import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/user_search_api.dart';
import '../domain/user_search_models.dart';

enum UserSearchMode { discover, search }

class UserSearchState {
  final String query;
  final List<UserSearchItem> items;
  final String? nextCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final UserSearchMode mode;

  const UserSearchState({
    required this.query,
    required this.items,
    required this.nextCursor,
    required this.isLoading,
    required this.isLoadingMore,
    required this.error,
    required this.mode,
  });

  const UserSearchState.initial()
    : query = '',
      items = const [],
      nextCursor = null,
      isLoading = false,
      isLoadingMore = false,
      error = null,
      mode = UserSearchMode.discover;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;

  UserSearchState copyWith({
    String? query,
    List<UserSearchItem>? items,
    String? nextCursor,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    UserSearchMode? mode,
  }) {
    return UserSearchState(
      query: query ?? this.query,
      items: items ?? this.items,
      nextCursor: nextCursor,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      mode: mode ?? this.mode,
    );
  }
}

final userSearchControllerProvider =
    NotifierProvider<UserSearchController, UserSearchState>(
      UserSearchController.new,
    );

class UserSearchController extends Notifier<UserSearchState> {
  static const int _limit = 20;

  @override
  UserSearchState build() => const UserSearchState.initial();

  void clear() {
    state = const UserSearchState.initial();
  }

  Future<void> loadDiscoverFirstPage() async {
    state = state.copyWith(
      query: '',
      mode: UserSearchMode.discover,
      isLoading: true,
      isLoadingMore: false,
      error: null,
      items: const [],
      nextCursor: null,
    );

    try {
      final api = ref.read(userSearchApiProvider);
      final res = await api.discover(limit: _limit);

      log(
        'USER_DISCOVER firstPage: items=${res.items.length} next=${res.nextCursor}',
      );

      state = state.copyWith(
        items: res.items,
        nextCursor: res.nextCursor,
        isLoading: false,
        error: null,
      );
    } on DioException catch (e, st) {
      log('USER_DISCOVER: firstPage error', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, error: _extractError(e));
    } catch (e, st) {
      log('USER_DISCOVER: firstPage unknown', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, error: 'unknown_error');
    }
  }

  Future<void> searchFirstPage(String q) async {
    final qq = q.trim();

    if (qq.isEmpty) {
      return loadDiscoverFirstPage();
    }

    state = state.copyWith(
      query: qq,
      mode: UserSearchMode.search,
      isLoading: true,
      isLoadingMore: false,
      error: null,
      items: const [],
      nextCursor: null,
    );

    try {
      final api = ref.read(userSearchApiProvider);
      final res = await api.search(q: qq, limit: _limit);

      log(
        'USER_SEARCH firstPage: q="$qq" items=${res.items.length} next=${res.nextCursor}',
      );

      state = state.copyWith(
        items: res.items,
        nextCursor: res.nextCursor,
        isLoading: false,
        error: null,
      );
    } on DioException catch (e, st) {
      log('USER_SEARCH: firstPage error', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, error: _extractError(e));
    } catch (e, st) {
      log('USER_SEARCH: firstPage unknown', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, error: 'unknown_error');
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore) return;

    final cursor = state.nextCursor;

    if (cursor == null || cursor.isEmpty) return;

    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final api = ref.read(userSearchApiProvider);
      late final UserSearchResponse res;
      if (state.mode == UserSearchMode.discover) {
        res = await api.discover(limit: _limit, cursor: cursor);
        log(
          'USER_DISCOVER loadMore: added=${res.items.length} next=${res.nextCursor}',
        );
      } else {
        final q = state.query.trim();
        if (q.isEmpty) {
          state = state.copyWith(isLoadingMore: false);
          return;
        }
        res = await api.search(q: q, limit: _limit, cursor: cursor);
        log(
          'USER_SEARCH loadMore: q="$q" added=${res.items.length} next=${res.nextCursor}',
        );
      }

      state = state.copyWith(
        items: [...state.items, ...res.items],
        nextCursor: res.nextCursor,
        isLoadingMore: false,
        error: null,
      );
    } on DioException catch (e, st) {
      log('USER_SEARCH: loadMore error', error: e, stackTrace: st);
      state = state.copyWith(isLoadingMore: false, error: _extractError(e));
    } catch (e, st) {
      log('USER_SEARCH: loadMore unknown', error: e, stackTrace: st);
      state = state.copyWith(isLoadingMore: false, error: 'unknown_error');
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    if (e.response?.statusCode == 401) return 'unauthorized';
    if (e.response?.statusCode == 403) return 'forbidden';
    return 'network_or_server_error';
  }
}
