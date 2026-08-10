import 'dart:io';
import 'dart:typed_data';

import 'package:chaput/features/settings/application/photo_upload_preparer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'prepareProfilePhotoUpload preserves picker-provided image bytes',
    () async {
      final dir = await Directory.systemTemp.createTemp('photo-preparer-test-');
      addTearDown(() => dir.delete(recursive: true));

      final bytes = Uint8List.fromList(const [
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        0x00,
        0x10,
        0x4A,
        0x46,
        0x49,
        0x46,
        0x00,
        0x01,
      ]);
      final file = File('${dir.path}/picked.jpg');
      await file.writeAsBytes(bytes);

      final prepared = await prepareProfilePhotoUpload(file.path);

      expect(prepared.filename, 'profile_photo.jpg');
      expect(prepared.bytes, bytes);
    },
  );
}
