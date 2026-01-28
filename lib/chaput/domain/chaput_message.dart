class ChaputMessage {
  ChaputMessage({
    required this.id,
    required this.senderId,
    required this.kind,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String kind; // NORMAL/WHISPER/WHISPER_HIDDEN
  final String body;
  final DateTime? createdAt;

  factory ChaputMessage.fromJson(Map<String, dynamic> json) {
    DateTime? parseTime(dynamic v) {
      final s = v?.toString();
      if (s == null || s.isEmpty || s == 'null') return null;
      return DateTime.tryParse(s);
    }

    return ChaputMessage(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'NORMAL',
      body: json['body']?.toString() ?? '',
      createdAt: parseTime(json['created_at']),
    );
  }
}
