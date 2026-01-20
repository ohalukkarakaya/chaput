enum VisibilityKind { blocked, restricted }

class VisibilityItem {
  final String userId;
  final int createdAt; // unix seconds
  final VisibilityKind kind;

  const VisibilityItem({
    required this.userId,
    required this.createdAt,
    required this.kind,
  });
}