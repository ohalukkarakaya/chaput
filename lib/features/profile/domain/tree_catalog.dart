import 'package:flutter/material.dart';

@immutable
class TreePreset {
  final String id;                 // "tree_003" gibi
  final String assetPath;          // "assets/tree_models/tree_003.glb"
  final int bgColor;             // arka plan rengi
  final double targetHeight;       // auto-scale hedefi (opsiyonel ama çok iş görür)

  const TreePreset({
    required this.id,
    required this.assetPath,
    required this.bgColor,
    this.targetHeight = 0.55,      // default
  });
}

class TreeCatalog {
  TreeCatalog._();

  // ✅ 6 farklı ağaç burada
  static const List<TreePreset> all = [
    TreePreset(
      id: '1',
      assetPath: 'tree_001.glb',
      bgColor: 0xEADBC8,
      targetHeight: 0.55,
    ),
    TreePreset(
      id: '2',
      assetPath: 'tree_002.glb',
      bgColor: 0xE6F0E6,
      targetHeight: 0.55,
    ),
    TreePreset(
      id: '3',
      assetPath: 'tree_003.glb',
      bgColor: 0xF3C6A6,
      targetHeight: 0.55,
    ),
    TreePreset(
      id: '4',
      assetPath: 'tree_004.glb',
      bgColor: 0xE9EEF3,
      targetHeight: 0.60,
    ),
    TreePreset(
      id: '5',
      assetPath: 'tree_005.glb',
      bgColor: 0xE6D9F0,
      targetHeight: 0.58,
    ),
    TreePreset(
      id: '6',
      assetPath: 'tree_006.glb',
      bgColor: 0xDCEFE6,
      targetHeight: 0.56,
    ),
  ];

  // ✅ hızlı lookup (O(1))
  static final Map<String, TreePreset> byId = {
    for (final t in all) t.id: t,
  };

  // ✅ güvenli getter (bulamazsa fallback)
  static TreePreset resolve(String? id) {
    return byId[id] ?? byId['2']!;
  }
}
