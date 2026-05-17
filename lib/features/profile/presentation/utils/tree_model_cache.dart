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
  final Map<String, Future<three.Object3D>> _sceneWarmups = {};
  bool _warming = false;

  Future<void> warmUpAll() async {
    if (_warming) return;
    _warming = true;
    try {
      for (final preset in TreeCatalog.all) {
        await _loadSourceScene(preset.assetPath);
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    } finally {
      _warming = false;
    }
  }

  Future<void> ensureWarm(String treeId) async {
    final preset = TreeCatalog.resolve(treeId);
    await _loadSourceScene(preset.assetPath);
  }

  Future<three.Object3D> loadSceneClone(String treeId) async {
    final preset = TreeCatalog.resolve(treeId);
    final source = await _loadSourceScene(preset.assetPath);
    final clone = source.clone(true);
    _shareRenderResources(source, clone);
    return clone;
  }

  void _shareRenderResources(three.Object3D source, three.Object3D clone) {
    if (source is three.Mesh && clone is three.Mesh) {
      clone.geometry = source.geometry;
      clone.material = source.material;
    }

    final count = source.children.length < clone.children.length
        ? source.children.length
        : clone.children.length;
    for (var i = 0; i < count; i++) {
      _shareRenderResources(source.children[i], clone.children[i]);
    }
  }

  Future<void> _warmAsset(String assetPath) {
    return _assetWarmups.putIfAbsent(assetPath, () async {
      final file = await _loader.fromAsset(assetPath);
      if (file == null) {
        throw Exception('GLB null ($assetPath)');
      }
    });
  }

  Future<three.Object3D> _loadSourceScene(String assetPath) {
    return _sceneWarmups.putIfAbsent(assetPath, () async {
      await _warmAsset(assetPath);
      final loader = three.GLTFLoader(
        flipY: true,
      ).setPath('assets/tree_models/');
      final gltf = await loader.fromAsset(assetPath);
      final scene = gltf?.scene;
      if (scene == null) throw Exception('GLB null ($assetPath)');
      return scene;
    });
  }
}
