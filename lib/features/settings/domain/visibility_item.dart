enum VisibilityKind { blocked, restricted }

class VisibilityItem {
  final String userId;
  final int createdAt; // unix seconds
  final VisibilityKind kind;
  final String? username;

  const VisibilityItem({
    required this.userId,
    required this.createdAt,
    required this.kind,
    this.username,
  });
}
