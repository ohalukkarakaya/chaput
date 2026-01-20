class UploadPhotoResponse {
  final bool ok;
  final String photoKey;
  final String photoUrl;
  final int bytes;

  UploadPhotoResponse({
    required this.ok,
    required this.photoKey,
    required this.photoUrl,
    required this.bytes,
  });

  factory UploadPhotoResponse.fromJson(Map<String, dynamic> json) {
    return UploadPhotoResponse(
      ok: json['ok'] == true,
      photoKey: (json['photo_key'] ?? '').toString(),
      photoUrl: (json['photo_url'] ?? '').toString(),
      bytes: (json['bytes'] is int) ? json['bytes'] as int : int.tryParse('${json['bytes']}') ?? 0,
    );
  }
}