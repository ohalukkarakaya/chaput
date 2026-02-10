import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

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
      bgColor: AppColors.chaputTreeBg1Hex,
      targetHeight: 0.55,
    ),
    TreePreset(
      id: '2',
      assetPath: 'tree_002.glb',
      bgColor: AppColors.chaputTreeBg2Hex,
      targetHeight: 0.55,
    ),
    TreePreset(
      id: '3',
      assetPath: 'tree_003.glb',
      bgColor: AppColors.chaputTreeBg3Hex,
      targetHeight: 0.55,
    ),
    TreePreset(
      id: '4',
      assetPath: 'tree_004.glb',
      bgColor: AppColors.chaputCloudBlueHex,
      targetHeight: 0.60,
    ),
    TreePreset(
      id: '5',
      assetPath: 'tree_005.glb',
      bgColor: AppColors.chaputTreeBg5Hex,
      targetHeight: 0.58,
    ),
    TreePreset(
      id: '6',
      assetPath: 'tree_006.glb',
      bgColor: AppColors.chaputTreeBg6Hex,
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
