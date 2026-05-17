import 'package:three_js/three_js.dart' as three;
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
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    } finally {
      _warming = false;
    }
  }

  Future<void> ensureWarm(String treeId) async {
    final preset = TreeCatalog.resolve(treeId);
    await _warmAsset(preset.assetPath);
  }

  Future<three.Object3D> loadFreshScene(String treeId) async {
    final preset = TreeCatalog.resolve(treeId);
    await _warmAsset(preset.assetPath);
    final loader = three.GLTFLoader(flipY: true).setPath('assets/tree_models/');
    final gltf = await loader.fromAsset(preset.assetPath);
    final scene = gltf?.scene;
    if (scene == null) throw Exception('GLB null (${preset.assetPath})');
    return scene;
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
