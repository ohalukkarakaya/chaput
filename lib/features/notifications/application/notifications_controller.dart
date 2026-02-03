import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../user/data/user_api.dart';
import '../../user/data/user_api_provider.dart';
import '../../user/domain/lite_user.dart';
import '../data/notification_api_provider.dart';
import '../domain/notification_item.dart';

class NotificationsState {
  final bool isLoading;
  final String? error;
  final List<AppNotification> items;
  final Map<String, LiteUser> usersById;
  final String? nextCursor;
  final bool hasMore;

  const NotificationsState({
    this.isLoading = false,
    this.error,
    this.items = const [],
    this.usersById = const {},
    this.nextCursor,
    this.hasMore = true,
  });

  NotificationsState copyWith({
    bool? isLoading,
    String? error,
    List<AppNotification>? items,
    Map<String, LiteUser>? usersById,
    String? nextCursor,
    bool? hasMore,
  }) {
    return NotificationsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      items: items ?? this.items,
      usersById: usersById ?? this.usersById,
      nextCursor: nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

final notificationsControllerProvider =
    AutoDisposeNotifierProvider<NotificationsController, NotificationsState>(
  NotificationsController.new,
);

class NotificationsController extends AutoDisposeNotifier<NotificationsState> {
  static const _pageSize = 20;

  UserApi get _userApi => ref.read(userApiProvider);

  @override
  NotificationsState build() {
    _loadInitial();
    return const NotificationsState(isLoading: true);
  }

  Future<void> _loadInitial() async {
    try {
      final res = await _fetchPage(cursor: null);
      final users = await _hydrateUsers(_actorIds(res.items));
      state = state.copyWith(
        isLoading: false,
        error: null,
        items: res.items,
        usersById: users,
        nextCursor: res.nextCursor,
        hasMore: res.items.length == _pageSize && res.nextCursor != null,
      );
    } catch (e, st) {
      log('notifications initial error: $e', stackTrace: st);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<({List<AppNotification> items, String? nextCursor})> _fetchPage({
    required String? cursor,
  }) async {
    final res = await ref.read(notificationApiProvider).list(cursor: cursor, limit: _pageSize);
    final items = res.items
        .map(AppNotification.fromJson)
        .where((e) => e.id.isNotEmpty)
        .toList(growable: false);
    return (items: items, nextCursor: res.nextCursor);
  }

  List<String> _actorIds(List<AppNotification> items) {
    final out = <String>{};
    for (final it in items) {
      final id = it.actorId;
      if (id != null && id.isNotEmpty) out.add(id);
    }
    return out.toList(growable: false);
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

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _fetchPage(cursor: state.nextCursor);
      final merged = [...state.items, ...res.items];
      final users = await _hydrateUsers(_actorIds(res.items));
      final mergedUsers = Map<String, LiteUser>.from(state.usersById);
      mergedUsers.addAll(users);
      state = state.copyWith(
        isLoading: false,
        items: merged,
        usersById: mergedUsers,
        nextCursor: res.nextCursor,
        hasMore: res.items.length == _pageSize && res.nextCursor != null,
      );
    } catch (e, st) {
      log('notifications load more error: $e', stackTrace: st);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void addFromSocket(AppNotification notif) {
    final exists = state.items.any((e) => e.id == notif.id);
    if (exists) return;
    state = state.copyWith(items: [notif, ...state.items]);
  }

  Future<void> ensureActorLoaded(String? actorId) async {
    if (actorId == null || actorId.isEmpty) return;
    if (state.usersById.containsKey(actorId)) return;
    final users = await _hydrateUsers([actorId]);
    if (users.isEmpty) return;
    final merged = Map<String, LiteUser>.from(state.usersById)..addAll(users);
    state = state.copyWith(usersById: merged);
  }

  Future<void> markRead(String id) async {
    await ref.read(notificationApiProvider).markRead(id);
    final nextItems = state.items.map((e) {
      if (e.id != id) return e;
      return AppNotification(
        id: e.id,
        userId: e.userId,
        actorId: e.actorId,
        type: e.type,
        payload: e.payload,
        profileId: e.profileId,
        threadId: e.threadId,
        createdAt: e.createdAt,
        readAt: DateTime.now(),
      );
    }).toList(growable: false);
    state = state.copyWith(items: nextItems);
  }

  void removeLocal(String id) {
    if (id.isEmpty) return;
    final nextItems = state.items.where((e) => e.id != id).toList(growable: false);
    if (nextItems.length == state.items.length) return;
    state = state.copyWith(items: nextItems);
  }

  void replaceWithFollowed(AppNotification it) {
    final nextItems = state.items.map((e) {
      if (e.id != it.id) return e;
      return AppNotification(
        id: e.id,
        userId: e.userId,
        actorId: e.actorId,
        type: 'followed',
        payload: const {},
        profileId: e.profileId,
        threadId: e.threadId,
        createdAt: e.createdAt,
        readAt: DateTime.now(),
      );
    }).toList(growable: false);
    state = state.copyWith(items: nextItems);
  }
}
