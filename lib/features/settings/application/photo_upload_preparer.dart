import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

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
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    throw Exception('image_decode_failed');
  }

  final oriented = img.bakeOrientation(decoded);
  final side = oriented.width < oriented.height
      ? oriented.width
      : oriented.height;
  final x = (oriented.width - side) ~/ 2;
  final y = (oriented.height - side) ~/ 2;

  img.Image working = img.copyCrop(
    oriented,
    x: x,
    y: y,
    width: side,
    height: side,
  );

  const targetBytes = 420 * 1024;
  final dimensions = <int>[1024, 896, 768, 640, 512];
  final qualities = <int>[86, 82, 78, 74, 70, 66, 62, 58];

  Uint8List best = Uint8List(0);

  for (final dimension in dimensions) {
    if (working.width != dimension) {
      working = img.copyResize(
        working,
        width: dimension,
        height: dimension,
        interpolation: img.Interpolation.average,
      );
    }

    for (final quality in qualities) {
      final encoded = img.encodeJpg(working, quality: quality);
      if (best.isEmpty || encoded.length < best.length) {
        best = encoded;
      }
      if (encoded.length <= targetBytes) {
        return {'bytes': encoded, 'filename': 'profile_photo.jpg'};
      }
    }
  }

  if (best.isEmpty) {
    throw Exception('image_encode_failed');
  }

  return {'bytes': best, 'filename': 'profile_photo.jpg'};
}
