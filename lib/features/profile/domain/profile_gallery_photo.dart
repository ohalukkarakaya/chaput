class ProfileGalleryPhoto {
  const ProfileGalleryPhoto({
    required this.id,
    required this.photoKey,
    required this.photoUrl,
    required this.sortOrder,
  });

  final String id;
  final String photoKey;
  final String photoUrl;
  final int sortOrder;

  factory ProfileGalleryPhoto.fromJson(Map<String, dynamic> json) {
    return ProfileGalleryPhoto(
      id: json['id']?.toString() ?? '',
      photoKey: json['photo_key']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString() ?? '',
      sortOrder: switch (json['sort_order']) {
        int value => value,
        num value => value.toInt(),
        _ => int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'photo_key': photoKey,
      'photo_url': photoUrl,
      'sort_order': sortOrder,
    };
  }

  static List<ProfileGalleryPhoto> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final out = <ProfileGalleryPhoto>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final photo = ProfileGalleryPhoto.fromJson(
        item.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (photo.id.isNotEmpty && photo.photoUrl.isNotEmpty) {
        out.add(photo);
      }
    }
    out.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return a.id.compareTo(b.id);
    });
    return out.length <= 3 ? out : out.take(3).toList(growable: false);
  }
}
