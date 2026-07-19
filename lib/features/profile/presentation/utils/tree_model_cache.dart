import 'package:flutter/services.dart';
import 'package:three_js/three_js.dart' as three;

import '../../domain/tree_catalog.dart';

class TreeModelCache {
  TreeModelCache._();

  static final TreeModelCache instance = TreeModelCache._();

  final Map<String, Future<Uint8List>> _assetBytes = {};
  Future<void> _decodeTail = Future<void>.value();
  bool _warming = false;

  Future<void> warmUpAll() async {
    if (_warming) return;
    _warming = true;
    try {
      for (final preset in TreeCatalog.all) {
        await _loadAssetBytes(preset.assetPath);
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    } finally {
      _warming = false;
    }
  }

  Future<void> ensureWarm(String treeId) async {
    final preset = TreeCatalog.resolve(treeId);
    await _loadAssetBytes(preset.assetPath);
  }

  Future<three.Object3D> loadFreshScene(String treeId) async {
    final preset = TreeCatalog.resolve(treeId);
    final bytes = await _loadAssetBytes(preset.assetPath);
    return _serializeDecode(() async {
      // A GLTF loader may retain its input while it builds material/texture
      // resources. Keep the cached asset immutable and give every renderer an
      // isolated buffer, so an old scene cannot share loader state with the
      // tree currently being displayed.
      final loader = three.GLTFLoader(flipY: true);
      final gltf = await loader.fromBytes(Uint8List.fromList(bytes));
      final scene = gltf?.scene;
      if (scene == null) throw Exception('GLB null (${preset.assetPath})');
      return scene;
    });
  }

  Future<Uint8List> _loadAssetBytes(String assetPath) {
    return _assetBytes.putIfAbsent(assetPath, () async {
      final data = await rootBundle.load('assets/tree_models/$assetPath');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    });
  }

  /// GLB decoding touches shared Three/ANGLE state. Serialising it avoids
  /// transient texture/material corruption while a profile is changing.
  Future<T> _serializeDecode<T>(Future<T> Function() decode) {
    final scheduled = _decodeTail.then<T>((_) => decode());
    _decodeTail = scheduled.then<void>((_) {}, onError: (_, __) {});
    return scheduled;
  }
}
