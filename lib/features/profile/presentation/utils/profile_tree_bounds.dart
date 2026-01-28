import 'package:three_js/three_js.dart' as three;

class Bounds {
  final three.Vector3 min;
  final three.Vector3 max;
  Bounds(this.min, this.max);
}

three.Vector3 sizeOfBounds(Bounds b) {
  return three.Vector3(
    b.max.x - b.min.x,
    b.max.y - b.min.y,
    b.max.z - b.min.z,
  );
}

Bounds computeObjectBounds(three.Object3D root) {
  final min = three.Vector3(1e9, 1e9, 1e9);
  final max = three.Vector3(-1e9, -1e9, -1e9);

  void expand(three.Vector3 p) {
    if (p.x < min.x) min.x = p.x;
    if (p.y < min.y) min.y = p.y;
    if (p.z < min.z) min.z = p.z;

    if (p.x > max.x) max.x = p.x;
    if (p.y > max.y) max.y = p.y;
    if (p.z > max.z) max.z = p.z;
  }

  root.updateMatrixWorld(true);

  root.traverse((obj) {
    final o = obj as dynamic;

    final geometry = o.geometry;
    if (geometry == null) return;

    if (geometry.boundingBox == null) {
      try {
        geometry.computeBoundingBox();
      } catch (_) {
        return;
      }
    }

    final bb = geometry.boundingBox;
    if (bb == null) return;

    final corners = <three.Vector3>[
      three.Vector3(bb.min.x, bb.min.y, bb.min.z),
      three.Vector3(bb.min.x, bb.min.y, bb.max.z),
      three.Vector3(bb.min.x, bb.max.y, bb.min.z),
      three.Vector3(bb.min.x, bb.max.y, bb.max.z),
      three.Vector3(bb.max.x, bb.min.y, bb.min.z),
      three.Vector3(bb.max.x, bb.min.y, bb.max.z),
      three.Vector3(bb.max.x, bb.max.y, bb.min.z),
      three.Vector3(bb.max.x, bb.max.y, bb.max.z),
    ];

    try {
      for (final c in corners) {
        c.applyMatrix4(o.matrixWorld);
        expand(c);
      }
    } catch (_) {
      for (final c in corners) {
        expand(c);
      }
    }
  });

  return Bounds(min, max);
}
