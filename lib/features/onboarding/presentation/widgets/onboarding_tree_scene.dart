import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_math/three_js_math.dart' as three_math;

import '../../../../core/constants/app_colors.dart';
import '../../../profile/domain/tree_catalog.dart';
import '../../../profile/presentation/utils/profile_tree_bounds.dart';
import '../../../profile/presentation/utils/tree_model_cache.dart';
import '../../../profile/presentation/widgets/tree_silhouette_shimmer.dart';

class OnboardingTreeScene extends StatefulWidget {
  const OnboardingTreeScene({
    super.key,
    required this.preset,
    required this.activePage,
    required this.onInteractionChanged,
    this.paused = false,
  });

  final TreePreset preset;
  final int activePage;
  final ValueChanged<bool> onInteractionChanged;
  final bool paused;

  @override
  State<OnboardingTreeScene> createState() => _OnboardingTreeSceneState();
}

class _OnboardingTreeSceneState extends State<OnboardingTreeScene> {
  final ValueNotifier<Offset?> _focusScreen = ValueNotifier<Offset?>(null);
  final math.Random _random = math.Random();
  final Map<int, three.Vector3> _pageAnchors = {};

  three.ThreeJS? _threeJs;
  three.Group? _treeGroup;
  Timer? _initTimer;
  String? _loadedPresetId;
  int _threeEpoch = 0;
  bool _ready = false;
  bool _disposed = false;
  String? _error;

  three.Vector3? _focusAnchor;
  bool _isInteracting = false;
  bool _pendingTreeModeShift = false;
  bool _treeModeShiftDoneThisGesture = false;

  double _yaw = 0.0;
  double _pitch = -0.20;
  double _radius = 3.0;
  double _defaultRadius = 3.0;
  double _minRadius = 0.6;
  double _maxRadius = 12.0;
  double _startRadius = 3.0;

  static const double _minPitchHard = -1.15;
  static const double _maxPitch = 0.45;

  three.Vector3 _treeCenter = three.Vector3(0, 0.9, 0);
  three.Vector3 _orbitCenter = three.Vector3(0, 0.9, 0);
  three.Vector3 _lookAt = three.Vector3(0, 0.9, 0);

  bool _centerShiftActive = false;
  double _centerShiftT = 0.0;
  late three.Vector3 _shiftFromCenter;
  late three.Vector3 _shiftToCenter;
  late three.Vector3 _shiftFromLookAt;
  late three.Vector3 _shiftToLookAt;

  bool _snapActive = false;
  double _snapT = 0.0;
  late double _snapFromYaw;
  late double _snapToYaw;
  late double _snapFromPitch;
  late double _snapToPitch;
  late three.Vector3 _snapFromCenter;
  late three.Vector3 _snapToCenter;
  late three.Vector3 _snapFromLookAt;
  late three.Vector3 _snapToLookAt;
  late double _snapFromRadius;
  late double _snapToRadius;

  double _modelHeight = 1.0;
  double _modelMaxDim = 1.0;
  double _groundY = 0.0;
  static const double _camGroundMargin = 0.06;

  StreamSubscription<AccelerometerEvent>? _tiltSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  DateTime? _lastTiltAt;
  double _tiltYaw = 0.0;
  double _tiltPitch = 0.0;
  double _gyroYaw = 0.0;
  double _gyroPitch = 0.0;
  double _parallaxYaw = 0.0;
  double _parallaxPitch = 0.0;

  @override
  void initState() {
    super.initState();
    _startTiltListener();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleThreeCreation(widget.preset);
    });
  }

  @override
  void didUpdateWidget(covariant OnboardingTreeScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preset.id != widget.preset.id) {
      _scheduleThreeCreation(widget.preset);
      return;
    }
    if (oldWidget.paused != widget.paused) {
      _applyRenderPause();
    }
    if (oldWidget.activePage != widget.activePage && _ready) {
      _pickNewRandomAnchorAndSnap();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _initTimer?.cancel();
    _tiltSub?.cancel();
    _gyroSub?.cancel();
    _focusScreen.dispose();
    _disposeThree();
    super.dispose();
  }

  bool get _motionParallaxEnabled =>
      !widget.paused && !_isInteracting && !_snapActive && _focusAnchor != null;

  double _deadzone(double value, double threshold) {
    return value.abs() < threshold ? 0.0 : value;
  }

  void _startTiltListener() {
    _tiltSub =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 80),
        ).listen((event) {
          if (_disposed || !mounted) return;
          if (!_motionParallaxEnabled) {
            _tiltYaw += (0.0 - _tiltYaw) * 0.12;
            _tiltPitch += (0.0 - _tiltPitch) * 0.12;
            return;
          }
          final now = DateTime.now();
          if (_lastTiltAt != null &&
              now.difference(_lastTiltAt!) < const Duration(milliseconds: 70)) {
            return;
          }
          _lastTiltAt = now;
          final nextYaw = _deadzone(
            event.x / 9.8 * 0.115,
            0.004,
          ).clamp(-0.115, 0.115);
          final nextPitch = _deadzone(
            event.y / 9.8 * 0.078,
            0.004,
          ).clamp(-0.078, 0.078);
          _tiltYaw += (nextYaw - _tiltYaw) * 0.08;
          _tiltPitch += (nextPitch - _tiltPitch) * 0.08;
        }, onError: (_) {});

    _gyroSub =
        gyroscopeEventStream(
          samplingPeriod: const Duration(milliseconds: 66),
        ).listen((event) {
          if (_disposed || !mounted) return;
          if (!_motionParallaxEnabled) {
            _gyroYaw *= 0.76;
            _gyroPitch *= 0.76;
            return;
          }
          final yawVelocity = _deadzone(event.y, 0.025);
          final pitchVelocity = _deadzone(event.x, 0.025);
          _gyroYaw = (_gyroYaw + yawVelocity * 0.0065).clamp(-0.055, 0.055);
          _gyroPitch = (_gyroPitch + pitchVelocity * 0.0048).clamp(
            -0.038,
            0.038,
          );
        }, onError: (_) {});
  }

  bool _isCurrentThree(three.ThreeJS js, int epoch) {
    return mounted &&
        !_disposed &&
        identical(_threeJs, js) &&
        _threeEpoch == epoch;
  }

  void _disposeThree() {
    _threeEpoch++;
    try {
      _threeJs?.dispose();
    } catch (_) {}
    _threeJs = null;
    _treeGroup = null;
    _pageAnchors.clear();
    _ready = false;
    _focusAnchor = null;
    _focusScreen.value = null;
  }

  void _scheduleThreeCreation(TreePreset preset) {
    _initTimer?.cancel();
    _initTimer = Timer(const Duration(milliseconds: 320), () {
      if (!mounted || _disposed) return;
      _createThree(preset);
    });
  }

  void _applyRenderPause() {
    final js = _threeJs;
    if (js == null || _disposed) return;
    js.pause = widget.paused;
    if (widget.paused) {
      _resetMarkerStabilizer();
      try {
        js.ticker?.stop(canceled: false);
      } catch (_) {}
      return;
    }
    try {
      final ticker = js.ticker;
      if (ticker != null && !ticker.isActive) {
        ticker.start();
      }
    } catch (_) {}
  }

  void _createThree(TreePreset preset) {
    if (_loadedPresetId == preset.id && _threeJs != null) return;
    _loadedPresetId = preset.id;
    _error = null;
    _disposeThree();
    final epoch = _threeEpoch;

    late final three.ThreeJS js;
    js = three.ThreeJS(
      setup: () => _setup(js, preset, epoch),
      onSetupComplete: () {
        if (!_isCurrentThree(js, epoch)) {
          try {
            js.dispose();
          } catch (_) {}
          return;
        }
        setState(() => _ready = true);
        _applyRenderPause();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_ready) return;
          _pickNewRandomAnchorAndSnap();
        });
      },
    );

    setState(() => _threeJs = js);
  }

  Future<void> _setup(three.ThreeJS js, TreePreset preset, int epoch) async {
    try {
      js.scene = three.Scene();
      js.camera = three.PerspectiveCamera(45, js.width / js.height, 0.01, 2000);

      final renderer = js.renderer;
      if (renderer != null) {
        renderer.setClearColor(three_math.Color.fromHex32(preset.bgColor), 1);
        renderer.shadowMap.enabled = true;
        renderer.shadowMap.type = three.PCFSoftShadowMap;
      }

      js.scene.add(three.AmbientLight(AppColors.chaputWhiteHex, 0.75));

      final dir = three.DirectionalLight(AppColors.chaputWhiteHex, 0.95);
      dir.position.setValues(2.5, 6.0, 3.5);
      dir.castShadow = true;
      dir.shadow!.mapSize.width = 1024;
      dir.shadow!.mapSize.height = 1024;
      dir.shadow!.camera?.near = 0.2;
      dir.shadow!.camera?.far = 80;
      dir.shadow!.camera?.left = -10;
      dir.shadow!.camera?.right = 10;
      dir.shadow!.camera?.top = 10;
      dir.shadow!.camera?.bottom = -10;
      js.scene.add(dir);

      await TreeModelCache.instance.ensureWarm(preset.id);
      if (!_isCurrentThree(js, epoch)) return;

      final loader = three.GLTFLoader(flipY: true)
        ..setPath('assets/tree_models/');
      final gltf = await loader.fromAsset(preset.assetPath);
      if (gltf == null) throw Exception('GLB null (${preset.assetPath})');
      if (!_isCurrentThree(js, epoch)) return;

      final tree = gltf.scene;
      tree.updateMatrixWorld(true);
      final b1 = computeObjectBounds(tree);
      final size1 = sizeOfBounds(b1);
      final scale = size1.y == 0 ? 1.0 : (preset.targetHeight / size1.y);
      tree.scale.setValues(scale, scale, scale);
      tree.updateMatrixWorld(true);

      final b2 = computeObjectBounds(tree);
      final centerX = (b2.min.x + b2.max.x) * 0.5;
      final centerZ = (b2.min.z + b2.max.z) * 0.5;
      tree.position.x -= centerX;
      tree.position.z -= centerZ;
      tree.position.y -= b2.min.y;
      tree.updateMatrixWorld(true);

      final b3 = computeObjectBounds(tree);
      final size3 = sizeOfBounds(b3);
      _modelHeight = size3.y.clamp(0.1, 1000.0);
      _modelMaxDim = math
          .max(size3.x, math.max(size3.y, size3.z))
          .clamp(0.1, 1000.0);
      _groundY = 0.0;
      _treeCenter = three.Vector3(0, (_modelHeight * 0.55).clamp(0.20, 2.0), 0);
      _orbitCenter = _treeCenter.clone();
      _lookAt = _orbitCenter.clone();

      final fovRad = 45.0 * math.pi / 180.0;
      final distance = (_modelMaxDim / 2) / math.tan(fovRad / 2);
      _radius = (distance * 2.05).clamp(0.8, 50.0);
      _defaultRadius = _radius;
      _minRadius = (_radius * 0.28).clamp(0.28, 6.0);
      _maxRadius = (_radius * 3.2).clamp(2.0, 90.0);

      _treeGroup = three.Group()..add(tree);
      _treeGroup!.traverse((obj) {
        if (obj is three.Mesh) {
          obj.castShadow = true;
          obj.receiveShadow = false;
        }
      });
      js.scene.add(_treeGroup!);

      final groundSize = (_modelMaxDim * 20).clamp(10.0, 200.0);
      final groundGeometry = three.PlaneGeometry(groundSize, groundSize);
      final groundMaterial = three.MeshStandardMaterial();
      groundMaterial.color = three_math.Color.fromHex32(preset.bgColor);
      groundMaterial.roughness = 1.0;
      groundMaterial.metalness = 0.0;

      final ground = three.Mesh(groundGeometry, groundMaterial);
      ground.rotation.x = -math.pi / 2;
      ground.position.setValues(0, 0.001, 0);
      ground.receiveShadow = true;
      ground.castShadow = false;
      js.scene.add(ground);

      final half = (_modelMaxDim * 3.5).clamp(3.0, 40.0);
      dir.shadow!.camera?.left = -half;
      dir.shadow!.camera?.right = half;
      dir.shadow!.camera?.top = half;
      dir.shadow!.camera?.bottom = -half;
      dir.shadow!.camera?.near = 0.2;
      dir.shadow!.camera?.far = (half * 7).clamp(40.0, 260.0);

      js.scene.fog = three.Fog(preset.bgColor, _radius * 0.9, _radius * 1.8);

      _updateCamera(js, 0.0);
      js.addAnimationEvent((dt) {
        if (!_isCurrentThree(js, epoch)) return;
        if (widget.paused) return;
        _tickCenterShift(dt);
        _tickSnap(dt);
        _updateCamera(js, dt);
      });
    } catch (e, st) {
      log('Onboarding tree setup error: $e', stackTrace: st);
      if (!_isCurrentThree(js, epoch)) return;
      setState(() => _error = e.toString());
    }
  }

  three.Vector3? _pickRandomAnchor(three.Object3D root) {
    final preferred = <three.Mesh>[];
    final fallback = <three.Mesh>[];

    root.traverse((obj) {
      if (obj is! three.Mesh) return;
      final name = obj.name.toLowerCase();
      if (name.contains('leaves') || name.contains('leaf')) {
        preferred.add(obj);
      } else {
        fallback.add(obj);
      }
    });

    final meshes = preferred.isNotEmpty ? preferred : fallback;
    if (meshes.isEmpty) return null;

    for (var attempt = 0; attempt < 8; attempt++) {
      final mesh = meshes[_random.nextInt(meshes.length)];
      final geo = mesh.geometry;
      if (geo is! three.BufferGeometry) continue;
      final pos = geo.attributes['position'];
      if (pos == null || pos.count <= 0) continue;
      final i = _random.nextInt(pos.count);
      final local = three.Vector3(pos.getX(i), pos.getY(i), pos.getZ(i));
      local.applyMatrix4(mesh.matrixWorld);
      if (local.y < _modelHeight * 0.28) continue;
      return local;
    }

    return null;
  }

  void _pickNewRandomAnchorAndSnap() {
    final group = _treeGroup;
    if (group == null) return;
    group.updateMatrixWorld(true);
    final cached = _pageAnchors[widget.activePage];
    final anchor = cached ?? _pickRandomAnchor(group);
    if (anchor == null) return;
    _pageAnchors[widget.activePage] = anchor.clone();
    _centerShiftActive = false;
    _pendingTreeModeShift = false;
    _treeModeShiftDoneThisGesture = false;
    _focusAnchor = anchor;
    _resetMarkerStabilizer();
    _startSnapToAnchor();
  }

  void _resetMarkerStabilizer() {
    _focusScreen.value = null;
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
    _centerShiftT += dt / 0.12;
    if (_centerShiftT >= 1.0) {
      _centerShiftT = 1.0;
      _centerShiftActive = false;
    }
    final s = _smooth(_centerShiftT);
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

  void _startSnapToAnchor() {
    if (_focusAnchor == null) return;
    final v = _focusAnchor!.clone().sub(_treeCenter);
    final len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    if (len < 1e-6) return;
    v.x /= len;
    v.y /= len;
    v.z /= len;

    final camDir = three.Vector3(-v.x, -v.y, -v.z);
    _snapActive = true;
    _snapT = 0.0;
    _snapFromYaw = _yaw;
    _snapToYaw = math.atan2(camDir.x, camDir.z);
    _snapFromPitch = _pitch;
    _snapToPitch = math.asin(camDir.y).clamp(_minPitchHard, _maxPitch);
    _snapFromCenter = _orbitCenter.clone();
    _snapToCenter = _focusAnchor!.clone();
    _snapFromLookAt = _lookAt.clone();
    _snapToLookAt = _focusAnchor!.clone();
    _snapToLookAt.y = math.max(
      _groundY + 0.08,
      _snapToLookAt.y - (_modelHeight * 0.24).clamp(0.08, 0.18),
    );
    _snapFromRadius = _radius;
    _snapToRadius = (_defaultRadius * 1.1).clamp(_minRadius, _maxRadius);
  }

  void _tickSnap(double dt) {
    if (!_snapActive || _isInteracting) return;
    _snapT += dt / 0.35;
    if (_snapT >= 1.0) {
      _snapT = 1.0;
      _snapActive = false;
    }
    final s = _smooth(_snapT);
    _yaw = _lerpAngle(_snapFromYaw, _snapToYaw, s);
    _pitch = (_snapFromPitch + (_snapToPitch - _snapFromPitch) * s).clamp(
      _minPitchHard,
      _maxPitch,
    );
    _orbitCenter = three.Vector3(
      _snapFromCenter.x + (_snapToCenter.x - _snapFromCenter.x) * s,
      _snapFromCenter.y + (_snapToCenter.y - _snapFromCenter.y) * s,
      _snapFromCenter.z + (_snapToCenter.z - _snapFromCenter.z) * s,
    );
    _lookAt = three.Vector3(
      _snapFromLookAt.x + (_snapToLookAt.x - _snapFromLookAt.x) * s,
      _snapFromLookAt.y + (_snapToLookAt.y - _snapFromLookAt.y) * s,
      _snapFromLookAt.z + (_snapToLookAt.z - _snapFromLookAt.z) * s,
    );
    _radius = (_snapFromRadius + (_snapToRadius - _snapFromRadius) * s).clamp(
      _minRadius,
      _maxRadius,
    );
  }

  void _updateCamera(three.ThreeJS js, double dt) {
    if (_disposed || !mounted) return;
    final minY = _groundY + _camGroundMargin;
    final rhs = (minY - _orbitCenter.y) / (_radius == 0 ? 0.0001 : _radius);
    final dynamicMinPitch = math.asin(rhs.clamp(-0.999, 0.999));
    final minPitch = math.max(_minPitchHard, dynamicMinPitch);
    _pitch = _pitch.clamp(minPitch, _maxPitch);

    final clampedDt = dt.clamp(0.0, 0.08);
    if (_motionParallaxEnabled) {
      final damping = math.pow(0.025, clampedDt).toDouble();
      _gyroYaw *= damping;
      _gyroPitch *= damping;
    } else {
      _gyroYaw += (0.0 - _gyroYaw) * 0.18;
      _gyroPitch += (0.0 - _gyroPitch) * 0.18;
    }

    final targetParallaxYaw = _motionParallaxEnabled
        ? (_tiltYaw + _gyroYaw).clamp(-0.160, 0.160)
        : 0.0;
    final targetParallaxPitch = _motionParallaxEnabled
        ? (_tiltPitch + _gyroPitch).clamp(-0.110, 0.110)
        : 0.0;
    final parallaxFollow = _motionParallaxEnabled
        ? 1 - math.pow(0.0008, clampedDt).toDouble()
        : 0.18;
    _parallaxYaw += (targetParallaxYaw - _parallaxYaw) * parallaxFollow;
    _parallaxPitch += (targetParallaxPitch - _parallaxPitch) * parallaxFollow;

    final finalYaw = _yaw + _parallaxYaw;
    final finalPitch = (_pitch + _parallaxPitch).clamp(minPitch, _maxPitch);

    final cp = math.cos(finalPitch);
    final sp = math.sin(finalPitch);
    final cy = math.cos(finalYaw);
    final sy = math.sin(finalYaw);

    js.camera.position.setValues(
      _orbitCenter.x + _radius * cp * sy,
      _orbitCenter.y + _radius * sp,
      _orbitCenter.z + _radius * cp * cy,
    );
    js.camera.lookAt(_lookAt);
    _updateFocusScreenPosition(js, dt);
  }

  void _updateFocusScreenPosition(three.ThreeJS js, double dt) {
    if (_focusAnchor == null || _isInteracting) {
      _resetMarkerStabilizer();
      return;
    }

    final p = _focusAnchor!.clone()..project(js.camera);
    if (p.z > 1) {
      _resetMarkerStabilizer();
      return;
    }

    final now = Offset(
      (p.x + 1) * 0.5 * js.width,
      (1 - (p.y + 1) * 0.5) * js.height,
    );

    final previous = _focusScreen.value;
    if (previous == null || _snapActive) {
      _focusScreen.value = now;
      return;
    }

    final clampedDt = dt.clamp(0.0, 0.08);
    final follow = 1 - math.pow(0.0012, clampedDt).toDouble();
    _focusScreen.value = Offset.lerp(previous, now, follow);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _isInteracting = true;
    _snapActive = false;
    _resetMarkerStabilizer();
    _pendingTreeModeShift = _focusAnchor != null;
    _treeModeShiftDoneThisGesture = false;
    _startRadius = _radius;
    widget.onInteractionChanged(true);
    if (mounted) setState(() {});
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final size = MediaQuery.sizeOf(context);
    final dx = details.focalPointDelta.dx / (size.width == 0 ? 1 : size.width);
    final dy =
        details.focalPointDelta.dy / (size.height == 0 ? 1 : size.height);
    final moved =
        details.focalPointDelta.dx.abs() + details.focalPointDelta.dy.abs() >
        0.8;
    final scaled = (details.scale - 1.0).abs() > 0.002;

    if (_pendingTreeModeShift &&
        !_treeModeShiftDoneThisGesture &&
        (moved || scaled)) {
      _startCenterShift(toCenter: _treeCenter, toLookAt: _treeCenter);
      _treeModeShiftDoneThisGesture = true;
      _pendingTreeModeShift = false;
    }

    _yaw -= dx * 3.2;
    _pitch += dy * 2.2;
    _radius = (_startRadius / details.scale).clamp(_minRadius, _maxRadius);
    final js = _threeJs;
    if (js != null) _updateCamera(js, 1 / 60);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _isInteracting = false;
    _pendingTreeModeShift = false;
    _treeModeShiftDoneThisGesture = false;
    widget.onInteractionChanged(false);
    _resetMarkerStabilizer();
    if (_focusAnchor != null) {
      _startSnapToAnchor();
    }
    if (mounted) setState(() {});
  }

  double _smooth(double t) => t * t * (3 - 2 * t);

  double _lerpAngle(double a, double b, double t) {
    var d = b - a;
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d < -math.pi) {
      d += 2 * math.pi;
    }
    return a + d * t;
  }

  @override
  Widget build(BuildContext context) {
    final bg = Color(widget.preset.bgColor);
    final js = _threeJs;
    return ColoredBox(
      color: bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (js != null)
            RepaintBoundary(child: SizedBox.expand(child: js.build())),
          if (!_ready && _error == null)
            IgnorePointer(
              child: Center(
                child: TreeSilhouetteShimmer(
                  size: math.min(MediaQuery.sizeOf(context).width * 0.5, 210),
                ),
              ),
            ),
          if (_error != null) const SizedBox.shrink(),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_ready || widget.paused,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: const SizedBox.expand(),
              ),
            ),
          ),
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
                            color: AppColors.chaputWhite,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 8,
                                spreadRadius: 1,
                                color: AppColors.chaputWhite.withValues(
                                  alpha: 0.6,
                                ),
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
        ],
      ),
    );
  }
}
