import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'photo_upload_preparer.dart';

/// Source coordinates shared by the preview and the exported photo.
class SquarePhotoCrop {
  SquarePhotoCrop(this.imageSize)
    : rect = ui.Rect.fromCenter(
        center: imageSize.center(ui.Offset.zero),
        width: imageSize.shortestSide,
        height: imageSize.shortestSide,
      );

  final ui.Size imageSize;
  ui.Rect rect;

  static const maxZoom = 5.0;
  double get zoom => imageSize.shortestSide / rect.width;

  void reset() {
    rect = ui.Rect.fromCenter(
      center: imageSize.center(ui.Offset.zero),
      width: imageSize.shortestSide,
      height: imageSize.shortestSide,
    );
  }

  void setZoom(double value) {
    final side = imageSize.shortestSide / value.clamp(1.0, maxZoom);
    _setRect(rect.center - ui.Offset(side / 2, side / 2), side);
  }

  /// Keeps the source point under the fingers fixed while panning / pinching.
  void updateGesture({
    required ui.Rect startRect,
    required ui.Offset startFocalPoint,
    required ui.Offset focalPoint,
    required double viewportSide,
    required double scale,
  }) {
    final sourceAnchor =
        startRect.topLeft + startFocalPoint * (startRect.width / viewportSide);
    final nextZoom = (imageSize.shortestSide / startRect.width * scale).clamp(
      1.0,
      maxZoom,
    );
    final side = imageSize.shortestSide / nextZoom;
    _setRect(sourceAnchor - focalPoint * (side / viewportSide), side);
  }

  void _setRect(ui.Offset origin, double side) {
    rect = ui.Rect.fromLTWH(
      origin.dx.clamp(0.0, imageSize.width - side),
      origin.dy.clamp(0.0, imageSize.height - side),
      side,
      side,
    );
  }
}

Future<PreparedPhotoUpload> exportSquarePhoto(
  ui.Image source,
  ui.Rect crop,
) async {
  final image = source.clone();
  final side = math.min(1600, math.max(1, crop.width.round()));
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final destination = ui.Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble());
  // Flatten transparent photos consistently in the preview and JPEG output.
  canvas.drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
  canvas.drawImageRect(
    image,
    crop,
    destination,
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final picture = recorder.endRecording();
  ui.Image? output;
  try {
    output = await picture.toImage(side, side);
    final data = await output.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) throw Exception('image_encode_failed');
    final bytes = await compute(_encodeJpeg, (
      pixels: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      side: side,
    ));
    return PreparedPhotoUpload(bytes: bytes, filename: 'profile_photo.jpg');
  } finally {
    output?.dispose();
    picture.dispose();
    image.dispose();
  }
}

Uint8List _encodeJpeg(({Uint8List pixels, int side}) input) {
  final image = img.Image.fromBytes(
    width: input.side,
    height: input.side,
    bytes: input.pixels.buffer,
    bytesOffset: input.pixels.offsetInBytes,
    numChannels: 4,
  );
  return img.encodeJpg(image, quality: 90);
}
