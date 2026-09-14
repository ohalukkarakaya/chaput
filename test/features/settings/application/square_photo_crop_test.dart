import 'dart:ui';

import 'package:chaput/features/settings/application/square_photo_crop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('portrait and landscape start centered with a square crop', () {
    expect(
      SquarePhotoCrop(const Size(400, 200)).rect,
      const Rect.fromLTWH(100, 0, 200, 200),
    );
    expect(
      SquarePhotoCrop(const Size(200, 400)).rect,
      const Rect.fromLTWH(0, 100, 200, 200),
    );
  });

  test('pinching preserves the source point under the fingers', () {
    final crop = SquarePhotoCrop(const Size(400, 200));
    crop.updateGesture(
      startRect: crop.rect,
      startFocalPoint: const Offset(50, 50),
      focalPoint: const Offset(50, 50),
      viewportSide: 200,
      scale: 2,
    );
    expect(crop.zoom, 2);
    expect(crop.rect, const Rect.fromLTWH(125, 25, 100, 100));
  });

  test(
    'dragging clamps at every edge and zooming out never exposes blank space',
    () {
      for (final size in [const Size(400, 200), const Size(200, 400)]) {
        final crop = SquarePhotoCrop(size)..setZoom(2);
        crop.updateGesture(
          startRect: crop.rect,
          startFocalPoint: const Offset(100, 100),
          focalPoint: const Offset(-10000, -10000),
          viewportSide: 200,
          scale: 1,
        );
        expect(crop.rect.right, size.width);
        expect(crop.rect.bottom, size.height);
        crop.setZoom(0.1);
        expect(crop.zoom, 1);
        expect(crop.rect.right, lessThanOrEqualTo(size.width));
        expect(crop.rect.bottom, lessThanOrEqualTo(size.height));
        crop.updateGesture(
          startRect: crop.rect,
          startFocalPoint: const Offset(100, 100),
          focalPoint: const Offset(10000, 10000),
          viewportSide: 200,
          scale: 100,
        );
        expect(crop.rect.topLeft, Offset.zero);
        expect(crop.zoom, SquarePhotoCrop.maxZoom);
        crop.reset();
        expect(crop.rect, SquarePhotoCrop(size).rect);
      }
    },
  );

  testWidgets(
    'export includes only the selected source area as a square JPEG',
    (tester) async {
      await tester.runAsync(() async {
        final source = img.Image(width: 200, height: 100);
        for (final pixel in source) {
          pixel.setRgb(pixel.x < 100 ? 255 : 0, 0, pixel.x < 100 ? 0 : 255);
        }
        final codec = await instantiateImageCodec(img.encodePng(source));
        final frame = await codec.getNextFrame();
        try {
          final result = await exportSquarePhoto(
            frame.image,
            const Rect.fromLTWH(100, 0, 100, 100),
          );
          expect(result.filename, 'profile_photo.jpg');
          final output = img.decodeJpg(result.bytes)!;
          expect(output.width, 100);
          expect(output.height, 100);
          for (final pixel in output) {
            expect(pixel.b, greaterThan(240));
            expect(pixel.r, lessThan(15));
          }
        } finally {
          frame.image.dispose();
          codec.dispose();
        }
      });
    },
  );
}
