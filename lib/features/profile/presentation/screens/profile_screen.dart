import 'dart:developer';
import 'dart:math' as math;
import 'dart:ui';

import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_math/three_js_math.dart' as three_math;

import '../../../../core/router/routes.dart';
import '../../../social/application/follow_state.dart';
import '../../../user/application/profile_controller.dart';
import '../../domain/tree_catalog.dart';

import '../../../social/application/follow_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {

  late final AnimationController _profileCardCtrl;
  late final Animation<double> _profileCardT;
  bool _profileCardOpen = false;

  bool _pendingTreeModeShift = false;
  bool _treeModeShiftDoneThisGesture = false;

  bool? _uiIsFollowing;
  int _uiFollowerDelta = 0;
  bool _uiFollowLoading = false;


  // ================= FOCUS / ANCHOR =================
  three.Vector3? _focusAnchor; // leaf üstündeki world-space nokta
  final ValueNotifier<Offset?> _focusScreen = ValueNotifier<Offset?>(null);

  bool _isInteracting = false;
  bool _showFocusMarker = false;

// snap-back animasyonu
  late double _snapFromYaw, _snapToYaw;
  late double _snapFromPitch, _snapToPitch;

  late three.Vector3 _snapFromLookAt;
  late three.Vector3 _snapToLookAt;

  bool _snapActive = false;
  double _snapT = 0.0;

  late three.Vector3 _snapFromTarget;
  late three.Vector3 _snapToTarget;

  late three.Vector3 _snapFromCenter;
  late three.Vector3 _snapToCenter;

  double _defaultRadius = 3.0;
  double _snapFromRadius = 3.0;
  double _snapToRadius = 3.0;

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

  // orbit merkez (ağacın merkezi) + bakış hedefi
  three.Vector3 _treeCenter = three.Vector3(0, 0.9, 0);  // sabit: ağacın merkezi
  three.Vector3 _orbitCenter = three.Vector3(0, 0.9, 0); // dinamik: treeCenter <-> focusAnchor
  three.Vector3 _lookAt = three.Vector3(0, 0.9, 0);      // genelde orbitCenter ile aynı gider

  bool _centerShiftActive = false;
  double _centerShiftT = 0.0;

  late three.Vector3 _shiftFromCenter;
  late three.Vector3 _shiftToCenter;

  late three.Vector3 _shiftFromLookAt;
  late three.Vector3 _shiftToLookAt;

  static const double _centerShiftDuration = 0.12; // hızlı geçiş

  // model dims
  double _modelHeight = 1.0;
  double _modelMaxDim = 1.0;

  // ground collision
  double _groundY = 0.0;
  static const double _camGroundMargin = 0.06;

  @override
  void initState() {
    super.initState();
    _profileCardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _profileCardT = CurvedAnimation(
      parent: _profileCardCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

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
    _focusScreen.dispose();
    _profileCardCtrl.dispose();
    super.dispose();
  }

  void _toggleProfileCard() {
    setState(() => _profileCardOpen = !_profileCardOpen);
    if (_profileCardOpen) {
      _profileCardCtrl.forward(from: 0);
    } else {
      _profileCardCtrl.reverse(from: 1);
    }
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

      // orbit merkez
      final targetY = (_modelHeight * 0.55).clamp(0.20, 2.0);
      _treeCenter = three.Vector3(0, targetY, 0);

      // ilk başta normal merkez
      _orbitCenter = _treeCenter.clone();
      _lookAt = _orbitCenter.clone();



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

      // ====== Focus anchor ======
      _defaultRadius = _radius;

      // İlk açılışta seçili nokta YOK
      _focusAnchor = null;
      _showFocusMarker = false;

      // merkez treeCenter'da kalsın
      _orbitCenter = _treeCenter.clone();
      _lookAt = _orbitCenter.clone();



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
        _tickCenterShift(dt);
        _tickSnap(dt);
        _updateCamera(threeJsRef);
      });
    } catch (e, st) {
      log('ThreeJS setup error: $e', stackTrace: st);
      if (!mounted) return;
      setState(() => _threeError = e.toString());
    }
  }

  three.Vector3? _pickRandomLeafAnchor(three.Object3D root) {
    final leafMeshes = <three.Mesh>[];

    root.traverse((obj) {
      if (obj is three.Mesh) {
        final name = obj.name.toLowerCase();
        if (name.contains('leaves') || name.contains('leaf')) {
          leafMeshes.add(obj);
        }
      }
    });

    if (leafMeshes.isEmpty) return null;

    final rnd = math.Random();
    final mesh = leafMeshes[rnd.nextInt(leafMeshes.length)];
    final geo = mesh.geometry;

    if (geo is! three.BufferGeometry) return null;

    final pos = geo.attributes['position'];
    if (pos == null) return null;

    final count = pos.count;
    if (count <= 0) return null;

    final i = rnd.nextInt(count);

    final local = three.Vector3(
      pos.getX(i),
      pos.getY(i),
      pos.getZ(i),
    );

    local.applyMatrix4(mesh.matrixWorld);
    return local;
  }

  void _pickNewRandomAnchorAndSnap() {
    _centerShiftActive = false;
    _pendingTreeModeShift = false;
    _treeModeShiftDoneThisGesture = false;
    _isInteracting = false;

    final g = _treeGroup;
    if (g == null) return;

    g.updateMatrixWorld(true);
    final newAnchor = _pickRandomLeafAnchor(g);
    if (newAnchor == null) return;

    // ✅ hedef anchor değişsin ama kamera/merkez anında zıplamasın
    _focusAnchor = newAnchor;

    _showFocusMarker = false; // snap bitince açılacak

    // ✅ mevcut durumdan -> yeni anchor'a smooth geç
    _startSnapToNewAnchor();
  }

  void _startSnapToNewAnchor() {
    if (_focusAnchor == null) return;

    // "yeni anchor" için ideal yaw/pitch'i treeCenter'a göre hesapla
    final v = _focusAnchor!.clone().sub(_treeCenter);
    final len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    if (len < 1e-6) return;

    v.x /= len;
    v.y /= len;
    v.z /= len;

    final camDir = three.Vector3(-v.x, -v.y, -v.z);
    final desiredYaw = math.atan2(camDir.x, camDir.z);
    final desiredPitch = math.asin(camDir.y).clamp(_minPitchHard, _maxPitch);

    // ✅ Snap hedefi: orbitCenter + lookAt = newAnchor
    _startSnapBackTo(
      yaw: desiredYaw,
      pitch: desiredPitch,
      lookAt: _focusAnchor!.clone(),
      radius: _defaultRadius,
    );
  }

  void _startCenterShift({
    required three.Vector3 toCenter,
    required three.Vector3 toLookAt,
  }) {
    _centerShiftActive = true;
    _centerShiftT = 0.0;

    _shiftFromCenter = _orbitCenter.clone();
    _shiftToCenter = toCenter.clone();

    _shiftFromLookAt = _lookAt.clone();
    _shiftToLookAt = toLookAt.clone();
  }

  void _tickCenterShift(double dt) {
    if (!_centerShiftActive) return;

    _centerShiftT += dt / _centerShiftDuration;
    if (_centerShiftT >= 1.0) {
      _centerShiftT = 1.0;
      _centerShiftActive = false;
    }

    final t = _centerShiftT;
    final s = t * t * (3 - 2 * t); // smoothstep

    _orbitCenter = three.Vector3(
      _shiftFromCenter.x + (_shiftToCenter.x - _shiftFromCenter.x) * s,
      _shiftFromCenter.y + (_shiftToCenter.y - _shiftFromCenter.y) * s,
      _shiftFromCenter.z + (_shiftToCenter.z - _shiftFromCenter.z) * s,
    );

    _lookAt = three.Vector3(
      _shiftFromLookAt.x + (_shiftToLookAt.x - _shiftFromLookAt.x) * s,
      _shiftFromLookAt.y + (_shiftToLookAt.y - _shiftFromLookAt.y) * s,
      _shiftFromLookAt.z + (_shiftToLookAt.z - _shiftFromLookAt.z) * s,
    );
  }

  void _setFocusModeInstant() {
    if (_focusAnchor == null) return;

    _orbitCenter = _focusAnchor!.clone();
    _lookAt = _orbitCenter.clone();

    // kamera açısı: anchor'ın treeCenter'a göre "ön" tarafına gelsin
    _yawPitchForFocus(frontByTreeCenter: true);

    _radius = _defaultRadius.clamp(_minRadius, _maxRadius);
    _showFocusMarker = true;
  }

  void _startTreeModeFast() {
    // kullanıcı dokununca hızlıca tree center’a geç
    _startCenterShift(
      toCenter: _treeCenter,
      toLookAt: _treeCenter,
    );
  }

  void _yawPitchForFocus({required bool frontByTreeCenter}) {
    if (_focusAnchor == null) return;

    final v = _focusAnchor!.clone().sub(_treeCenter);
    final len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    if (len < 1e-6) return;

    v.x /= len; v.y /= len; v.z /= len;

    // kamerayı anchor'ın "ön" tarafına al (treeCenter'a göre)
    final camDir = frontByTreeCenter
        ? three.Vector3(-v.x, -v.y, -v.z)
        : three.Vector3(v.x, v.y, v.z);

    _yaw = math.atan2(camDir.x, camDir.z);
    _pitch = math.asin(camDir.y).clamp(_minPitchHard, _maxPitch);
  }


  void _updateCamera(three.ThreeJS threeJsRef) {
    final minY = _groundY + _camGroundMargin;

    final rhs = (minY - _orbitCenter.y) / (_radius == 0 ? 0.0001 : _radius);
    final clampedRhs = rhs.clamp(-0.999, 0.999);
    final dynamicMinPitch = math.asin(clampedRhs);

    final minPitch = math.max(_minPitchHard, dynamicMinPitch);
    _pitch = _pitch.clamp(minPitch, _maxPitch);

    final cp = math.cos(_pitch);
    final sp = math.sin(_pitch);
    final cy = math.cos(_yaw);
    final sy = math.sin(_yaw);

    final x = _orbitCenter.x + _radius * cp * sy;
    final y = _orbitCenter.y + _radius * sp;
    final z = _orbitCenter.z + _radius * cp * cy;

    threeJsRef.camera.position.setValues(x, y, z);
    threeJsRef.camera.lookAt(_lookAt);
    _updateFocusScreenPosition(threeJsRef);
  }

  void _updateFocusScreenPosition(three.ThreeJS js) {
    final markerAllowed = _showFocusMarker && !_isInteracting && !_snapActive;

    if (!markerAllowed || _focusAnchor == null) {
      _focusScreen.value = null;
      return;
    }

    final p = _focusAnchor!.clone();
    p.project(js.camera);

    if (p.z > 1) {
      _focusScreen.value = null;
      return;
    }

    final sx = (p.x + 1) * 0.5 * js.width;
    final sy = (1 - (p.y + 1) * 0.5) * js.height;

    _focusScreen.value = Offset(sx, sy);
  }

  double _lerpAngle(double a, double b, double t) {
    var d = (b - a);
    while (d > math.pi) d -= 2 * math.pi;
    while (d < -math.pi) d += 2 * math.pi;
    return a + d * t;
  }

  void _startSnapBackTo({
    required double yaw,
    required double pitch,
    required three.Vector3 lookAt,
    required double radius,
  }) {
    if (_focusAnchor == null) return;
    _snapFromCenter = _orbitCenter.clone();
    _snapToCenter = _focusAnchor!.clone();

    _snapActive = true;
    _snapT = 0.0;

    _snapFromYaw = _yaw;
    _snapToYaw = yaw;

    _snapFromPitch = _pitch;
    _snapToPitch = pitch;

    _snapFromLookAt = _lookAt.clone();
    _snapToLookAt = lookAt.clone();

    _snapFromRadius = _radius;
    _snapToRadius = radius;
  }

  void _snapViewToAnchor() {
    if (_focusAnchor == null) return;

    // orbitCenter -> anchor yönü
    final v = _focusAnchor!.clone().sub(_treeCenter);
    final len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    if (len < 1e-6) return;

    v.x /= len;
    v.y /= len;
    v.z /= len;

    // kameranın yönü anchor'a doğru bakarken, kamerayı anchor'ın "önüne" al
    final camDir = three.Vector3(-v.x, -v.y, -v.z);

    final desiredYaw = math.atan2(camDir.x, camDir.z);
    final desiredPitch = math.asin(camDir.y).clamp(_minPitchHard, _maxPitch);

    _startSnapBackTo(
      yaw: desiredYaw,
      pitch: desiredPitch,
      lookAt: _focusAnchor!.clone(),
      radius: _defaultRadius,
    );
  }

  void _jumpViewToAnchor() {
    if (_focusAnchor == null) return;

    // orbitCenter -> anchor yönü
    final v = _focusAnchor!.clone().sub(_orbitCenter);
    final len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    if (len < 1e-6) return;

    v.x /= len;
    v.y /= len;
    v.z /= len;

    // kamerayı anchor'ın "ön" tarafına al
    final camDir = three.Vector3(-v.x, -v.y, -v.z);

    _yaw = math.atan2(camDir.x, camDir.z);
    _pitch = math.asin(camDir.y).clamp(_minPitchHard, _maxPitch);

    _lookAt = _focusAnchor!.clone();
    _radius = _defaultRadius.clamp(_minRadius, _maxRadius);

    // marker ilk açılışta görünür olsun (ama snap yoksa)
    _showFocusMarker = true;
  }

  void _tickSnap(double dt) {
    if (!_snapActive || _isInteracting) return;

    const duration = 0.35;
    _snapT += dt / duration;

    if (_snapT >= 1.0) {
      _snapT = 1.0;
      _snapActive = false;

      _showFocusMarker = true;
    }

    final t = _snapT;
    final s = t * t * (3 - 2 * t); // smoothstep

    _yaw = _lerpAngle(_snapFromYaw, _snapToYaw, s);
    _pitch = (_snapFromPitch + (_snapToPitch - _snapFromPitch) * s)
        .clamp(_minPitchHard, _maxPitch);

    _orbitCenter = three.Vector3(
      _snapFromCenter.x + (_snapToCenter.x - _snapFromCenter.x) * s,
      _snapFromCenter.y + (_snapToCenter.y - _snapFromCenter.y) * s,
      _snapFromCenter.z + (_snapToCenter.z - _snapFromCenter.z) * s,
    );

    // focus'ta lookAt = center daha iyi hissettirir
    _lookAt = _orbitCenter.clone();


    _radius = (_snapFromRadius + (_snapToRadius - _snapFromRadius) * s)
        .clamp(_minRadius, _maxRadius);
  }




  void _onScaleStart(ScaleStartDetails d) {
    _isInteracting = true;
    _showFocusMarker = false;
    _snapActive = false;

    // Sadece "seçili nokta varsa" ve "gerçek drag başlarsa" yapacağız.
    _pendingTreeModeShift = (_focusAnchor != null);
    _treeModeShiftDoneThisGesture = false;

    _startYaw = _yaw;
    _startPitch = _pitch;
    _startRadius = _radius;
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _isInteracting = false;
    _pendingTreeModeShift = false;
    _treeModeShiftDoneThisGesture = false;

    if (_focusAnchor == null) {
      _showFocusMarker = false;
      return;
    }

    _showFocusMarker = false;
    _snapViewToAnchor();
  }



  void _onScaleUpdate(ScaleUpdateDetails d) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    final dx = d.focalPointDelta.dx / (w == 0 ? 1 : w);
    final dy = d.focalPointDelta.dy / (h == 0 ? 1 : h);

    // Drag gerçekten başladı mı? (küçük eşik)
    final moved = (d.focalPointDelta.dx.abs() + d.focalPointDelta.dy.abs()) > 0.8;
    final scaled = (d.scale - 1.0).abs() > 0.002;

    if (_pendingTreeModeShift && !_treeModeShiftDoneThisGesture && (moved || scaled)) {
      _startTreeModeFast();                // artık tree center’a hızlı geç
      _treeModeShiftDoneThisGesture = true;
      _pendingTreeModeShift = false;
    }


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
    final profilePhotoUrl = user?['profile_photo_url'] as String?;
    final bio = user?['bio']?.toString() ?? '';


    final isFollowing = st.profileJson?['viewer_state']['is_following'] == true;
    final isMe = st.profileJson?['viewer_state']['is_me'] == true;
    final isBlocked = st.profileJson?['viewer_state']['is_blocked'] == true;

    final int effectiveFollowerCount =
    (followerCount + _uiFollowerDelta).clamp(0, 1 << 30);

    bool effectiveIsFollowing = _uiIsFollowing ?? isFollowing;


    final followState = ref.watch(
      followControllerProvider(username),
    );

    if (followState is FollowIdle && followState.isFollowing != null) {
      effectiveIsFollowing = followState.isFollowing!;
    }

    final followLoading = followState is FollowLoading;


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
                onScaleEnd: _onScaleEnd,
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
                  // Back button (aynı)
                  IgnorePointer(
                    ignoring: _profileCardOpen, // kart açıkken tıklanmasın
                    child: ClipOval(
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
                                child: Icon(Icons.chevron_left, size: 30, color: Colors.black),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // SMALL AVATAR (sağ üst)
          Positioned(
            top: topInset + 10,
            right: 14,
            child: IgnorePointer(
              ignoring: _profileCardOpen, // kart açıkken tıklanmasın
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _profileCardOpen ? 0.0 : 1.0, // kart açılınca kaybol
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Material(
                      color: Colors.white.withOpacity(0.35),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _toggleProfileCard,
                        customBorder: const CircleBorder(),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: ClipOval(
                              child: (defaultAvatar != null)
                                  ? ChaputCircleAvatar(
                                      isDefaultAvatar: profilePhotoKey == null || profilePhotoKey == "",
                                      imageUrl: profilePhotoUrl != null && profilePhotoUrl != ""
                                          ? profilePhotoUrl
                                          : defaultAvatar,
                                    )
                                  : const ColoredBox(color: Colors.transparent),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),


          // Expanded profile card overlay
          Positioned(
            left: 0,
            right: 0,
            top: topInset + 10,

            child: IgnorePointer(
              ignoring: !_profileCardOpen,
              child: AnimatedBuilder(
                animation: _profileCardT,
                builder: (_, __) {
                  final t = _profileCardT.value;

                  // ufak slide + fade
                  final dy = (1 - t) * -10; // yukarıdan gelsin
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, dy),
                      child: Transform.scale(
                        scale: 0.98 + 0.02 * t,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,

                              // Bu layer'ın üstü, bulunduğu Positioned'ın üstünden
                              // topInset+10 yukarı çıkıp ekranın en üstüne oturur:
                              top: -(topInset + 10),

                              // Altı: içerik yüksekliği kadar kalsın diye 0
                              bottom: 0,

                              child: ClipRRect(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.35),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.25),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // ✅ İÇERİK: senin mevcut içerik aynen
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                    onTap: _toggleProfileCard,
                                    customBorder: const CircleBorder(),
                                    child: SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: ClipOval(
                                        child: (defaultAvatar != null)
                                            ? ChaputCircleAvatar(
                                          isDefaultAvatar: profilePhotoKey == null || profilePhotoKey == "",
                                          imageUrl: profilePhotoUrl != null && profilePhotoUrl != ""
                                              ? profilePhotoUrl
                                              : defaultAvatar,
                                        )
                                            : const ColoredBox(color: Colors.transparent),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 10),

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
                                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                                  ),
                                                  Text(
                                                    '@$username',
                                                    style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.65)),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 6,
                                                    children: [
                                                      _StatChip(value: effectiveFollowerCount, label: 'Takipçi', onTap: () {}),
                                                      _StatChip(value: followingCount, label: 'Takip', onTap: () {}),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // ================= ACTION BUTTON =================
                                            if (isMe)
                                              TextButton(
                                                onPressed: () {
                                                  context.push(Routes.settings);
                                                },
                                                style: TextButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  backgroundColor: Colors.black,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Ayarlar',
                                                  style: TextStyle(fontSize: 12),
                                                ),
                                              )
                                            else
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // FOLLOW / UNFOLLOW
                                                  TextButton(
                                                    onPressed: _uiFollowLoading
                                                        ? null
                                                        : () async {
                                                      if (isBlocked) return;

                                                      setState(() {
                                                        _uiFollowLoading = true;
                                                        if (effectiveIsFollowing) {
                                                          _uiIsFollowing = false;
                                                          _uiFollowerDelta -= 1;
                                                        } else {
                                                          _uiIsFollowing = true;
                                                          _uiFollowerDelta += 1;
                                                        }
                                                      });

                                                      try {
                                                        final ctrl = ref.read(
                                                          followControllerProvider(username).notifier,
                                                        );
                                                        if (effectiveIsFollowing) {
                                                          await ctrl.unfollow();
                                                        } else {
                                                          await ctrl.follow();
                                                        }
                                                      } catch (_) {
                                                        setState(() {
                                                          _uiIsFollowing = null;
                                                          _uiFollowerDelta = 0;
                                                        });
                                                      } finally {
                                                        setState(() {
                                                          _uiFollowLoading = false;
                                                        });
                                                      }
                                                    },
                                                    style: TextButton.styleFrom(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                      backgroundColor: isBlocked
                                                          ? Colors.red.shade200
                                                          : effectiveIsFollowing
                                                          ? Colors.grey.shade300
                                                          : Colors.black,
                                                      foregroundColor:
                                                      effectiveIsFollowing ? Colors.black : Colors.white,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                    ),
                                                    child: _uiFollowLoading
                                                        ? const SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    )
                                                        : Text(
                                                      effectiveIsFollowing ? 'Takibi Bırak' : 'Takip Et',
                                                      style: const TextStyle(fontSize: 12),
                                                    ),
                                                  ),

                                                  const SizedBox(width: 6),

                                                  // THREE DOT MENU
                                                  _MoreActionsButton(username: username),
                                                ],
                                              ),

                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),


          // MARKER (sadece marker ignore pointer)
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<Offset?>(
                valueListenable: _focusScreen,
                builder: (_, off, __) {
                  if (off == null) return const SizedBox.shrink();

                  return Stack(
                    children: [
                      Positioned(
                        left: off.dx - 5,
                        top: off.dy - 5,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 8,
                                spreadRadius: 1,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

// BUTON (marker'dan tamamen bağımsız)
          Positioned(
            right: 14,
            bottom: 14,
            child: SafeArea(
              child: IgnorePointer(
                ignoring: !_threeReady,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Material(
                      color: Colors.white.withOpacity(0.35),
                      child: InkWell(
                        onTap: _pickNewRandomAnchorAndSnap,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome, size: 18, color: Colors.black),
                              SizedBox(width: 8),
                              Text(
                                "Yeni nokta",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
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

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.value,
    required this.label,
    this.onTap,
  });

  final int value;
  final String label;
  final VoidCallback? onTap;

  String _compact(int n) {
    if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1).replaceAll('.0', '')}B';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final v = _compact(value);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          constraints: const BoxConstraints(minHeight: 28), // daha stabil
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                v,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreActionsButton extends StatelessWidget {
  const _MoreActionsButton({
    required this.username,
  });

  final String username;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      radius: 20,
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => _ProfileActionsSheet(username: username),
        );
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.more_vert,
          size: 18,
          color: Colors.black,
        ),
      ),
    );
  }
}

class _ProfileActionsSheet extends StatelessWidget {
  const _ProfileActionsSheet({
    required this.username,
  });

  final String username;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 8,
        bottom: bottomInset > 0 ? bottomInset : 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),

          _ActionTile(
            icon: Icons.remove_circle_outline,
            title: 'Kısıtla',
            subtitle: 'Bu kullanıcının etkileşimleri sınırlandırılır',
            onTap: () {
              Navigator.pop(context);
              // TODO: restrict API
            },
          ),

          _ActionTile(
            icon: Icons.block,
            title: 'Engelle',
            subtitle: 'Bu kullanıcı seni göremez ve etkileşemez',
            destructive: true,
            onTap: () {
              Navigator.pop(context);
              // TODO: block API
            },
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.red : Colors.black;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.black.withOpacity(0.6),
        ),
      ),
      onTap: onTap,
    );
  }
}