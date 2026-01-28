class ChaputThreadItem {
  ChaputThreadItem({
    required this.threadId,
    required this.userAId,
    required this.userBId,
    required this.starterId,
    required this.kind,
    required this.state,
    required this.lastMessageAt,
    required this.pendingExpiresAt,
    required this.createdAt,
    required this.x,
    required this.y,
    required this.z,
  });

  final String threadId;
  final String userAId;
  final String userBId;
  final String starterId;
  final String kind; // NORMAL/HIDDEN/SPECIAL
  final String state; // PENDING/OPEN/ARCHIVED
  final DateTime? lastMessageAt;
  final DateTime? pendingExpiresAt;
  final DateTime? createdAt;
  final double? x;
  final double? y;
  final double? z;

  ChaputThreadItem copyWith({
    String? kind,
    String? state,
    DateTime? lastMessageAt,
    DateTime? pendingExpiresAt,
    DateTime? createdAt,
    double? x,
    double? y,
    double? z,
  }) {
    return ChaputThreadItem(
      threadId: threadId,
      userAId: userAId,
      userBId: userBId,
      starterId: starterId,
      kind: kind ?? this.kind,
      state: state ?? this.state,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      pendingExpiresAt: pendingExpiresAt ?? this.pendingExpiresAt,
      createdAt: createdAt ?? this.createdAt,
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
    );
  }

  factory ChaputThreadItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseTime(dynamic v) {
      final s = v?.toString();
      if (s == null || s.isEmpty || s == 'null') return null;
      return DateTime.tryParse(s);
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return ChaputThreadItem(
      threadId: json['thread_id']?.toString() ?? '',
      userAId: json['user_a_id']?.toString() ?? '',
      userBId: json['user_b_id']?.toString() ?? '',
      starterId: json['starter_id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'NORMAL',
      state: json['state']?.toString() ?? 'OPEN',
      lastMessageAt: parseTime(json['last_message_at']),
      pendingExpiresAt: parseTime(json['pending_expires_at']),
      createdAt: parseTime(json['created_at']),
      x: parseDouble(json['x']),
      y: parseDouble(json['y']),
      z: parseDouble(json['z']),
    );
  }

  bool hasCoords() => x != null && y != null && z != null;
}
