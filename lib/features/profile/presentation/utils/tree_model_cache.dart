import 'package:three_js_core_loaders/three_js_core_loaders.dart';

import '../../domain/tree_catalog.dart';

class TreeModelCache {
  TreeModelCache._() {
    Cache.enabled = true;
  }

  static final TreeModelCache instance = TreeModelCache._();

  final FileLoader _loader = FileLoader()..setPath('assets/tree_models/');
  bool _warming = false;

  Future<void> warmUpAll() async {
    if (_warming) return;
    _warming = true;
    try {
      for (final preset in TreeCatalog.all) {
        await _loader.fromAsset(preset.assetPath);
      }
    } finally {
      _warming = false;
    }
  }
}
