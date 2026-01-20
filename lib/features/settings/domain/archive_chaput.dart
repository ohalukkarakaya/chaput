class ArchiveChaput {
  final String id; // chaput hex
  final String? text;
  final int createdAt;
  final String authorId;

  const ArchiveChaput({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.authorId,
  });

  factory ArchiveChaput.fromJson(Map<String, dynamic> json) {
    return ArchiveChaput(
      id: (json['id'] ?? '').toString(),
      text: json['text']?.toString(),
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      authorId: (json['author_id'] ?? '').toString(),
    );
  }
}