import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_math/three_js_math.dart' as three_math;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final three.ThreeJS threeJs;

  bool _ready = false;
  String? _error;

  three.Group? _treeGroup;
  three.Mesh? _ground;

  // orbit state
  double _yaw = 0.0;
  double _pitch = -0.20;
  double _radius = 3.0;

  // gesture snapshot
  double _startYaw = 0.0;
  double _startPitch = -0.20;
  double _startRadius = 3.0;

  // limits (dinamik)
  double _minRadius = 0.6;
  double _maxRadius = 12.0;

  // pitch limits (hard)
  static const double _minPitchHard = -1.15;
  static const double _maxPitch = 0.45;

  // target (lookAt)
  three.Vector3 _target = three.Vector3(0, 0.9, 0);

  // model dims
  double _modelHeight = 1.0;
  double _modelMaxDim = 1.0;

  // ground collision
  double _groundY = 0.0; // model oturtunca 0 olacak
  static const double _camGroundMargin = 0.02; // kamera zemine yapışmasın

  @override
  void initState() {
    super.initState();

    threeJs = three.ThreeJS(
      setup: _setup,
      onSetupComplete: () {
        if (!mounted) return;
        setState(() => _ready = true);
      },
    );
  }

  @override
  void dispose() {
    threeJs.dispose();
    three.loading.clear();
    super.dispose();
  }

  Future<void> _setup() async {
    try {
      // ---------------- Scene ----------------
      threeJs.scene = three.Scene();

      // ---------------- Camera ----------------
      threeJs.camera = three.PerspectiveCamera(
        45,
        threeJs.width / threeJs.height,
        0.01,
        2000,
      );

      // ---------------- Renderer (SHADOW MAP ON) ----------------
      final r = threeJs.renderer;
      if (r != null) {
        r.setClearColor(three_math.Color.fromHex32(0x000000), 1);
        r.shadowMap.enabled = true;
        r.shadowMap.type = three.PCFSoftShadowMap;
      }

      // ---------------- Lights ----------------
      threeJs.scene.add(three.AmbientLight(0xffffff, 0.75));

      final dir = three.DirectionalLight(0xffffff, 0.95);
      dir.position.setValues(2.5, 6.0, 3.5);
      dir.castShadow = true;

      // shadow quality
      dir.shadow!.mapSize.width = 2048;
      dir.shadow!.mapSize.height = 2048;

      // (sonra modele göre güncellenecek)
      dir.shadow!.camera?.near = 0.2;
      dir.shadow!.camera?.far = 80;
      dir.shadow!.camera?.left = -10;
      dir.shadow!.camera?.right = 10;
      dir.shadow!.camera?.top = 10;
      dir.shadow!.camera?.bottom = -10;

      threeJs.scene.add(dir);

      // ---------------- Load GLB ----------------
      final loader = three.GLTFLoader(flipY: true).setPath('assets/tree_models/');
      final gltf = await loader.fromAsset('tree_002.glb');
      if (gltf == null) throw Exception('GLB null (tree_002.glb)');

      final tree = gltf.scene;

      // --- A) Bounds (ilk)
      tree.updateMatrixWorld(true);
      final b1 = _computeObjectBounds(tree);
      final size1 = _sizeOfBounds(b1);

      // --- B) Auto-scale: hedef yükseklik
      const targetHeight = 0.55; // küçük dursun
      final scale = (size1.y == 0) ? 1.0 : (targetHeight / size1.y);
      tree.scale.setValues(scale, scale, scale);
      tree.updateMatrixWorld(true);

      // --- C) bounds after scale
      final b2 = _computeObjectBounds(tree);
      final size2 = _sizeOfBounds(b2);

      _modelHeight = size2.y.clamp(0.1, 1000.0);
      _modelMaxDim = math.max(size2.x, math.max(size2.y, size2.z)).clamp(0.1, 1000.0);

      // --- D) Model'i yere oturt + XZ merkezle
      final centerX = (b2.min.x + b2.max.x) * 0.5;
      final centerZ = (b2.min.z + b2.max.z) * 0.5;
      final minY = b2.min.y;

      tree.position.x -= centerX;
      tree.position.z -= centerZ;
      tree.position.y -= minY; // ✅ minY -> 0
      tree.updateMatrixWorld(true);

      // --- E) final bounds (artık minY ~ 0)
      final b3 = _computeObjectBounds(tree);
      final size3 = _sizeOfBounds(b3);

      _modelHeight = size3.y.clamp(0.1, 1000.0);
      _modelMaxDim = math.max(size3.x, math.max(size3.y, size3.z)).clamp(0.1, 1000.0);

      // ground artık 0
      _groundY = 0.0;

      // Target: orta-üst
      final targetY = (_modelHeight * 0.55).clamp(0.20, 2.0);
      _target = three.Vector3(0, targetY, 0);

      // Kamera mesafesi
      final fovRad = (45.0 * math.pi) / 180.0;
      final distance = (_modelMaxDim / 2) / math.tan(fovRad / 2);

      // biraz daha uzak olsun
      _radius = (distance * 2.1).clamp(0.8, 50.0);

      // Zoom sınırları (zoom-in kesin çalışsın)
      _minRadius = (_radius * 0.28).clamp(0.28, 6.0);
      _maxRadius = (_radius * 3.2).clamp(2.0, 90.0);

      // ---------------- Group + Shadows ----------------
      _treeGroup = three.Group();
      _treeGroup!.add(tree);

      // ✅ Mesh kontrolünü doğru yap (isMesh yok)
      _treeGroup!.traverse((obj) {
        if (obj is three.Mesh) {
          obj.castShadow = true;
          obj.receiveShadow = false;
        }
      });

      threeJs.scene.add(_treeGroup!);

      // ---------------- Ground (tam dibinde) ----------------
      final groundSize = (_modelMaxDim * 20).clamp(10.0, 200.0);

      final geo = three.PlaneGeometry(groundSize, groundSize);
      final mat = three.MeshStandardMaterial();
      mat.color = three.Color(0x000000);
      mat.roughness = 1.0;
      mat.metalness = 0.0;

      final g = three.Mesh(geo, mat);
      g.rotation.x = -math.pi / 2;

      // ✅ model minY=0 => ground y=0 (+ z-fight offset)
      g.position.setValues(0, 0.001, 0);

      g.receiveShadow = true;
      g.castShadow = false;

      _ground = g;
      threeJs.scene.add(_ground!);

      // ---------------- Directional shadow frustum'u modele göre ayarla ----------------
      final half = (_modelMaxDim * 3.5).clamp(3.0, 40.0);
      dir.shadow!.camera?.left = -half;
      dir.shadow!.camera?.right = half;
      dir.shadow!.camera?.top = half;
      dir.shadow!.camera?.bottom = -half;
      dir.shadow!.camera?.near = 0.2;
      dir.shadow!.camera?.far = (half * 7).clamp(40.0, 260.0);

      // İlk kamera update
      _updateCamera();

      // render loop
      threeJs.addAnimationEvent((dt) {
        _updateCamera(); // collision clamp burada çalışıyor
      });
    } catch (e, st) {
      log('ThreeJS error: $e', stackTrace: st);
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  void _updateCamera() {
    // ✅ Zemin çarpışma: cameraY >= groundY + margin
    final minY = _groundY + _camGroundMargin;

    // targetY + radius*sin(pitch) >= minY
    final rhs = (minY - _target.y) / (_radius == 0 ? 0.0001 : _radius);

    // asin domain clamp
    final clampedRhs = rhs.clamp(-0.999, 0.999);

    // pitch alt sınırı (zemin için)
    final dynamicMinPitch = math.asin(clampedRhs);

    // hard limit ile birleştir
    final minPitch = math.max(_minPitchHard, dynamicMinPitch);
    _pitch = _pitch.clamp(minPitch, _maxPitch);

    final cp = math.cos(_pitch);
    final sp = math.sin(_pitch);
    final cy = math.cos(_yaw);
    final sy = math.sin(_yaw);

    final x = _target.x + _radius * cp * sy;
    final y = _target.y + _radius * sp;
    final z = _target.z + _radius * cp * cy;

    threeJs.camera.position.setValues(x, y, z);
    threeJs.camera.lookAt(_target);
  }

  // ✅ Scale = orbit + pinch zoom (tek gesture)
  void _onScaleStart(ScaleStartDetails d) {
    _startYaw = _yaw;
    _startPitch = _pitch;
    _startRadius = _radius;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    final dx = d.focalPointDelta.dx / (w == 0 ? 1 : w);
    final dy = d.focalPointDelta.dy / (h == 0 ? 1 : h);

    // sağ-sol
    _yaw -= dx * 3.2;

    // yukarı-aşağı (ters olmasın)
    _pitch += dy * 2.2;

    // pinch zoom:
    // scale > 1 => yakınlaş => radius küçül
    // scale < 1 => uzaklaş => radius büyül
    final s = d.scale;
    _radius = (_startRadius / s).clamp(_minRadius, _maxRadius);

    _updateCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: threeJs.build()),

          // gesture overlay
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_ready,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                child: const SizedBox.expand(),
              ),
            ),
          ),

          // back
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          if (_error == null && !_ready)
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),

          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ---------------- Bounds helpers ----------------
class _Bounds {
  final three.Vector3 min;
  final three.Vector3 max;
  _Bounds(this.min, this.max);
}

three.Vector3 _sizeOfBounds(_Bounds b) {
  return three.Vector3(
    b.max.x - b.min.x,
    b.max.y - b.min.y,
    b.max.z - b.min.z,
  );
}

_Bounds _computeObjectBounds(three.Object3D root) {
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

    // 8 corner
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

  return _Bounds(min, max);
}