import 'dart:io';

import 'package:flutter/foundation.dart';

class PreparedPhotoUpload {
  const PreparedPhotoUpload({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

Future<PreparedPhotoUpload> prepareProfilePhotoUpload(String path) async {
  final result = await compute(_prepareProfilePhotoUpload, path);
  return PreparedPhotoUpload(
    bytes: result['bytes'] as Uint8List,
    filename: result['filename'] as String,
  );
}

Map<String, Object> _prepareProfilePhotoUpload(String path) {
  final sourceBytes = File(path).readAsBytesSync();
  if (sourceBytes.isEmpty) {
    throw Exception('image_decode_failed');
  }

  const maxPreparedUploadBytes = 8 * 1024 * 1024;
  if (sourceBytes.length > maxPreparedUploadBytes) {
    throw Exception('file_too_large');
  }

  return {'bytes': sourceBytes, 'filename': _uploadFilename(sourceBytes)};
}

String _uploadFilename(Uint8List bytes) {
  if (_startsWith(bytes, const [0xFF, 0xD8, 0xFF])) {
    return 'profile_photo.jpg';
  }
  if (_startsWith(bytes, const [0x89, 0x50, 0x4E, 0x47])) {
    return 'profile_photo.png';
  }
  if (_startsWith(bytes, const [0x52, 0x49, 0x46, 0x46]) &&
      bytes.length >= 12 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'profile_photo.webp';
  }
  return 'profile_photo_upload';
}

bool _startsWith(Uint8List bytes, List<int> signature) {
  if (bytes.length < signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return false;
  }
  return true;
}
