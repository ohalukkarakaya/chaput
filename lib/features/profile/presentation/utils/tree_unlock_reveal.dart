import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_math/three_js_math.dart' as three_math;

/// Runs on the existing renderer's frame clock, so route/app pauses also pause
/// the reveal. Only colors change; textures, geometry and materials stay intact.
class TreeUnlockReveal extends ValueNotifier<double> {
  TreeUnlockReveal() : super(1);

  static const durationSeconds = 1.8;
  final Map<three.Material, _MaterialColors> _colors = {};

  void start(Iterable<three.Material> materials) {
    finish();
    for (final material in materials) {
      _colors.putIfAbsent(material, () => _MaterialColors(material));
    }
    if (_colors.isEmpty) return;
    value = 0;
    _apply(0);
  }

  void advance(double dt) {
    if (value >= 1 || !dt.isFinite || dt <= 0) return;
    final next = (value + dt / durationSeconds).clamp(0.0, 1.0);
    if (next == 1) {
      finish();
      return;
    }
    _apply(Curves.easeInOutCubic.transform(next));
    value = next;
  }

  void _apply(double amount) {
    for (final entry in _colors.entries) {
      _scaleColor(entry.key.color, entry.value.color, amount);
      final emissive = entry.value.emissive;
      final targetEmissive = entry.key.emissive;
      if (emissive != null && targetEmissive != null) {
        _scaleColor(targetEmissive, emissive, amount);
      }
    }
  }

  void _scaleColor(
    three_math.Color target,
    three_math.Color original,
    double amount,
  ) {
    target.setValues(
      original.red * amount,
      original.green * amount,
      original.blue * amount,
      original.alpha,
    );
  }

  /// Restore exact colors before re-locking, replacing, or disposing the tree.
  void finish() {
    _apply(1);
    _colors.clear();
    value = 1;
  }

  @override
  void dispose() {
    finish();
    super.dispose();
  }
}

class _MaterialColors {
  _MaterialColors(three.Material material)
    : color = material.color.clone(),
      emissive = material.emissive?.clone();

  final three_math.Color color;
  final three_math.Color? emissive;
}
