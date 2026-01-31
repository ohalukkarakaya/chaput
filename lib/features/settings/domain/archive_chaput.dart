class ArchiveChaput {
  final String threadId;
  final String otherUserId;
  final String starterId;
  final String kind;
  final String? archivedAt;

  const ArchiveChaput({
    required this.threadId,
    required this.otherUserId,
    required this.starterId,
    required this.kind,
    required this.archivedAt,
  });

  factory ArchiveChaput.fromJson(Map<String, dynamic> json) {
    return ArchiveChaput(
      threadId: (json['thread_id'] ?? '').toString(),
      otherUserId: (json['other_user_id'] ?? '').toString(),
      starterId: (json['starter_id'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      archivedAt: json['archived_at']?.toString(),
    );
  }
}
