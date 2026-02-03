class AppNotification {
  final String id;
  final String userId;
  final String? actorId;
  final String type;
  final Map<String, dynamic> payload;
  final String? profileId;
  final String? threadId;
  final DateTime? createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.actorId,
    required this.type,
    required this.payload,
    required this.profileId,
    required this.threadId,
    required this.createdAt,
    required this.readAt,
  });

  bool get isRead => readAt != null;

  static DateTime? _parseDate(dynamic v) {
    final s = v?.toString();
    if (s == null || s.isEmpty || s == 'null') return null;
    return DateTime.tryParse(s);
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      actorId: json['actor_id']?.toString(),
      type: json['type']?.toString() ?? '',
      payload: (json['payload'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? const {},
      profileId: json['profile_id']?.toString(),
      threadId: json['thread_id']?.toString(),
      createdAt: _parseDate(json['created_at']),
      readAt: _parseDate(json['read_at']),
    );
  }
}
