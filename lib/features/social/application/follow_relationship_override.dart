import 'package:flutter_riverpod/flutter_riverpod.dart';

final followRelationshipOverridesProvider =
    NotifierProvider<
      FollowRelationshipOverridesController,
      Map<String, FollowRelationshipOverride>
    >(FollowRelationshipOverridesController.new);

class FollowRelationshipOverride {
  const FollowRelationshipOverride({
    required this.isFollowing,
    required this.requestPending,
  });

  final bool isFollowing;
  final bool requestPending;
}

class FollowRelationshipOverridesController
    extends Notifier<Map<String, FollowRelationshipOverride>> {
  @override
  Map<String, FollowRelationshipOverride> build() => const {};

  void setForUser({
    String? userId,
    String? username,
    required bool isFollowing,
    required bool requestPending,
  }) {
    final relation = FollowRelationshipOverride(
      isFollowing: isFollowing,
      requestPending: isFollowing ? false : requestPending,
    );
    final next = Map<String, FollowRelationshipOverride>.of(state);
    var changed = false;

    void setKey(String key) {
      final current = next[key];
      if (current?.isFollowing == relation.isFollowing &&
          current?.requestPending == relation.requestPending) {
        return;
      }
      next[key] = relation;
      changed = true;
    }

    final idKey = followRelationshipUserIdKey(userId);
    if (idKey != null) setKey(idKey);

    final usernameKey = followRelationshipUsernameKey(username);
    if (usernameKey != null) setKey(usernameKey);

    if (changed) state = Map.unmodifiable(next);
  }

  void clear() {
    if (state.isEmpty) return;
    state = const {};
  }
}

FollowRelationshipOverride? followRelationshipOverrideFor(
  Map<String, FollowRelationshipOverride> overrides, {
  String? userId,
  String? username,
}) {
  final idKey = followRelationshipUserIdKey(userId);
  if (idKey != null) {
    final byId = overrides[idKey];
    if (byId != null) return byId;
  }

  final usernameKey = followRelationshipUsernameKey(username);
  if (usernameKey != null) return overrides[usernameKey];

  return null;
}

String? followRelationshipUserIdKey(String? userId) {
  final normalized = userId?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  return 'id:$normalized';
}

String? followRelationshipUsernameKey(String? username) {
  var normalized = username?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  if (normalized.startsWith('@')) {
    normalized = normalized.substring(1).trim();
  }
  if (normalized.isEmpty) return null;
  return 'username:$normalized';
}
