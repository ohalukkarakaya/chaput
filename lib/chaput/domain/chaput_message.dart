class ChaputMessage {
  ChaputMessage({
    required this.id,
    required this.senderId,
    required this.kind,
    required this.body,
    required this.createdAt,
    required this.replyToId,
    required this.replyToSenderId,
    required this.replyToBody,
    required this.likeCount,
    required this.likedByMe,
    required this.delivered,
    required this.readByOther,
    required this.topLikers,
  });

  final String id;
  final String senderId;
  final String kind; // NORMAL/WHISPER/WHISPER_HIDDEN
  final String body;
  final DateTime? createdAt;
  final String? replyToId;
  final String? replyToSenderId;
  final String? replyToBody;
  final int likeCount;
  final bool likedByMe;
  final bool delivered;
  final bool readByOther;
  final List<ChaputMessageLiker> topLikers;

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
      replyToId: json['reply_to_id']?.toString(),
      replyToSenderId: json['reply_to_sender_id']?.toString(),
      replyToBody: json['reply_to_body']?.toString(),
      likeCount: (json['like_count'] ?? 0) as int,
      likedByMe: json['liked_by_me'] == true,
      delivered: true,
      readByOther: json['read_by_other'] == true,
      topLikers: ((json['top_likers'] as List?) ?? const [])
          .map((e) => ChaputMessageLiker.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class ChaputMessageLiker {
  ChaputMessageLiker({
    required this.id,
    required this.username,
    required this.fullName,
    required this.defaultAvatar,
    required this.profilePhotoKey,
    required this.profilePhotoUrl,
  });

  final String id;
  final String? username;
  final String fullName;
  final String defaultAvatar;
  final String? profilePhotoKey;
  final String? profilePhotoUrl;

  factory ChaputMessageLiker.fromJson(Map<String, dynamic> json) {
    final idVal = json['id'] ?? json['user_id'];
    return ChaputMessageLiker(
      id: idVal?.toString() ?? '',
      username: json['username']?.toString(),
      fullName: json['full_name']?.toString() ?? '',
      defaultAvatar: json['default_avatar']?.toString() ?? '',
      profilePhotoKey: json['profile_photo_key']?.toString(),
      profilePhotoUrl: json['profile_photo_url']?.toString(),
    );
  }

  String? get profilePhotoPath {
    if (profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty) return profilePhotoUrl;
    if (profilePhotoKey != null && profilePhotoKey!.isNotEmpty) {
      if (profilePhotoKey!.contains('/')) return profilePhotoKey;
      return '/uploads/profile_photos/$profilePhotoKey';
    }
    return null;
  }
}
