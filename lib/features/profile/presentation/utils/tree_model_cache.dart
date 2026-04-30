import 'package:three_js_core_loaders/three_js_core_loaders.dart';

import '../../domain/tree_catalog.dart';

class TreeModelCache {
  TreeModelCache._() {
    Cache.enabled = true;
  }

  static final TreeModelCache instance = TreeModelCache._();

  final FileLoader _loader = FileLoader()..setPath('assets/tree_models/');
  final Map<String, Future<void>> _assetWarmups = {};
  bool _warming = false;

  Future<void> warmUpAll() async {
    if (_warming) return;
    _warming = true;
    try {
      for (final preset in TreeCatalog.all) {
        await _warmAsset(preset.assetPath);
      }
    } finally {
      _warming = false;
    }
  }

  Future<void> ensureWarm(String treeId) {
    final preset = TreeCatalog.resolve(treeId);
    return _warmAsset(preset.assetPath);
  }

  Future<void> _warmAsset(String assetPath) {
    return _assetWarmups.putIfAbsent(assetPath, () async {
      final file = await _loader.fromAsset(assetPath);
      if (file == null) {
        throw Exception('GLB null ($assetPath)');
      }
    });
  }
}
