import 'dart:developer';
import 'dart:math' as math;
import 'dart:ui';

import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_math/three_js_math.dart' as three_math;

import '../../../user/application/profile_controller.dart';
import '../../domain/tree_catalog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  three.ThreeJS? _threeJs;

  bool _threeReady = false;
  String? _threeError;

  String? _lastTreeId;

  three.Group? _treeGroup;
  three.Mesh? _ground;

  // orbit
  double _yaw = 0.0;
  double _pitch = -0.20;
  double _radius = 3.0;

  // gesture snapshot
  double _startYaw = 0.0;
  double _startPitch = -0.20;
  double _startRadius = 3.0;

  // zoom limits
  double _minRadius = 0.6;
  double _maxRadius = 12.0;

  // pitch limits
  static const double _minPitchHard = -1.15;
  static const double _maxPitch = 0.45;

  // target
  three.Vector3 _target = three.Vector3(0, 0.9, 0);

  // model dims
  double _modelHeight = 1.0;
  double _modelMaxDim = 1.0;

  // ground collision
  double _groundY = 0.0;
  static const double _camGroundMargin = 0.06;

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId) {
      _disposeThree(); // user değiştiyse 3D sıfırla
      _lastTreeId = null;
      _threeError = null;
      _threeReady = false;
    }
  }

  @override
  void dispose() {
    _disposeThree();
    three.loading.clear();
    super.dispose();
  }

  void _disposeThree() {
    _threeJs?.dispose();
    _threeJs = null;
    _treeGroup = null;
    _ground = null;
    _threeReady = false;
  }

  void _createThreeIfNeeded(String treeId) {
    // aynı tree ise yeniden kurma
    if (_lastTreeId == treeId && _threeJs != null) return;

    _lastTreeId = treeId;
    _threeError = null;
    _threeReady = false;

    _disposeThree();

    late final three.ThreeJS js;
    js = three.ThreeJS(
      setup: () => _setup(threeJsRef: js, treeId: treeId),
      onSetupComplete: () {
        if (!mounted) return;
        setState(() => _threeReady = true);
      },
    );

    setState(() {
      _threeJs = js;
    });
  }

  Future<void> _setup({
    required three.ThreeJS threeJsRef,
    required String treeId,
  }) async {
    try {
      final preset = TreeCatalog.resolve(treeId);

      // Scene
      threeJsRef.scene = three.Scene();

      // Camera
      threeJsRef.camera = three.PerspectiveCamera(
        45,
        threeJsRef.width / threeJsRef.height,
        0.01,
        2000,
      );

      // Renderer + shadows
      final r = threeJsRef.renderer;
      if (r != null) {
        r.setClearColor(three_math.Color.fromHex32(preset.bgColor), 1);
        r.shadowMap.enabled = true;
        r.shadowMap.type = three.PCFSoftShadowMap;
      }

      // Lights
      threeJsRef.scene.add(three.AmbientLight(0xffffff, 0.75));

      final dir = three.DirectionalLight(0xffffff, 0.95);
      dir.position.setValues(2.5, 6.0, 3.5);
      dir.castShadow = true;

      dir.shadow!.mapSize.width = 2048;
      dir.shadow!.mapSize.height = 2048;

      dir.shadow!.camera?.near = 0.2;
      dir.shadow!.camera?.far = 80;
      dir.shadow!.camera?.left = -10;
      dir.shadow!.camera?.right = 10;
      dir.shadow!.camera?.top = 10;
      dir.shadow!.camera?.bottom = -10;

      threeJsRef.scene.add(dir);

      // Load GLB
      final loader = three.GLTFLoader(flipY: true).setPath('assets/tree_models/');
      final gltf = await loader.fromAsset(preset.assetPath);
      if (gltf == null) throw Exception('GLB null (${preset.assetPath})');

      final tree = gltf.scene;

      // A) bounds
      tree.updateMatrixWorld(true);
      final b1 = _computeObjectBounds(tree);
      final size1 = _sizeOfBounds(b1);

      // B) scale
      const targetHeight = 0.55;
      final scale = (size1.y == 0) ? 1.0 : (targetHeight / size1.y);
      tree.scale.setValues(scale, scale, scale);
      tree.updateMatrixWorld(true);

      // C) bounds after scale
      final b2 = _computeObjectBounds(tree);
      final size2 = _sizeOfBounds(b2);

      _modelHeight = size2.y.clamp(0.1, 1000.0);
      _modelMaxDim = math.max(size2.x, math.max(size2.y, size2.z)).clamp(0.1, 1000.0);

      // D) ground + center
      final centerX = (b2.min.x + b2.max.x) * 0.5;
      final centerZ = (b2.min.z + b2.max.z) * 0.5;
      final minY = b2.min.y;

      tree.position.x -= centerX;
      tree.position.z -= centerZ;
      tree.position.y -= minY; // minY -> 0
      tree.updateMatrixWorld(true);

      // E) final bounds
      final b3 = _computeObjectBounds(tree);
      final size3 = _sizeOfBounds(b3);

      _modelHeight = size3.y.clamp(0.1, 1000.0);
      _modelMaxDim = math.max(size3.x, math.max(size3.y, size3.z)).clamp(0.1, 1000.0);

      _groundY = 0.0;

      // target
      final targetY = (_modelHeight * 0.55).clamp(0.20, 2.0);
      _target = three.Vector3(0, targetY, 0);

      // radius
      final fovRad = (45.0 * math.pi) / 180.0;
      final distance = (_modelMaxDim / 2) / math.tan(fovRad / 2);
      _radius = (distance * 2.1).clamp(0.8, 50.0);

      _minRadius = (_radius * 0.28).clamp(0.28, 6.0);
      _maxRadius = (_radius * 3.2).clamp(2.0, 90.0);

      // Group + shadows
      _treeGroup = three.Group();
      _treeGroup!.add(tree);

      _treeGroup!.traverse((obj) {
        if (obj is three.Mesh) {
          obj.castShadow = true;
          obj.receiveShadow = false;
        }
      });

      threeJsRef.scene.add(_treeGroup!);

      // Ground
      final groundSize = (_modelMaxDim * 20).clamp(10.0, 200.0);
      final geo = three.PlaneGeometry(groundSize, groundSize);

      final mat = three.MeshStandardMaterial();
      mat.color = three_math.Color.fromHex32(preset.bgColor);
      mat.roughness = 1.0;
      mat.metalness = 0.0;

      final g = three.Mesh(geo, mat);
      g.rotation.x = -math.pi / 2;
      g.position.setValues(0, 0.001, 0);
      g.receiveShadow = true;
      g.castShadow = false;

      _ground = g;
      threeJsRef.scene.add(_ground!);

      // Shadow frustum
      final half = (_modelMaxDim * 3.5).clamp(3.0, 40.0);
      dir.shadow!.camera?.left = -half;
      dir.shadow!.camera?.right = half;
      dir.shadow!.camera?.top = half;
      dir.shadow!.camera?.bottom = -half;
      dir.shadow!.camera?.near = 0.2;
      dir.shadow!.camera?.far = (half * 7).clamp(40.0, 260.0);

      // Fog
      threeJsRef.scene.fog = three.Fog(
        preset.bgColor,
        _radius * 0.9,
        _radius * 1.8,
      );

      _updateCamera(threeJsRef);

      threeJsRef.addAnimationEvent((dt) {
        _updateCamera(threeJsRef);
      });
    } catch (e, st) {
      log('ThreeJS setup error: $e', stackTrace: st);
      if (!mounted) return;
      setState(() => _threeError = e.toString());
    }
  }

  void _updateCamera(three.ThreeJS threeJsRef) {
    final minY = _groundY + _camGroundMargin;

    final rhs = (minY - _target.y) / (_radius == 0 ? 0.0001 : _radius);
    final clampedRhs = rhs.clamp(-0.999, 0.999);
    final dynamicMinPitch = math.asin(clampedRhs);

    final minPitch = math.max(_minPitchHard, dynamicMinPitch);
    _pitch = _pitch.clamp(minPitch, _maxPitch);

    final cp = math.cos(_pitch);
    final sp = math.sin(_pitch);
    final cy = math.cos(_yaw);
    final sy = math.sin(_yaw);

    final x = _target.x + _radius * cp * sy;
    final y = _target.y + _radius * sp;
    final z = _target.z + _radius * cp * cy;

    threeJsRef.camera.position.setValues(x, y, z);
    threeJsRef.camera.lookAt(_target);
  }

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

    _yaw -= dx * 3.2;
    _pitch += dy * 2.2;

    final s = d.scale;
    _radius = (_startRadius / s).clamp(_minRadius, _maxRadius);

    final js = _threeJs;
    if (js != null) _updateCamera(js);
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(profileControllerProvider(widget.userId));

    // treeId geldiyse: three init (1 kere) -> post frame
    final tid = st.treeId;
    if (tid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _createThreeIfNeeded(tid);
      });
    }

    final preset = (tid == null) ? null : TreeCatalog.resolve(tid);
    final bg = Color(preset?.bgColor ?? 0xFF000000);

    final showLoading = st.isLoading || (tid != null && !_threeReady && _threeError == null);

    final user = (st.profileJson?['user'] is Map) ? (st.profileJson!['user'] as Map) : null;

    final fullName = user?['full_name']?.toString() ?? '';
    final username = user?['username']?.toString() ?? '';
    final followerCount = st.profileJson?['follower_count'] ?? 0;
    final followingCount = st.profileJson?['following_count'] ?? 0;
    final defaultAvatar = user?['default_avatar'];
    final profilePhotoKey = user?['profile_photo_key']?.toString();
    final bio = user?['bio']?.toString() ?? '';

    final isFollowing = st.profileJson?['viewer_state']['is_following'] == true;
    final isMe = st.profileJson?['viewer_state']['is_me'] == true;
    final isBlocked = st.profileJson?['viewer_state']['is_blocked'] == true;

    final double topInset = MediaQuery.of(context).padding.top;
    const double topBarHeight = 72;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ThreeJS TAM EKRAN
          Positioned.fill(
            child: _threeJs == null
                ? const SizedBox.shrink()
                : SizedBox.expand(
                  child: _threeJs!.build(),
                ),
          ),

          // Gesture ALANI (top bar ALTINDAN başlar)
          Positioned(
            left: 0,
            right: 0,
            top: topInset + topBarHeight,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !_threeReady,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                child: const SizedBox.expand(),
              ),
            ),
          ),

          // TOP BAR (overlay – yer kaplamaz)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Material(
                        color: Colors.white.withOpacity(0.35),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          customBorder: const CircleBorder(),
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: Icon(
                                Icons.chevron_left,
                                size: 30,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 12,
                          sigmaY: 12,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.35), // cam hissi
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // AVATAR
                              defaultAvatar != null
                              ? ChaputCircleAvatar(
                                  isDefaultAvatar: profilePhotoKey == null || profilePhotoKey == "",
                                  imageUrl: profilePhotoKey != null && profilePhotoKey != ""
                                      ? profilePhotoKey
                                      : defaultAvatar,
                                )
                              : const SizedBox(),

                              const SizedBox(width: 10),

                              // ORTA ALAN
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                fullName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                '@$username',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.black.withOpacity(0.65),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        TextButton(
                                          onPressed: () {
                                            if (isBlocked) {
                                              null;
                                            } else if (isFollowing) {
                                              // unfollow
                                            } else {
                                              // follow
                                            }
                                          },
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            backgroundColor: isBlocked
                                                ? Colors.red.shade200
                                                : isFollowing
                                                ? Colors.grey.shade300
                                                : Colors.black,
                                            foregroundColor:
                                            isFollowing ? Colors.black : Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(
                                            isBlocked
                                                ? 'Engellenmiş'
                                                : isMe
                                                ? 'Ayarlar'
                                                : isFollowing
                                                ? 'Takibi Bırak'
                                                : 'Takip Et',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),

                                    if (bio.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        bio,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.black.withOpacity(0.8),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                ],
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