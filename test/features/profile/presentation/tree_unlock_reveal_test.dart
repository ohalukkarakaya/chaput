import 'package:chaput/features/profile/presentation/utils/tree_unlock_reveal.dart';
import 'package:chaput/features/profile/presentation/widgets/tree_unlock_mist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_math/three_js_math.dart' as three_math;

void main() {
  test('reveals shared materials once and restores their exact colors', () {
    final material = three.MeshStandardMaterial();
    material.color = three_math.Color(0.2, 0.6, 0.4);
    material.emissive = three_math.Color(0.1, 0.2, 0.3);
    final color = material.color;
    final originalColor = color.clone();
    final originalEmissive = material.emissive!.clone();
    final reveal = TreeUnlockReveal();
    addTearDown(reveal.dispose);

    reveal.start([material, material]);
    expect(material.color.green, 0);
    expect(material.emissive!.blue, 0);
    reveal.advance(TreeUnlockReveal.durationSeconds / 2);
    expect(material.color.green, greaterThan(0));
    expect(material.color.green, lessThan(0.6));
    reveal.advance(TreeUnlockReveal.durationSeconds / 2);

    expect(reveal.value, 1);
    expect(identical(material.color, color), isTrue);
    expect(material.color.red, originalColor.red);
    expect(material.color.green, closeTo(0.6, 0.000001));
    expect(material.color.blue, originalColor.blue);
    expect(material.emissive!.blue, originalEmissive.blue);
  });

  test('interruption and restart cannot leave the tree dark', () {
    final material = three.MeshStandardMaterial();
    material.color = three_math.Color(0.2, 0.6, 0.4);
    final reveal = TreeUnlockReveal();

    reveal.start([material]);
    reveal.advance(0.4);
    reveal.finish(); // Re-lock or renderer replacement.
    expect(material.color.green, closeTo(0.6, 0.000001));
    expect(reveal.value, 1);

    reveal.start([material]);
    reveal.advance(0.2);
    reveal.start([material]); // A repeated state update during the reveal.
    reveal.advance(TreeUnlockReveal.durationSeconds);
    expect(material.color.green, closeTo(0.6, 0.000001));

    reveal.start([material]);
    reveal.dispose();
    expect(material.color.green, closeTo(0.6, 0.000001));
  });

  testWidgets('mist lets taps through during the reveal and at completion', (
    tester,
  ) async {
    final reveal = TreeUnlockReveal();
    addTearDown(reveal.dispose);
    final material = three.MeshStandardMaterial();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            ),
            TreeUnlockMist(progress: reveal),
          ],
        ),
      ),
    );
    reveal.start([material]);
    reveal.advance(0.7);
    await tester.pump();
    await tester.tapAt(const Offset(200, 200));
    expect(taps, 1);
    reveal.finish();
    await tester.pump();
    await tester.tapAt(const Offset(200, 200));
    expect(taps, 2);
    expect(tester.takeException(), isNull);
  });
}
