import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../user/data/user_api.dart';
import '../../user/data/user_api_provider.dart';
import '../../user/domain/lite_user.dart';
import '../data/follow_api.dart';
import 'follow_controller.dart';

enum FollowListKind { followers, following }

class FollowListItem {
  final String userId;
  final String username;
  final String fullName;
  final bool canOpenProfile;

  const FollowListItem({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.canOpenProfile,
  });
}

class FollowListState {
  final bool isLoading;
  final String? error;
  final bool isForbidden;
  final List<FollowListItem> items;
  final Map<String, LiteUser> usersById;
  final int nextAfter;
  final bool hasMore;

  const FollowListState({
    this.isLoading = false,
    this.error,
    this.isForbidden = false,
    this.items = const [],
    this.usersById = const {},
    this.nextAfter = 0,
    this.hasMore = true,
  });

  FollowListState copyWith({
    bool? isLoading,
    String? error,
    bool? isForbidden,
    List<FollowListItem>? items,
    Map<String, LiteUser>? usersById,
    int? nextAfter,
    bool? hasMore,
  }) {
    return FollowListState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isForbidden: isForbidden ?? this.isForbidden,
      items: items ?? this.items,
      usersById: usersById ?? this.usersById,
      nextAfter: nextAfter ?? this.nextAfter,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class FollowListArgs {
  final String username;
  final FollowListKind kind;

  const FollowListArgs({
    required this.username,
    required this.kind,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FollowListArgs &&
        other.username == username &&
        other.kind == kind;
  }

  @override
  int get hashCode => Object.hash(username, kind);
}

final followListControllerProvider =
AutoDisposeNotifierProviderFamily<FollowListController, FollowListState, FollowListArgs>(
  FollowListController.new,
);

class FollowListController extends AutoDisposeFamilyNotifier<FollowListState, FollowListArgs> {
  static const _pageSize = 20;

  FollowApi get _followApi => ref.read(followApiProvider);
  UserApi get _userApi => ref.read(userApiProvider);

  @override
  FollowListState build(FollowListArgs arg) {
    _loadInitial();
    return const FollowListState(isLoading: true);
  }

  Future<void> _loadInitial() async {
    try {
      final res = await _fetchPage(after: 0);
      final ids = res.items.map((e) => e.userId).toSet().toList(growable: false);
      final users = await _hydrateUsers(ids);

      state = state.copyWith(
        isLoading: false,
        error: null,
        isForbidden: false,
        items: res.items,
        usersById: users,
        nextAfter: res.nextAfter,
        hasMore: res.items.isNotEmpty && res.items.length == _pageSize && res.nextAfter > 0,
      );
    } catch (e, st) {
      if (_isForbiddenError(e)) {
        state = state.copyWith(
          isLoading: false,
          error: null,
          isForbidden: true,
          items: const [],
          usersById: const {},
          nextAfter: 0,
          hasMore: false,
        );
        return;
      }
      log('follow list initial load error: $e', stackTrace: st);
      state = state.copyWith(isLoading: false, error: e.toString(), hasMore: false, isForbidden: false);
    }
  }

  Future<({List<FollowListItem> items, int nextAfter})> _fetchPage({required int after}) async {
    final data = arg.kind == FollowListKind.followers
        ? await _followApi.listFollowers(username: arg.username, after: after, limit: _pageSize)
        : await _followApi.listFollowing(username: arg.username, after: after, limit: _pageSize);

    final items = data.items.map((e) {
      return FollowListItem(
        userId: e['user_id']?.toString() ?? '',
        username: e['username']?.toString() ?? '',
        fullName: e['full_name']?.toString() ?? '',
        canOpenProfile: e['can_open_profile'] == true,
      );
    }).where((e) => e.userId.isNotEmpty).toList(growable: false);

    return (items: items, nextAfter: data.nextAfter);
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
    state = state.copyWith(isLoading: true, error: null, isForbidden: false);
    await _loadInitial();
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.isForbidden) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _fetchPage(after: state.nextAfter);
      final merged = [...state.items, ...res.items];
      final ids = res.items.map((e) => e.userId).toSet().toList(growable: false);
      final users = await _hydrateUsers(ids);

      final mergedUsers = Map<String, LiteUser>.from(state.usersById);
      mergedUsers.addAll(users);

      state = state.copyWith(
        isLoading: false,
        items: merged,
        usersById: mergedUsers,
        nextAfter: res.nextAfter,
        hasMore: res.items.isNotEmpty && res.items.length == _pageSize && res.nextAfter > state.nextAfter,
      );
    } catch (e, st) {
      if (_isForbiddenError(e)) {
        state = state.copyWith(isLoading: false, hasMore: false, isForbidden: true);
        return;
      }
      log('follow list load more error: $e', stackTrace: st);
      state = state.copyWith(isLoading: false, error: e.toString(), hasMore: false, isForbidden: false);
    }
  }

  bool _isForbiddenError(Object e) {
    if (e is FollowForbidden) return true;
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 403) return true;
      final msg = e.message ?? '';
      if (msg.contains('403')) return true;
    }
    final msg = e.toString();
    return msg.contains('private_profile') || msg.contains('restricted') || msg.contains('blocked');
  }

  Future<void> removeFollower({
    required String ownerUsername,
    required String followerUsername,
    required String followerId,
  }) async {
    await _followApi.removeFollower(username: ownerUsername, followerUsername: followerUsername);
    final nextItems = state.items.where((e) => e.userId != followerId).toList(growable: false);
    final nextUsers = Map<String, LiteUser>.from(state.usersById)..remove(followerId);
    state = state.copyWith(items: nextItems, usersById: nextUsers);
  }
}
