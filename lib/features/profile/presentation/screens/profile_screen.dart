import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:ui';

import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_math/three_js_math.dart' as three_math;

import '../../../../chaput/application/chaput_decision_controller.dart';
import '../../../../chaput/application/chaput_messages_controller.dart';
import '../../../../chaput/application/chaput_threads_controller.dart';
import '../../../../chaput/data/chaput_api.dart';
import '../../../../chaput/data/chaput_socket.dart';
import '../../../../chaput/domain/chaput_decision.dart';
import '../../../../chaput/domain/chaput_message.dart';
import '../../../../chaput/domain/chaput_thread.dart';
import '../../../../core/config/env.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../billing/data/billing_api_provider.dart';
import '../../../billing/domain/billing_verify_result.dart';
import '../../../me/application/me_controller.dart';
import '../../../user/domain/lite_user.dart';
import '../../../social/application/follow_state.dart';
import '../../../social/application/ui_restriction_override_provider.dart';
import '../../../user/application/profile_controller.dart';
import '../../../user/data/user_api_provider.dart';
import '../../domain/tree_catalog.dart';

import '../../../social/application/follow_controller.dart';
import '../utils/profile_tree_bounds.dart';
import '../widgets/black_glass.dart';
import '../widgets/chaput_ad_offer_sheet.dart';
import '../widgets/chaput_ads_watch_screen.dart';
import '../widgets/chaput_composer_bar.dart';
import '../widgets/chaput_composer_options_sheet.dart';
import '../widgets/chaput_paywall_sheet.dart';
import '../widgets/chaput_reply_bar.dart';
import '../widgets/glass_toast_overlay.dart';
import '../widgets/profile_actions_sheet.dart';
import '../widgets/profile_stat_chip.dart';
import '../widgets/subscription_replace_sheet.dart';
import '../widgets/chaput_thread_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    required this.userId,
    this.initialThreadId,
  });

  final String userId;
  final String? initialThreadId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {

  OverlayEntry? _toastEntry;
  bool _toastShowing = false;

  late final AnimationController _profileCardCtrl;
  late final Animation<double> _profileCardT;
  bool _profileCardOpen = false;

  bool _pendingTreeModeShift = false;
  bool _treeModeShiftDoneThisGesture = false;

  bool? _uiIsFollowing;
  int _uiFollowerDelta = 0;
  bool _uiFollowLoading = false;
  bool? _uiRequestedFollow;

  // ===== COMPOSER (Chaput bağla) =====
  final TextEditingController _msgCtrl = TextEditingController();
  final FocusNode _msgFocus = FocusNode();

  late final ChaputSocketClient _socketClient;
  StreamSubscription<ChaputSocketEvent>? _socketSub;
  String? _socketProfileId;
  String? _socketThreadId;
  final Map<String, Set<String>> _typingUsersByThread = {};
  bool _activeThreadIsParticipant = false;
  String? _activeThreadId;
  ChaputThreadsArgs? _lastChaputArgs;

  bool _composerOpen = false;                 // input bar açık mı?
  three.Vector3? _draftAnchor;                // mesaj varken hatırlanan anchor
  three.Vector3? _activeAnchor;               // şu an focus olunan anchor (genelde _focusAnchor)

  bool get _composerHasKeyboard => MediaQuery.of(context).viewInsets.bottom > 0;
  double _composerPitchBias = 0.0;

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
  bool _navToOtherProfile = false;

  String? _lastTreeId;
  String? _lastProfileUserId;

  three.Group? _treeGroup;
  three.Mesh? _ground;
  ChaputThreadItem? _pendingThreadFocus;
  String? _pendingInitialThreadId;
  bool _initialThreadApplied = false;
  String? _pendingThreadProfileId;

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

  // ===== SILHOUETTE MODE =====
  bool _silhouetteMode = false;
  bool _silhouetteApplied = false;

  // ===== COMPOSER OPTIONS =====
  bool _anonMode = false;     // "Kimliğini gizle"
  bool _highlightMode = false; // "Öne çıkar" (şimdilik dummy)

  // ===== CHAPUT DECISION / ENTITLEMENTS =====
  bool _chaputThreadCreated = false;
  bool _chaputSendLoading = false;
  final PageController _chaputPageCtrl = PageController();
  int _chaputActiveIndex = 0;
  static const double _chaputSheetMin = 0.12;
  static const double _chaputSheetMid = 0.33;
  static const double _chaputSheetMax = 0.95;

  double _chaputSheetExtent = _chaputSheetMin;
  double _chaputSheetPrevExtent = _chaputSheetMin;
  final DraggableScrollableController _chaputSheetCtrl = DraggableScrollableController();
  bool _sheetAutoExpanded = false;
  double _sheetExtentBeforeKeyboard = _chaputSheetMin;
  String? _chaputProfileId;
  String? _focusedThreadId;
  String? _decisionProfileId;
  DateTime? _lastDecisionFetchAt;
  String? _replyBarThreadId;
  ChaputMessage? _replyTarget;
  String? _replyTargetThreadId;

  String _planType = 'FREE';
  String? _planPeriod;
  int _creditNormal = 0;
  int _creditHidden = 0;
  int _creditSpecial = 0;
  int _creditRevive = 0;
  int _creditWhisper = 0;

  bool _adsCanWatch = false;
  int _adsWatchedToday = 0;
  int _adsRewardsToday = 0;
  int _adsNextRewardIn = 0;

  String _decisionPath = 'FORBIDDEN';
  bool _decisionCanStart = false;
  bool _decisionLoaded = false;
  bool _decisionHasThread = false;

  bool get canHideCredentials => _creditHidden > 0;
  bool get canBoost => _creditSpecial > 0;

  bool _replyWhisperMode = false;

  // orijinal material'ları saklamak için
  final Map<three.Mesh, dynamic> _origMaterials = {};

  @override
  void initState() {
    super.initState();
    _socketClient = ref.read(chaputSocketProvider);
    _pendingInitialThreadId = widget.initialThreadId;
    _navToOtherProfile = false;
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
    _msgFocus.addListener(() {
      if (!_msgFocus.hasFocus) {
        _onComposerUnfocus();
      } else {
        _onComposerFocus();
      }
    });
  }

  Future<void> _ensureSocket(String profileIdHex) async {
    if (profileIdHex.length != 32) return;
    await _socketClient.ensureConnected();
    _socketSub ??= _socketClient.events.listen(_handleSocketEvent);
    if (_socketProfileId != profileIdHex) {
      if (_socketProfileId != null) {
        _socketClient.unsubscribeProfile(_socketProfileId!);
      }
      _socketClient.subscribeProfile(profileIdHex);
      _socketProfileId = profileIdHex;
    }
  }

  void _subscribeThreadSocket(String threadId, String profileIdHex) {
    if (threadId.isEmpty) return;
    if (_socketThreadId != null && _socketThreadId != threadId) {
      _socketClient.unsubscribeThread(_socketThreadId!);
    }
    _socketClient.subscribeThread(threadId, profileId: profileIdHex);
    _socketThreadId = threadId;
  }

  void _clearSocketSubscriptions() {
    if (_socketProfileId != null) _socketClient.unsubscribeProfile(_socketProfileId!);
    if (_socketThreadId != null) _socketClient.unsubscribeThread(_socketThreadId!);
    _socketProfileId = null;
    _socketThreadId = null;
    _typingUsersByThread.clear();
  }

  DateTime? _parseSocketTime(dynamic v) {
    final s = v?.toString();
    if (s == null || s.isEmpty || s == 'null') return null;
    return DateTime.tryParse(s);
  }

  Future<void> _handleSocketEvent(ChaputSocketEvent ev) async {
    final data = ev.data;
    if (ev.type == 'chaput.thread.bump') {
      final profileId = data['profile_id']?.toString();
      if (profileId == null || profileId != _chaputProfileId) return;
      final threadId = data['thread_id']?.toString() ?? '';
      if (threadId.isEmpty) return;
      final item = ChaputThreadItem(
        threadId: threadId,
        userAId: data['user_a_id']?.toString() ?? '',
        userBId: data['user_b_id']?.toString() ?? '',
        starterId: data['starter_id']?.toString() ?? '',
        kind: data['kind']?.toString() ?? 'NORMAL',
        state: data['state']?.toString() ?? 'OPEN',
        lastMessageAt: _parseSocketTime(data['last_message_at']),
        pendingExpiresAt: null,
        createdAt: _parseSocketTime(data['created_at']),
        x: null,
        y: null,
        z: null,
      );
      final args = _lastChaputArgs;
      if (args != null) {
        ref.read(chaputThreadsControllerProvider(args).notifier).upsertThreadFromSocket(item, args);
        final missingIds = <String>{};
        if (!ref.read(chaputThreadsControllerProvider(args)).usersById.containsKey(item.userAId)) {
          missingIds.add(item.userAId);
        }
        if (!ref.read(chaputThreadsControllerProvider(args)).usersById.containsKey(item.userBId)) {
          missingIds.add(item.userBId);
        }
        if (missingIds.isNotEmpty) {
          final api = ref.read(userApiProvider);
          final res = await api.batchLite(userIds: missingIds.toList(growable: false));
          final map = <String, LiteUser>{};
          for (final u in res.items) {
            map[u.id] = u;
          }
          ref.read(chaputThreadsControllerProvider(args).notifier).addUsers(map);
        }
      }
      return;
    }

    if (ev.type == 'chaput.message.created') {
      final threadId = data['thread_id']?.toString() ?? '';
      final msg = data['message'];
      if (threadId.isEmpty || msg is! Map<String, dynamic>) return;
      if (_chaputProfileId == null) return;
      final args = ChaputMessagesArgs(threadId: threadId, profileId: _chaputProfileId!);
      ref.read(chaputMessagesControllerProvider(args).notifier).upsertMessageFromSocket(
            ChaputMessage.fromJson(msg),
          );

      if (_activeThreadId == threadId && _activeThreadIsParticipant) {
        try {
          await ref.read(chaputApiProvider).markThreadRead(threadIdHex: threadId);
        } catch (_) {}
      }
      return;
    }

    if (ev.type == 'chaput.message.like') {
      final threadId = data['thread_id']?.toString() ?? '';
      final msgId = data['message_id']?.toString() ?? '';
      if (threadId.isEmpty || msgId.isEmpty || _chaputProfileId == null) return;
      final args = ChaputMessagesArgs(threadId: threadId, profileId: _chaputProfileId!);
      final likerId = data['user_id']?.toString() ?? '';
      final likeCount = (data['like_count'] ?? 0) as int;
      final liked = data['liked'] == true;
      ChaputMessageLiker? liker;
      final likerJson = data['liker'];
      if (likerJson is Map<String, dynamic>) {
        liker = ChaputMessageLiker.fromJson(likerJson);
      }
      ref.read(chaputMessagesControllerProvider(args).notifier).applyLikeFromSocket(
            messageId: msgId,
            likeCount: likeCount,
            likerId: likerId,
            liked: liked,
            liker: liker,
          );
      return;
    }

    if (ev.type == 'chaput.message.read') {
      final threadId = data['thread_id']?.toString() ?? '';
      final readerId = data['user_id']?.toString() ?? '';
      if (threadId.isEmpty || _chaputProfileId == null) return;
      final meId = ref.read(meControllerProvider).valueOrNull?.user.userId ?? '';
      if (meId.isNotEmpty && readerId == meId) return;
      final argsThreads = _lastChaputArgs;
      if (argsThreads == null) return;
      final thread = ref.read(chaputThreadsControllerProvider(argsThreads)).items
          .where((t) => t.threadId == threadId)
          .cast<ChaputThreadItem?>()
          .firstWhere((t) => t != null, orElse: () => null);
      if (thread == null) return;
      final otherId = thread.userAId == meId
          ? thread.userBId
          : thread.userBId == meId
              ? thread.userAId
              : '';
      if (otherId.isEmpty || readerId != otherId) return;
      final args = ChaputMessagesArgs(threadId: threadId, profileId: _chaputProfileId!);
      ref.read(chaputMessagesControllerProvider(args).notifier).markReadByOther();
      return;
    }

    if (ev.type == 'chaput.typing') {
      final threadId = data['thread_id']?.toString() ?? '';
      final userId = data['user_id']?.toString() ?? '';
      final isTyping = data['is_typing'] == true;
      if (threadId.isEmpty || userId.isEmpty) return;
      final set = _typingUsersByThread.putIfAbsent(threadId, () => <String>{});
      if (isTyping) {
        set.add(userId);
      } else {
        set.remove(userId);
      }
      if (mounted) setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId) {
      _disposeThree(); // user değiştiyse 3D sıfırla
      _lastTreeId = null;
      _threeError = null;
      _threeReady = false;
      _navToOtherProfile = false;
      _chaputThreadCreated = false;
      _decisionProfileId = null;
      _anonMode = false;
      _highlightMode = false;
      _pendingInitialThreadId = widget.initialThreadId;
      _initialThreadApplied = false;
      _msgCtrl.clear();
    }
  }

  @override
  void dispose() {
    _disposeThree();
    three.loading.clear();
    _focusScreen.dispose();
    _profileCardCtrl.dispose();
    _msgCtrl.dispose();
    _msgFocus.dispose();
    _chaputPageCtrl.dispose();
    _socketSub?.cancel();
    _socketSub = null;
    _clearSocketSubscriptions();
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
    try {
      _threeJs?.dispose();
    } catch (_) {}
    _threeJs = null;
    _treeGroup = null;
    _ground = null;
    _threeReady = false;
    _origMaterials.clear();
    _silhouetteApplied = false;
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
        _applyPendingThreadFocus();
      },
    );

    setState(() {
      _threeJs = js;
    });
  }

  void _applyPendingThreadFocus() {
    if (!_threeReady) return;
    final thread = _pendingThreadFocus;
    final pid = _pendingThreadProfileId;
    if (thread == null || pid == null) return;
    _pendingThreadFocus = null;
    _pendingThreadProfileId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusToThreadAnchor(thread, pid);
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
      final b1 = computeObjectBounds(tree);
      final size1 = sizeOfBounds(b1);

      // B) scale
      const targetHeight = 0.55;
      final scale = (size1.y == 0) ? 1.0 : (targetHeight / size1.y);
      tree.scale.setValues(scale, scale, scale);
      tree.updateMatrixWorld(true);

      // C) bounds after scale
      final b2 = computeObjectBounds(tree);
      final size2 = sizeOfBounds(b2);

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
      final b3 = computeObjectBounds(tree);
      final size3 = sizeOfBounds(b3);

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
      _applySilhouetteIfNeeded();

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

      _updateCamera(threeJsRef, 0.0);

      threeJsRef.addAnimationEvent((dt) {
        _tickCenterShift(dt);
        _tickSnap(dt);
        _updateCamera(threeJsRef, dt);
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

  // ===== MARKER STABILIZER =====
  Offset? _lastProjected;
  double _stableFor = 0.0;

  // Ne kadar süre stabil kalınca marker açılsın (arttır: 0.6, 0.8, 1.0)
  static const double _needStableSeconds = 0.35;

  // Piksel toleransı (azalt: daha hassas, arttır: daha toleranslı)
  static const double _stablePxEps = 1.5;

  void _resetMarkerStabilizer() {
    _lastProjected = null;
    _stableFor = 0.0;
    _showFocusMarker = false;
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

    _resetMarkerStabilizer();

    // ✅ mevcut durumdan -> yeni anchor'a smooth geç
    _startSnapToNewAnchor();
  }

  bool _isBlankDraft() {
    // sadece whitespace ise boş kabul
    return _msgCtrl.text.trim().isEmpty;
  }

  void _openComposer() {
    if (_composerOpen) return;
    setState(() => _composerOpen = true);

    // klavyeyi aç
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_msgFocus);
    });
  }

  void _closeComposer() {
    if (!_composerOpen) return;
    setState(() => _composerOpen = false);
    FocusScope.of(context).unfocus();
  }

  void _openComposerOptionsSheet() {
    // Klavye açıkken sheet görünür alanı aşmasın diye kb’yi alıyoruz
    final kb = MediaQuery.of(context).viewInsets.bottom;
    if (kb > 0 && !_composerOpen && _chaputSheetExtent < _chaputSheetMax - 0.01) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_chaputSheetCtrl.isAttached) return;
        _chaputSheetCtrl.animateTo(
          _chaputSheetMax,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            // sheet’i klavyenin üstüne "oturt"
            bottom: (kb > 0 ? kb : 12) + 10,
          ),
          child: ComposerOptionsSheet(
            anonEnabled: _anonMode,
            highlightEnabled: _highlightMode,

            onToggleAnon: (v) {
              if (!canHideCredentials && v == true) {
                Navigator.pop(context);
                _openHiddenPaywall();
                return;
              }
              setState(() => _anonMode = v);
              Navigator.pop(context);
            },

            onToggleHighlight: (v) {
              if (!canBoost && v == true) {
                Navigator.pop(context);
                _openBoostPaywall();
                return;
              }
              setState(() => _highlightMode = v);
              Navigator.pop(context);
            },

            onPaywallAnon: canHideCredentials
                ? null
                : () {
                    Navigator.pop(context);
                    _openHiddenPaywall();
                  },
            onPaywallBoost: canBoost
                ? null
                : () {
                    Navigator.pop(context);
                    _openBoostPaywall();
                  },
          ),

        );
      },
    );
  }

  void _showGlassToast(
      String message, {
        IconData icon = Icons.info_outline,
        Duration duration = const Duration(milliseconds: 900),
      }) {
    if (!mounted) return;

    _toastEntry?.remove();
    _toastEntry = null;

    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    if (overlay == null) return;

    final mq = MediaQuery.of(context);
    final kb = mq.viewInsets.bottom;
    const composerH = 72.0;
    const gap = 12.0;

    final bottom = kb + composerH + gap;

    _toastShowing = true;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => GlassToastOverlay(
        message: message,
        icon: icon,
        bottom: bottom,
        duration: duration,
        onDone: () {
          if (!_toastShowing) return;
          _toastShowing = false;
          if (entry.mounted) entry.remove();
          if (_toastEntry == entry) _toastEntry = null;
        },
      ),
    );

    _toastEntry = entry;
    overlay.insert(entry);
  }

  String _resolveProfileId(Map<String, dynamic>? profileJson, String fallback) {
    if (profileJson == null) return fallback;
    final user = (profileJson['user'] is Map) ? (profileJson['user'] as Map) : null;
    final direct = profileJson['profile_id']?.toString();
    final fromUser = user?['profile_id']?.toString();
    final userId = user?['id']?.toString();
    return direct ?? fromUser ?? userId ?? fallback;
  }

  void _applyBillingResult(BillingVerifyResult result) {
    if (_decisionProfileId == null) return;
    final decisionCtrl = ref.read(
      chaputDecisionControllerProvider(_decisionProfileId!).notifier,
    );
    decisionCtrl.applyPlanType(result.planType);
    if (result.planPeriod != null && result.planPeriod!.isNotEmpty) {
      decisionCtrl.applyPlanPeriod(result.planPeriod!);
    }
    decisionCtrl.setCredits(
      normal: result.credits.normal,
      hidden: result.credits.hidden,
      special: result.credits.special,
      revive: result.credits.revive,
      whisper: result.credits.whisper,
    );
    // Refresh /me so subscription state is up to date for future warnings.
    ref.read(meControllerProvider.notifier).fetchAndStoreMe();
  }

  Future<bool> _verifyPurchaseAndApply(PaywallPurchase purchase) async {
    try {
      final confirmed = await _confirmReplaceSubscriptionIfNeeded(purchase);
      if (!confirmed) return false;
      final api = ref.read(billingApiProvider);
      final res = await api.verifyPurchase(
        provider: purchase.provider,
        productId: purchase.productId,
        transactionId: purchase.transactionId,
        devToken: Env.devBillingToken,
      );
      _applyBillingResult(res);
      return true;
    } catch (_) {
      _showGlassToast('Satın alma doğrulanamadı', icon: Icons.error_outline);
      return false;
    }
  }

  Future<bool> _confirmReplaceSubscriptionIfNeeded(PaywallPurchase purchase) async {
    const subscriptionProducts = <String>{
      'chaput_plus_month',
      'chaput_pro_month',
      'chaput_pro_year',
    };
    if (!subscriptionProducts.contains(purchase.productId)) return true;

    final meAsync = ref.read(meControllerProvider);
    var me = meAsync.valueOrNull;
    if (me == null) {
      try {
        me = await ref.read(meControllerProvider.notifier).fetchAndStoreMe();
      } catch (_) {}
    }

    final plan = me?.subscription.plan ?? _planType;
    final expiresAtRaw = me?.subscription.expiresAt;

    DateTime? expiresAt;
    if (expiresAtRaw != null && expiresAtRaw.isNotEmpty) {
      expiresAt = DateTime.tryParse(expiresAtRaw);
      if (expiresAt != null && !expiresAt.isUtc && !expiresAtRaw.contains('Z')) {
        expiresAt = DateTime.parse('${expiresAtRaw}Z');
      }
    }

    if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) return true;

    // Only warn when we have a non-free active plan.
    if (plan == 'FREE') return true;

    final untilText = expiresAt != null
        ? expiresAt.toLocal().toString().split('.').first
        : null;
    final res = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SubscriptionReplaceSheet(
        untilText: untilText,
      ),
    );
    return res == true;
  }

  Future<bool> _openAdOfferSheet({required int requiredAds, required bool canWatch}) async {
    final res = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChaputAdOfferSheet(
        requiredAds: requiredAds,
        canWatch: canWatch,
      ),
    );
    return res == true;
  }

  Future<bool> _openAdsWatchScreen({required int requiredAds}) async {
    if (_decisionProfileId == null) return false;
    final api = ref.read(chaputApiProvider);
    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChaputAdsWatchScreen(
          requiredAds: requiredAds,
          onComplete: () async {
            try {
              final sessionId = await api.startAdRewardSession(
                requiredAds: requiredAds,
              );
              if (sessionId.isEmpty) return false;
              await api.claimAdReward(
                sessionId: sessionId,
                watchedCount: requiredAds,
              );
              ref
                  .read(chaputDecisionControllerProvider(_decisionProfileId!).notifier)
                  .fetchDecision();
              return true;
            } catch (_) {
              return false;
            }
          },
        ),
      ),
    );
    return res == true;
  }

  void _prepareComposer() {
    _pickNewRandomAnchorAndSnap(); // random anchor + snap
    _openComposer();
  }

  void _focusToThreadAnchor(ChaputThreadItem thread, String profileIdHex) {
    if (!_threeReady || _treeGroup == null) {
      _pendingThreadFocus = thread;
      _pendingThreadProfileId = profileIdHex;
      return;
    }
    if (thread.hasCoords()) {
      _focusAnchor = three.Vector3(thread.x!, thread.y!, thread.z!);
      _showFocusMarker = false;
      _resetMarkerStabilizer();
      _startSnapToNewAnchor();
      return;
    }

    final g = _treeGroup;
    if (g == null) return;
    g.updateMatrixWorld(true);
    final newAnchor = _pickRandomLeafAnchor(g);
    if (newAnchor == null) return;
    _focusAnchor = newAnchor;
    _showFocusMarker = false;
    _resetMarkerStabilizer();
    _startSnapToNewAnchor();

    // Persist node for this profile if empty.
    final api = ref.read(chaputApiProvider);
    api.setThreadNode(
      threadIdHex: thread.threadId,
      profileIdHex: profileIdHex,
      x: newAnchor.x,
      y: newAnchor.y,
      z: newAnchor.z,
    );
  }

  OverlayEntry _showNavMask() {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) {
        return Positioned.fill(
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              builder: (ctx, t, _) {
                return Container(
                  color: Colors.black.withOpacity(0.12 * t),
                );
              },
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    return entry;
  }

  Future<void> _openThreadCounterpartyProfile({
    required String userId,
    required String threadId,
  }) async {
    if (userId.isEmpty || userId == widget.userId) return;
    FocusScope.of(context).unfocus();

    setState(() => _navToOtherProfile = true);
    _disposeThree();

    final mask = _showNavMask();
    final router = GoRouter.of(context);
    router.go(Routes.home);
    await Future.delayed(const Duration(milliseconds: 140));
    router.push('/profile/$userId', extra: {'threadId': threadId});
    await Future.delayed(const Duration(milliseconds: 220));
    if (mask.mounted) mask.remove();
  }

  void _handleReplyRequested(ChaputThreadItem thread, ChaputMessage message) {
    setState(() {
      _replyTarget = message;
      _replyTargetThreadId = thread.threadId;
      _replyBarThreadId = thread.threadId;
    });
    if (_chaputSheetCtrl.isAttached && _chaputSheetExtent < _chaputSheetMid) {
      _chaputSheetCtrl.animateTo(
        _chaputSheetMid,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendThreadMessage({
    required ChaputThreadItem thread,
    required String body,
    required bool whisper,
    required String profileIdHex,
    required ChaputThreadsArgs chaputArgs,
    required String viewerId,
  }) async {
    if (body.trim().isEmpty) return;
    final api = ref.read(chaputApiProvider);
    final kind = whisper ? 'WHISPER' : 'NORMAL';
    final replyToId = (_replyTarget != null && _replyTargetThreadId == thread.threadId)
        ? _replyTarget!.id
        : null;
    final replyTarget = (_replyTarget != null && _replyTargetThreadId == thread.threadId) ? _replyTarget : null;
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final meId = ref.read(meControllerProvider).valueOrNull?.user.userId ?? viewerId;
    final msg = ChaputMessage(
      id: localId,
      senderId: meId.isNotEmpty ? meId.toLowerCase() : '',
      kind: kind,
      body: body,
      createdAt: DateTime.now().toUtc(),
      replyToId: replyTarget?.id,
      replyToSenderId: replyTarget?.senderId,
      replyToBody: replyTarget?.body,
      likeCount: 0,
      likedByMe: false,
      delivered: false,
      readByOther: false,
      topLikers: const [],
    );
    ref
        .read(
          chaputMessagesControllerProvider(
            ChaputMessagesArgs(threadId: thread.threadId, profileId: profileIdHex),
          ).notifier,
        )
        .addLocalMessage(msg);

    try {
      final serverMsg =
          await api.sendMessage(threadIdHex: thread.threadId, body: body, kind: kind, replyToId: replyToId);
      ref
          .read(
            chaputMessagesControllerProvider(
              ChaputMessagesArgs(threadId: thread.threadId, profileId: profileIdHex),
            ).notifier,
          )
          .confirmDelivered(localId: localId, serverMessage: serverMsg);

      if (thread.state == 'PENDING') {
        ref
            .read(chaputThreadsControllerProvider(chaputArgs).notifier)
            .updateThreadState(threadId: thread.threadId, newState: 'OPEN', pendingExpiresAt: null);
      }
    } catch (_) {
      // leave local message as-is; UI already shows it as sent but undelivered
    }

    setState(() {
      _replyTarget = null;
      _replyTargetThreadId = null;
    });
  }

  Future<void> _makeThreadHidden({
    required ChaputThreadItem thread,
    required String profileIdHex,
    required ChaputThreadsArgs chaputArgs,
  }) async {
    final api = ref.read(chaputApiProvider);

    // ✅ 1) fresh decision'ı direkt API sonucundan al (race yok)
    final decisionNotifier =
        ref.read(chaputDecisionControllerProvider(profileIdHex).notifier);

    ChaputDecision? freshDecision;
    try {
      freshDecision = await api.getDecision(profileIdHex);
      decisionNotifier.setCredits(
        normal: freshDecision.credits.normal,
        hidden: freshDecision.credits.hidden,
        special: freshDecision.credits.special,
        revive: freshDecision.credits.revive,
        whisper: freshDecision.credits.whisper,
      );
      decisionNotifier.applyPlanType(freshDecision.plan.type);
      if (freshDecision.plan.period != null && freshDecision.plan.period!.isNotEmpty) {
        decisionNotifier.applyPlanPeriod(freshDecision.plan.period!);
      }
    } catch (_) {
      freshDecision = await decisionNotifier.fetchDecisionAndReturn();
    }
    final freshHidden = freshDecision?.credits.hidden ?? 0;

    Future<bool> _hideNow() async {
      try {
        await api.hideThread(threadIdHex: thread.threadId);
        return true;
      } catch (_) {
        return false;
      }
    }

    // ✅ 2) kredi varsa direkt gizle
    if (freshHidden > 0) {
      final ok = await _hideNow();
      if (!ok) {
        _showGlassToast('Chaput gizlenemedi', icon: Icons.error_outline);
        return;
      }

      // UI/State: 1 kredi düş
      decisionNotifier.applyCreditsDelta(hidden: -1);
      ref
          .read(chaputThreadsControllerProvider(chaputArgs).notifier)
          .updateThreadKind(thread.threadId, 'HIDDEN');

      _showGlassToast('Chaput gizlendi', icon: Icons.lock_outline);
      return;
    }

    // ✅ 3) kredi yoksa paywall
    final purchase = await _openPaywall(feature: PaywallFeature.hideCredentials);
    if (purchase == null) return;

    final verified = await _verifyPurchaseAndApply(purchase);
    if (!verified) return;

    // Satın aldıktan sonra tekrar dene (istersen tekrar fetch yap)
    final ok = await _hideNow();
    if (!ok) {
      _showGlassToast('Chaput gizlenemedi', icon: Icons.error_outline);
      return;
    }

    // satın alma doğrulandıysa server zaten krediyi yazmış olmalı,
    // ama UI için güvenli şekilde local düşür / güncelle
    decisionNotifier.applyCreditsDelta(hidden: -1);
    ref
        .read(chaputThreadsControllerProvider(chaputArgs).notifier)
        .updateThreadKind(thread.threadId, 'HIDDEN');

    _showGlassToast('Chaput gizlendi', icon: Icons.lock_outline);
  }

  Future<void> _sendChaputMessage({
    required String profileId,
    required String viewerId,
    required String targetUserId,
    required LiteUser? viewerLite,
    required ChaputThreadsArgs chaputArgs,
  }) async {
    if (_chaputSendLoading) return;
    if (profileId.length != 32) {
      _showGlassToast('Profil bulunamadı', icon: Icons.error_outline);
      return;
    }
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) {
      _showGlassToast('Önce mesajını yaz', icon: Icons.edit_outlined);
      return;
    }

    setState(() => _chaputSendLoading = true);
    try {
      final api = ref.read(chaputApiProvider);
      final kind = _highlightMode
          ? 'SPECIAL'
          : (_anonMode ? 'HIDDEN' : 'NORMAL');

      final anchor = _focusAnchor ?? _draftAnchor;

    final out = await api.startThread(
      profileIdHex: profileId,
      kind: kind,
    );

    if (out.threadId.isNotEmpty && anchor != null) {
      await api.setThreadNode(
          threadIdHex: out.threadId,
          profileIdHex: profileId,
          x: anchor.x,
          y: anchor.y,
          z: anchor.z,
        );
      }

    if (out.threadId.isNotEmpty) {
      final now = DateTime.now().toUtc();
      final created = ChaputThreadItem(
        threadId: out.threadId,
        userAId: viewerId,
        userBId: targetUserId,
        starterId: viewerId,
        kind: kind,
        state: 'PENDING',
        lastMessageAt: now,
        pendingExpiresAt: null,
        createdAt: now,
        x: anchor?.x,
        y: anchor?.y,
        z: anchor?.z,
      );
      final chaputCtrl = ref.read(chaputThreadsControllerProvider(chaputArgs).notifier);
      chaputCtrl.addThreadOptimistic(created, chaputArgs);
      if (viewerLite != null) {
        chaputCtrl.addUsers({viewerLite.id: viewerLite});
      }
      await api.sendMessage(threadIdHex: out.threadId, body: text);
    }

      _chaputThreadCreated = true;
      _msgCtrl.clear();
      _closeComposer();
      _showGlassToast('Chaput gönderildi', icon: Icons.check_circle_outline);
      if (_decisionProfileId != null) {
        ref
            .read(chaputDecisionControllerProvider(_decisionProfileId!).notifier)
            .fetchDecision();
      }
    } catch (e) {
      _showGlassToast('Chaput gönderilemedi', icon: Icons.error_outline);
    } finally {
      if (mounted) {
        setState(() => _chaputSendLoading = false);
      }
    }
  }

  Future<void> _handleRevivePressed({
    required String threadIdHex,
    required String profileIdHex,
    required ChaputThreadsArgs chaputArgs,
    required LiteUser? targetUser,
  }) async {
    if (threadIdHex.length != 32) {
      _showGlassToast('Chaput bulunamadı', icon: Icons.error_outline);
      return;
    }
    final api = ref.read(chaputApiProvider);
    final isPro = _planType == 'PRO';
    final hasRevive = _creditRevive > 0;

    if (!isPro && !hasRevive) {
      final reviveTarget = targetUser == null
          ? null
          : PaywallReviveTarget(
              avatarUrl: (targetUser.profilePhotoKey != null && targetUser.profilePhotoKey!.isNotEmpty)
                  ? targetUser.profilePhotoKey!
                  : targetUser.defaultAvatar,
              isDefaultAvatar: targetUser.profilePhotoKey == null || targetUser.profilePhotoKey!.isEmpty,
              fullName: targetUser.fullName,
                                    username: targetUser.username ?? '',
            );
      final purchase = await _openPaywall(feature: PaywallFeature.revive, reviveTarget: reviveTarget);
      if (purchase == null) return;
      final ok = await _verifyPurchaseAndApply(purchase);
      if (!ok) return;
    }

    try {
      await api.reviveThread(threadIdHex: threadIdHex);
      ref.read(chaputThreadsControllerProvider(chaputArgs).notifier).refresh();
      if (_decisionProfileId != null) {
        ref.read(chaputDecisionControllerProvider(profileIdHex).notifier).fetchDecision();
      }
      _showGlassToast('Chaput kurtarıldı', icon: Icons.check_circle_outline);
    } catch (e) {
      _showGlassToast('Chaput kurtarılamadı', icon: Icons.error_outline);
    }
  }


  void _onOptionsEmptyTap() {
    _showGlassToast('Önce mesajını yaz', icon: Icons.edit_outlined);
  }

  Future<void> _handleBindPressed({required String profileId}) async {
    if (_chaputThreadCreated || _composerOpen) return;
    if (profileId.length != 32) {
      _showGlassToast('Profil bulunamadı', icon: Icons.error_outline);
      return;
    }
    if (_decisionProfileId == null) {
      _showGlassToast('Chaput hakların yükleniyor', icon: Icons.hourglass_empty);
      return;
    }
    if (!_decisionLoaded) {
      _showGlassToast('Chaput hakların yükleniyor', icon: Icons.hourglass_empty);
      return;
    }
    if (_decisionHasThread) {
      _showGlassToast('Bu kullanıcıyla zaten chaput var', icon: Icons.chat_bubble_outline);
      return;
    }

    if (!_decisionCanStart || _decisionPath == 'FORBIDDEN') {
      _showGlassToast('Bu kullanıcıyla chaput başlatamazsın', icon: Icons.block);
      return;
    }

    final isPro = _planType == 'PRO';
    final hasNormalCredit = _creditNormal > 0;
    final adsAvailable = _adsCanWatch && _adsNextRewardIn > 0;

    if (_decisionPath == 'CAN_START' || isPro || hasNormalCredit) {
      _prepareComposer();
      return;
    }

    final purchase = await _openPaywall(feature: PaywallFeature.bind);
    if (purchase != null) {
      final ok = await _verifyPurchaseAndApply(purchase);
      if (ok) {
        if (_decisionProfileId != null) {
          ref
              .read(chaputDecisionControllerProvider(_decisionProfileId!).notifier)
              .fetchDecision();
        }
        _prepareComposer();
      }
      return;
    }

    if (!adsAvailable) return;
    final accepted = await _openAdOfferSheet(
      requiredAds: _adsNextRewardIn,
      canWatch: _adsCanWatch,
    );
    if (!accepted) return;

    final ok = await _openAdsWatchScreen(requiredAds: _adsNextRewardIn);
    if (!ok) return;

    _prepareComposer();
  }

  Future<PaywallPurchase?> _openPaywall({
    required PaywallFeature feature,
    PaywallReviveTarget? reviveTarget,
  }) async {
    final me = ref.read(meControllerProvider).valueOrNull;
    final subPlan = me?.subscription.plan;
    final effectivePlanType =
        (_planType.isNotEmpty && _planType != 'FREE') ? _planType : (subPlan ?? _planType);
    final effectivePlanPeriod = _planPeriod;
    return showModalBottomSheet<PaywallPurchase>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (_) => FakePaywallSheet(
        feature: feature,
        planType: effectivePlanType,
        planPeriod: effectivePlanPeriod,
        reviveTarget: reviveTarget,
      ),
    );
  }

  Future<void> _openHiddenPaywall() async {
    final purchase = await _openPaywall(feature: PaywallFeature.hideCredentials);
    if (purchase == null) return;
    final ok = await _verifyPurchaseAndApply(purchase);
    if (!ok) return;
    setState(() => _anonMode = true);
    _openComposer();
  }

  Future<void> _openBoostPaywall() async {
    final purchase = await _openPaywall(feature: PaywallFeature.boost);
    if (purchase == null) return;
    final ok = await _verifyPurchaseAndApply(purchase);
    if (!ok) return;
    setState(() => _highlightMode = true);
    _openComposer();
  }

  void _onComposerFocus() {
    _emitTyping(true);
    // Eğer mesaj var ve daha önce anchor hatırlanmışsa, aynı anchor’a geri focus ol
    if (_draftAnchor != null) {
      _focusAnchor = _draftAnchor!.clone();
      _showFocusMarker = false;
      _resetMarkerStabilizer();
      _snapViewToAnchor(); // geri focus
    }
  }

  void _onComposerUnfocus() {
    _emitTyping(false);
    // composer açık değilse ignore
    if (!_composerOpen) return;

    final hasText = !_isBlankDraft();

    if (!hasText) {
      // 1) mesaj yoksa: temizle, kapat, anchor unut, model unfocus
      _msgCtrl.clear();
      _draftAnchor = null;
      _focusedThreadId = null;

      // focus tamamen kapansın
      _focusAnchor = null;
      _showFocusMarker = false;
      _snapActive = false;

      // orbit’i tree center’a geri al
      _startCenterShift(toCenter: _treeCenter, toLookAt: _treeCenter);

      setState(() => _composerOpen = false);
      return;
    }

    // 2) mesaj varsa: anchor hatırla, ama model "sanki nokta yok" moduna çıksın
    if (_focusAnchor != null) {
      _draftAnchor = _focusAnchor!.clone();
    }

    // model focus modundan çıksın (marker yok)
    _focusAnchor = null;
    _showFocusMarker = false;
    _snapActive = false;

    _startCenterShift(toCenter: _treeCenter, toLookAt: _treeCenter);

    // composer açık kalsın, sadece unfocus edildi (UI aynı kalsın)
  }

  void _emitTyping(bool isTyping) {
    if (!_activeThreadIsParticipant) return;
    final threadId = _activeThreadId;
    if (threadId == null || threadId.isEmpty) return;
    ref.read(chaputSocketProvider).sendTyping(threadId, isTyping);
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


  void _updateCamera(three.ThreeJS js, double dt) {
    final minY = _groundY + _camGroundMargin;

    // 1) ground constraint ile base pitch clamp
    final rhs = (minY - _orbitCenter.y) / (_radius == 0 ? 0.0001 : _radius);
    final dynamicMinPitch = math.asin(rhs.clamp(-0.999, 0.999));
    final minPitch = math.max(_minPitchHard, dynamicMinPitch);

    _pitch = _pitch.clamp(minPitch, _maxPitch);

    // 2) composer bias sadece hesaplanır (pitch'i burada değiştirmez!)
    _adjustCameraForComposer(js);

    // 3) final pitch = base + bias (tek noktada)
    final finalPitch = (_pitch + _composerPitchBias).clamp(minPitch, _maxPitch);

    final cp = math.cos(finalPitch);
    final sp = math.sin(finalPitch);
    final cy = math.cos(_yaw);
    final sy = math.sin(_yaw);

    final x = _orbitCenter.x + _radius * cp * sy;
    final y = _orbitCenter.y + _radius * sp;
    final z = _orbitCenter.z + _radius * cp * cy;

    js.camera.position.setValues(x, y, z);
    js.camera.lookAt(_lookAt);

    // 4) marker HER ZAMAN final kamera ile hesaplanır
    _updateFocusScreenPosition(js, dt);
  }

  void _applySilhouetteIfNeeded() {
    final g = _treeGroup;
    if (g == null) return;

    if (_silhouetteMode) {
      if (_silhouetteApplied) return;
      _silhouetteApplied = true;

      g.traverse((obj) {
        if (obj is! three.Mesh) return;
        if (obj == _ground) return; // ground'u elleme

        // orijinali bir kere sakla
        _origMaterials.putIfAbsent(obj, () => obj.material);

        final black = three.MeshBasicMaterial();
        black.color = three_math.Color.fromHex32(0xFF000000);

        obj.material = black;
      });
    } else {
      if (!_silhouetteApplied) return;
      _silhouetteApplied = false;

      // geri döndür
      for (final e in _origMaterials.entries) {
        e.key.material = e.value;
      }
    }
  }

  void _updateFocusScreenPosition(three.ThreeJS js, double dt) {
    // Marker gösterme koşulları
    if (_focusAnchor == null || _isInteracting || _snapActive) {
      _focusScreen.value = null;
      _resetMarkerStabilizer();
      return;
    }

    // (İstersen composer açıkken de gizle)
    // if (_composerOpen) { _focusScreen.value = null; _resetMarkerStabilizer(); return; }

    final p = _focusAnchor!.clone()..project(js.camera);

    // Kameranın arkasındaysa
    if (p.z > 1) {
      _focusScreen.value = null;
      _resetMarkerStabilizer();
      return;
    }

    final sx = (p.x + 1) * 0.5 * js.width;
    final sy = (1 - (p.y + 1) * 0.5) * js.height;

    final now = Offset(sx, sy);

    // Stabilite ölçümü
    if (_lastProjected != null) {
      final dx = (now.dx - _lastProjected!.dx).abs();
      final dy = (now.dy - _lastProjected!.dy).abs();
      final stable = (dx <= _stablePxEps && dy <= _stablePxEps);

      if (stable) {
        _stableFor += dt;
      } else {
        _stableFor = 0.0;
      }
    }

    _lastProjected = now;

    // Yeterince stabil kalınca göster
    if (_stableFor >= _needStableSeconds) {
      _showFocusMarker = true;
      _focusScreen.value = now;
    } else {
      _showFocusMarker = false;
      _focusScreen.value = null;
    }
  }

  void _adjustCameraForComposer(three.ThreeJS js) {
    if (!_composerOpen) {
      _composerPitchBias = 0.0;
      return;
    }
    if (_focusAnchor == null) return;

    final kb = MediaQuery.of(context).viewInsets.bottom;
    if (kb <= 0) {
      _composerPitchBias = 0.0;
      return;
    }

    // 1) anchor'ın ekran Y'sini ölç
    final p = _focusAnchor!.clone()..project(js.camera);
    if (p.z > 1) return;

    final sy = (1 - (p.y + 1) * 0.5) * js.height;

    // 2) görünür alan
    final visibleH = js.height - kb;
    if (visibleH <= 0) return;

    // 3) hedef Y (üst yarıda kalsın)
    final targetY = visibleH * 0.42;

    final diff = sy - targetY;

    // deadzone
    const dead = 8.0;
    if (diff.abs() < dead) return;

    // 4) diff -> hedef bias (küçük)
    // çok agresif olmasın diye clamp
    final desiredBias = (-diff * 0.0009).clamp(-0.22, 0.22);

    // 5) bias'a smooth yaklaş (damping)
    _composerPitchBias = _composerPitchBias + (desiredBias - _composerPitchBias) * 0.12;
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

    _resetMarkerStabilizer();

    // Sadece "seçili nokta varsa" ve "gerçek drag başlarsa" yapacağız.
    _pendingTreeModeShift = (_focusAnchor != null);
    _treeModeShiftDoneThisGesture = false;

    _startYaw = _yaw;
    _startPitch = _pitch;
    _startRadius = _radius;

    if (_chaputSheetExtent > _chaputSheetMin + 0.01) {
      _chaputSheetPrevExtent = _chaputSheetExtent;
      _chaputSheetCtrl.animateTo(
        _chaputSheetMin,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
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

    if (_chaputSheetPrevExtent > _chaputSheetMin + 0.01) {
      _chaputSheetCtrl.animateTo(
        _chaputSheetPrevExtent.clamp(_chaputSheetMin, _chaputSheetMax),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
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
    if (js != null) _updateCamera(js, 1 / 60);
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(profileControllerProvider(widget.userId));
    final meAsync = ref.watch(meControllerProvider);

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

    final userId = user?['id']?.toString() ?? '';
    if (userId.isNotEmpty && userId != _lastProfileUserId) {
      _lastProfileUserId = userId;
      _lastTreeId = null;
      _disposeThree();
    }
    final fullName = user?['full_name']?.toString() ?? '';
    final username = user?['username']?.toString() ?? '';
    final followerCount = st.profileJson?['follower_count'] ?? 0;
    final followingCount = st.profileJson?['following_count'] ?? 0;
    final defaultAvatar = user?['default_avatar'];
    final profilePhotoKey = user?['profile_photo_key']?.toString();
    final profilePhotoUrl = user?['profile_photo_url']?.toString();
    final bio = user?['bio']?.toString() ?? '';

    final LiteUser? targetLiteUser = userId.isEmpty
        ? null
        : LiteUser(
            id: userId,
            username: username,
            fullName: fullName,
            bio: bio,
            defaultAvatar: defaultAvatar?.toString() ?? '',
            profilePhotoKey: profilePhotoKey,
            profilePhotoUrl: profilePhotoUrl,
          );

    bool _asBool(dynamic v) => v == true || v == 1 || v == '1';

    final isPublic = _asBool(user?['is_public']);
    final isPrivateTarget = !isPublic;

    final viewerState = (st.profileJson?['viewer_state'] is Map)
        ? (st.profileJson!['viewer_state'] as Map)
        : null;

    final isFollowing = viewerState?['is_following'] == true;
    final isMe = viewerState?['is_me'] == true;
    final isBlocked = viewerState?['is_blocked'] == true;
    final iRequestedFollow = viewerState?['i_requested_follow'] == true;


    final iRestrictedHim = viewerState?['i_restricted_him'] == true;
    final heRestrictedMe = viewerState?['he_restricted_me'] == true;

    final uiRestrictedOverride = ref.watch(uiRestrictedOverrideProvider(widget.userId));
    final effectiveIRestrictedHim = uiRestrictedOverride ?? iRestrictedHim;



    final int effectiveFollowerCount =  (followerCount + _uiFollowerDelta).clamp(0, 1 << 30);
    bool effectiveIsFollowing = _uiIsFollowing ?? isFollowing;
    final effectiveRequestedFollow = _uiRequestedFollow ?? iRequestedFollow;



    final followState = ref.watch(
      followControllerProvider(username),
    );

    if (followState is FollowIdle && followState.isFollowing != null) {
      effectiveIsFollowing = followState.isFollowing!;
    }

    final followLoading = followState is FollowLoading;

    final me = meAsync.valueOrNull;
    final viewerId = me?.user.userId ?? '';
    final viewerLite = me == null
        ? null
        : LiteUser(
            id: me.user.userId,
            username: me.user.username,
            fullName: me.user.fullName,
            bio: me.user.bio,
            defaultAvatar: me.user.defaultAvatar ?? '',
            profilePhotoKey: me.user.profilePhotoKey,
            profilePhotoUrl: me.user.profilePhotoUrl,
          );

    final profileIdHex = _resolveProfileId(st.profileJson, userId);
    final bool decisionAllowed =
        profileIdHex.length == 32 && !isMe && !(isPrivateTarget && !effectiveIsFollowing);

    final decisionState = decisionAllowed
        ? ref.watch(chaputDecisionControllerProvider(profileIdHex))
        : ChaputDecisionState.empty;

    final decision = decisionState.decision;

    final planType = decision?.plan.type ?? 'FREE';
    final planPeriod = decision?.plan.period;

    final creditsNormal  = decision?.credits.normal  ?? 0;
    final creditsHidden = decision?.credits.hidden ?? 0;
    final creditsSpecial = decision?.credits.special ?? 0;
    final creditsRevive  = decision?.credits.revive  ?? 0;
    final creditsWhisper = decision?.credits.whisper ?? 0;

    final adsCanWatch     = decision?.ads.canWatch ?? false;
    final adsWatchedToday = decision?.ads.watchedToday ?? 0;
    final adsRewardsToday = decision?.ads.rewardsToday ?? 0;
    final adsNextRewardIn = decision?.ads.nextRewardIn ?? 0;

    final decisionPath    = decision?.decision.path ?? 'FORBIDDEN';
    final decisionCanStart = decision?.target.canStart ?? false;
    final decisionHasThread = decision?.target.hasThread ?? false;
    final decisionThreadState = decision?.target.threadState ?? '';
    final decisionThreadId = decision?.target.threadId ?? '';

    final decisionLoaded = decision != null;
    _planType = planType;
    _planPeriod = planPeriod;
    _creditNormal = creditsNormal;
    _creditHidden = creditsHidden;
    _creditSpecial = creditsSpecial;
    _creditRevive = creditsRevive;
    _creditWhisper = creditsWhisper;
    _adsCanWatch = adsCanWatch;
    _adsWatchedToday = adsWatchedToday;
    _adsRewardsToday = adsRewardsToday;
    _adsNextRewardIn = adsNextRewardIn;
    _decisionLoaded = decisionLoaded;
    _decisionPath = decisionPath;
    _decisionCanStart = decisionCanStart;
    _decisionHasThread = decisionHasThread;

    if (!decisionAllowed) {
      _decisionProfileId = null;
    } else if (_decisionProfileId != profileIdHex) {
      _decisionProfileId = profileIdHex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(chaputDecisionControllerProvider(profileIdHex).notifier).fetchDecision();
      });
    } else if (decision == null && !decisionState.isLoading) {
      final now = DateTime.now();
      if (_lastDecisionFetchAt == null ||
          now.difference(_lastDecisionFetchAt!) > const Duration(seconds: 2)) {
        _lastDecisionFetchAt = now;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref.read(chaputDecisionControllerProvider(profileIdHex).notifier).fetchDecision();
        });
      }
    }


    final double topInset = MediaQuery.of(context).padding.top;
    const double topBarHeight = 72;

    final bool showRequestMode = !isMe && isPrivateTarget && !effectiveIsFollowing;

    final bool silhouetteMode = !isMe && isPrivateTarget && !effectiveIsFollowing;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_silhouetteMode != silhouetteMode) {
        _silhouetteMode = silhouetteMode;
        _applySilhouetteIfNeeded();
      }
    });

    final bool requestAlreadySent = showRequestMode && effectiveRequestedFollow;

    final bool followButtonDisabled = _uiFollowLoading || isBlocked || requestAlreadySent;

    final kb = MediaQuery.of(context).viewInsets.bottom;

    final bool isProPlan = _planType == 'PRO';
    final bool hasNormalCredit = _creditNormal > 0;
    final bool adsAvailable = _adsCanWatch && _adsNextRewardIn > 0;
    final bool canStartNow = decisionPath == 'CAN_START';
    final bool decisionHasArchived = decisionHasThread && decisionThreadState == 'ARCHIVED';
    final bool showBindExhausted =
        decisionLoaded
            && !decisionHasThread
            && !canStartNow
            && !isProPlan
            && !hasNormalCredit
            && !adsAvailable;

    final bool chaputAllowed = profileIdHex.length == 32 && (!isPrivateTarget || effectiveIsFollowing || isMe);
    final chaputArgs = ChaputThreadsArgs(
      profileId: profileIdHex,
      viewerId: viewerId,
      ownerId: userId,
      restricted: heRestrictedMe,
    );
    _lastChaputArgs = chaputArgs;

    final ChaputThreadsState chaputThreadsState = chaputAllowed && viewerId.isNotEmpty
        ? ref.watch(chaputThreadsControllerProvider(chaputArgs))
        : ChaputThreadsState.empty;

    final chaputThreads = chaputThreadsState.items;
    final typingUsersByThread = <String, List<LiteUser>>{};
    _typingUsersByThread.forEach((threadId, ids) {
      final list = <LiteUser>[];
      for (final id in ids) {
        if (id == viewerId) continue;
        final u = chaputThreadsState.usersById[id];
        if (u != null) list.add(u);
      }
      if (list.isNotEmpty) typingUsersByThread[threadId] = list;
    });
    if (!_initialThreadApplied && _pendingInitialThreadId != null && chaputThreads.isNotEmpty) {
      final idx = chaputThreads.indexWhere((t) => t.threadId == _pendingInitialThreadId);
      if (idx >= 0) {
        _initialThreadApplied = true;
        _pendingInitialThreadId = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_chaputPageCtrl.hasClients) {
            _chaputPageCtrl.jumpToPage(idx);
          } else {
            setState(() => _chaputActiveIndex = idx);
          }
          _focusToThreadAnchor(chaputThreads[idx], profileIdHex);
        });
      }
    }
    final bool hasOurThread = chaputThreads.any((t) =>
        (t.userAId == userId && t.userBId == viewerId) || (t.userAId == viewerId && t.userBId == userId));
    final ChaputThreadItem? activeThread =
        chaputThreads.isNotEmpty && _chaputActiveIndex < chaputThreads.length ? chaputThreads[_chaputActiveIndex] : null;
    final bool activeIsParticipant = activeThread != null &&
        (activeThread.userAId == viewerId || activeThread.userBId == viewerId);
    final bool activeViewerIsStarter = activeThread != null && activeThread.starterId == viewerId;
    final bool activeIsPending = activeThread != null && activeThread.state == 'PENDING';
    final bool canReplyOnActive = activeIsParticipant && (!activeIsPending || !activeViewerIsStarter);
    _activeThreadId = activeThread?.threadId;
    _activeThreadIsParticipant = activeIsParticipant;
    final ChaputMessage? replyTarget =
        (_replyTarget != null && _replyTargetThreadId == activeThread?.threadId) ? _replyTarget : null;
    final String? replyAuthor = replyTarget == null
        ? null
        : (replyTarget.senderId == viewerId
            ? context.t('chat_you')
            : (chaputThreadsState.usersById[replyTarget.senderId]?.fullName ?? ''));
    final String? replyBody = replyTarget?.body;
    final bool showReplyBar = canReplyOnActive &&
        (_replyBarThreadId == null || _replyBarThreadId == activeThread?.threadId) &&
        _chaputSheetExtent >= _chaputSheetMid - 0.01 &&
        !_composerOpen &&
        !_silhouetteMode;
    if (_chaputProfileId != profileIdHex) {
      _chaputProfileId = profileIdHex;
      _clearSocketSubscriptions();
      if (chaputAllowed) {
        _ensureSocket(profileIdHex);
      }
      _chaputActiveIndex = 0;
      _focusedThreadId = null;
      _chaputSheetExtent = _chaputSheetMin;
      _chaputSheetPrevExtent = _chaputSheetMin;
      _pendingThreadFocus = null;
      _pendingThreadProfileId = null;
      _replyBarThreadId = null;
      _replyWhisperMode = false;
      _replyTarget = null;
      _replyTargetThreadId = null;
      _focusAnchor = null;
      _showFocusMarker = false;
      _snapActive = false;
      _silhouetteApplied = false;
      _applySilhouetteIfNeeded();
      if (_chaputPageCtrl.hasClients) {
        _chaputPageCtrl.jumpToPage(0);
      }
    }

    if (chaputThreads.isNotEmpty && _chaputActiveIndex < chaputThreads.length) {
      final t = chaputThreads[_chaputActiveIndex];
      if (_focusedThreadId != t.threadId) {
        _focusedThreadId = t.threadId;
        _subscribeThreadSocket(t.threadId, profileIdHex);
        final isParticipant = t.userAId == viewerId || t.userBId == viewerId;
        if (isParticipant) {
          ref.read(chaputApiProvider).markThreadRead(threadIdHex: t.threadId).catchError((_) {});
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _focusToThreadAnchor(t, profileIdHex);
        });
      }
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: bg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ThreeJS TAM EKRAN
            Positioned.fill(
              child: (_threeJs == null || _navToOtherProfile)
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
                                                        ProfileStatChip(value: effectiveFollowerCount, label: 'Takipçi', onTap: () {}),
                                                        ProfileStatChip(value: followingCount, label: 'Takip', onTap: () {}),
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
                                                      onPressed: followButtonDisabled
                                                          ? null
                                                          : () async {
                                                        if (isBlocked) return;

                                                        setState(() => _uiFollowLoading = true);

                                                        // PRIVATE + not following: follow -> request gönderme modu
                                                        if (showRequestMode) {
                                                          // optimistic: anında "İstek Gönderildi"
                                                          setState(() => _uiRequestedFollow = true);

                                                          try {
                                                            final ctrl = ref.read(
                                                              followControllerProvider(username).notifier,
                                                            );

                                                            // follow() backend'de private ise follow_request oluşturmalı (senin sistemde genelde böyle)
                                                            await ctrl.follow();

                                                          } catch (_) {
                                                            // rollback
                                                            setState(() => _uiRequestedFollow = null);
                                                          } finally {
                                                            setState(() => _uiFollowLoading = false);
                                                          }
                                                          return;
                                                        }

                                                        // PUBLIC veya zaten following/unfollow normal akış
                                                        setState(() {
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
                                                          setState(() => _uiFollowLoading = false);
                                                        }
                                                      },

                                                      style: TextButton.styleFrom(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                        backgroundColor: isBlocked
                                                            ? Colors.red.shade200
                                                            : requestAlreadySent
                                                            ? Colors.blue
                                                            : effectiveIsFollowing
                                                            ? Colors.grey.shade300
                                                            : Colors.black,
                                                        foregroundColor: requestAlreadySent
                                                            ? Colors.white
                                                            : (effectiveIsFollowing ? Colors.black : Colors.white),

                                                        // disabled iken de beyaz kalsın
                                                        disabledForegroundColor: requestAlreadySent ? Colors.white : Colors.white70,

                                                        // disabled iken arka plan da mavi kalsın
                                                        disabledBackgroundColor: requestAlreadySent ? Colors.blue : Colors.grey.shade300,

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
                                                        requestAlreadySent
                                                            ? 'İstek Gönderildi'
                                                            : (effectiveIsFollowing ? 'Takibi Bırak' : 'Takip Et'),
                                                        style: const TextStyle(fontSize: 12),
                                                      ),
                                                    ),

                                                    const SizedBox(width: 6),

                                                    // THREE DOT MENU
                                                    ProfileActionsButton(
                                                        username: username,
                                                        userId: userId,
                                                        iRestrictedHim: effectiveIRestrictedHim,
                                                    ),
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


            // MARKER (sheet'in arkasında kalmalı)
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

            if (chaputThreads.isNotEmpty && !_composerOpen && !_silhouetteMode)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                    child: ChaputThreadSheet(
                      threads: chaputThreads,
                      usersById: chaputThreadsState.usersById,
                      typingUsersByThread: typingUsersByThread,
                      viewerUser: viewerLite,
                      viewerId: viewerId,
                      ownerId: userId,
                      profileId: profileIdHex,
                      pageController: _chaputPageCtrl,
                      sheetController: _chaputSheetCtrl,
                      initialExtent: _chaputSheetExtent,
                      onExtentChanged: (v) {
                        _chaputSheetExtent = v;
                        if (v > _chaputSheetMin + 0.01) {
                          _chaputSheetPrevExtent = v;
                        }
                        if (v <= _chaputSheetMid + 0.001 && MediaQuery.of(context).viewInsets.bottom > 0) {
                          FocusScope.of(context).unfocus();
                        }
                        setState(() {});
                      },
                      onPageChanged: (index) async {
                        setState(() => _chaputActiveIndex = index);
                        if (index < chaputThreads.length) {
                          final t = chaputThreads[index];
                          _subscribeThreadSocket(t.threadId, profileIdHex);
                          _focusToThreadAnchor(t, profileIdHex);
                          final isParticipant = t.userAId == viewerId || t.userBId == viewerId;
                          final viewerIsStarter = t.starterId == viewerId;
                          final isPending = t.state == 'PENDING';
                          _replyBarThreadId = (isParticipant && (!isPending || !viewerIsStarter)) ? t.threadId : null;
                          _replyWhisperMode = false;
                          _replyTarget = null;
                          _replyTargetThreadId = null;
                          FocusScope.of(context).unfocus();
                          final isParticipant2 = t.userAId == viewerId || t.userBId == viewerId;
                          if (!isParticipant2) {
                            final api = ref.read(chaputApiProvider);
                            await api.recordView(threadIdHex: t.threadId);
                          } else {
                            ref.read(chaputApiProvider).markThreadRead(threadIdHex: t.threadId).catchError((_) {});
                          }
                          if (index >= chaputThreads.length - 2) {
                            ref.read(chaputThreadsControllerProvider(chaputArgs).notifier).loadMore();
                          }
                        }
                      },
                      onOpenProfile: (id, threadId) async {
                        if (id.isEmpty) return;
                        await _openThreadCounterpartyProfile(userId: id, threadId: threadId);
                      },
                      onSendMessage: (thread, body, whisper) async {
                        await _sendThreadMessage(
                          thread: thread,
                          body: body,
                          whisper: whisper,
                          profileIdHex: profileIdHex,
                          chaputArgs: chaputArgs,
                          viewerId: viewerId,
                        );
                      },
                      onMakeHidden: (thread) async {
                        await _makeThreadHidden(
                          thread: thread,
                          profileIdHex: profileIdHex,
                          chaputArgs: chaputArgs,
                        );
                      },
                      canMakeHidden: creditsHidden > 0,
                      onReplyMessage: _handleReplyRequested,
                      onOpenWhisperPaywall: () async {
                        await ref.read(chaputDecisionControllerProvider(profileIdHex).notifier).fetchDecision();

                        final freshWhisper = ref
                            .read(chaputDecisionControllerProvider(profileIdHex))
                            .decision
                            ?.credits
                            .whisper
                            ?? 0;

                        if (freshWhisper > 0) return; // ✅ kredi varsa paywall yok

                        final purchase = await _openPaywall(feature: PaywallFeature.whisper);
                        if (purchase == null) return;
                        await _verifyPurchaseAndApply(purchase);
                      },
                      replyOverlay: showReplyBar ? 88.0 : 0.0,
                      whisperCredits: creditsWhisper,
                    ),
                  ),
                ),
              ),

            if (showReplyBar)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: ChaputReplyBar(
                    key: ValueKey(activeThread?.threadId ?? 'none'),
                    canWhisper: creditsWhisper > 0,
                    whisperMode: _replyWhisperMode,
                    replyAuthor: replyAuthor,
                    replyBody: replyBody,
                    onClearReply: () {
                      setState(() {
                        _replyTarget = null;
                        _replyTargetThreadId = null;
                      });
                    },

                    onToggleWhisper: () async {
                      // kapatmak serbest
                      if (_replyWhisperMode) {
                        setState(() => _replyWhisperMode = false);
                        return;
                      }

                      // açarken: fresh decision çek
                      final notifier = ref.read(chaputDecisionControllerProvider(profileIdHex).notifier);
                      ChaputDecision? freshDecision;
                      final api = ref.read(chaputApiProvider);
                      try {
                        freshDecision = await api.getDecision(profileIdHex);
                        notifier.setCredits(
                          normal: freshDecision.credits.normal,
                          hidden: freshDecision.credits.hidden,
                          special: freshDecision.credits.special,
                          revive: freshDecision.credits.revive,
                          whisper: freshDecision.credits.whisper,
                        );
                        notifier.applyPlanType(freshDecision.plan.type);
                        if (freshDecision.plan.period != null && freshDecision.plan.period!.isNotEmpty) {
                          notifier.applyPlanPeriod(freshDecision.plan.period!);
                        }
                      } catch (_) {
                        freshDecision = await notifier.fetchDecisionAndReturn();
                      }
                      final freshWhisper = freshDecision?.credits.whisper ?? 0;

                      if (freshWhisper > 0) {
                        setState(() => _replyWhisperMode = true);
                        return;
                      }

                      // kredi yok -> paywall
                      final purchase = await _openPaywall(feature: PaywallFeature.whisper);
                      if (purchase == null) return;

                      final ok = await _verifyPurchaseAndApply(purchase);
                      if (!ok) return;

                      // satın alma sonrası tekrar çek
                      ChaputDecision? after;
                      try {
                        after = await api.getDecision(profileIdHex);
                        notifier.setCredits(
                          normal: after.credits.normal,
                          hidden: after.credits.hidden,
                          special: after.credits.special,
                          revive: after.credits.revive,
                          whisper: after.credits.whisper,
                        );
                        notifier.applyPlanType(after.plan.type);
                        if (after.plan.period != null && after.plan.period!.isNotEmpty) {
                          notifier.applyPlanPeriod(after.plan.period!);
                        }
                      } catch (_) {
                        after = await notifier.fetchDecisionAndReturn();
                      }
                      final afterWhisper = after?.credits.whisper ?? 0;

                      if (afterWhisper > 0) {
                        setState(() => _replyWhisperMode = true);
                      } else {
                        _showGlassToast('Fısılda hakkı gelmedi', icon: Icons.error_outline);
                      }
                    },

                    onWhisperPaywall: () async {
                      // artık send tetiklemeyecek ama yine de bırakıyoruz
                      final notifier = ref.read(chaputDecisionControllerProvider(profileIdHex).notifier);
                      ChaputDecision? freshDecision;
                      final api = ref.read(chaputApiProvider);
                      try {
                        freshDecision = await api.getDecision(profileIdHex);
                        notifier.setCredits(
                          normal: freshDecision.credits.normal,
                          hidden: freshDecision.credits.hidden,
                          special: freshDecision.credits.special,
                          revive: freshDecision.credits.revive,
                          whisper: freshDecision.credits.whisper,
                        );
                        notifier.applyPlanType(freshDecision.plan.type);
                        if (freshDecision.plan.period != null && freshDecision.plan.period!.isNotEmpty) {
                          notifier.applyPlanPeriod(freshDecision.plan.period!);
                        }
                      } catch (_) {
                        freshDecision = await notifier.fetchDecisionAndReturn();
                      }
                      final freshWhisper = freshDecision?.credits.whisper ?? 0;

                      if (freshWhisper > 0) {
                        setState(() => _replyWhisperMode = true);
                        return;
                      }

                      final purchase = await _openPaywall(feature: PaywallFeature.whisper);
                      if (purchase == null) return;

                      final ok = await _verifyPurchaseAndApply(purchase);
                      if (!ok) return;

                      setState(() => _replyWhisperMode = true);
                    },

                    onSend: (text, _ignored) async {
                      final t = activeThread;
                      if (t == null) return;

                      await _sendThreadMessage(
                        thread: t,
                        body: text,
                        whisper: _replyWhisperMode,
                        profileIdHex: profileIdHex,
                        chaputArgs: chaputArgs,
                        viewerId: viewerId,
                      );

                      setState(() => _replyWhisperMode = false);
                      setState(() {
                        _replyTarget = null;
                        _replyTargetThreadId = null;
                      });
                    },
                    onFocus: () {
                      if (_chaputSheetExtent >= _chaputSheetMax - 0.01) return;
                      _sheetAutoExpanded = true;
                      _sheetExtentBeforeKeyboard = _chaputSheetExtent;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!_chaputSheetCtrl.isAttached) return;
                        _chaputSheetCtrl.animateTo(
                          _chaputSheetMax,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                        );
                      });
                    },
                    onBlur: () {
                      if (!_sheetAutoExpanded) return;
                      _sheetAutoExpanded = false;
                      final target = _sheetExtentBeforeKeyboard;
                      if (target < _chaputSheetMax - 0.01) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!_chaputSheetCtrl.isAttached) return;
                          _chaputSheetCtrl.animateTo(
                            target.clamp(_chaputSheetMin, _chaputSheetMax),
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                          );
                        });
                      }
                    },
                  ),
                ),
              ),

          // BUTON
          Positioned(
            right: 14,
            bottom: (chaputThreads.isNotEmpty
                    ? (MediaQuery.of(context).size.height * _chaputSheetExtent + 10)
                    : 14),
            child: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: (_composerOpen ||
                        _silhouetteMode ||
                        isMe ||
                        _chaputThreadCreated ||
                        hasOurThread ||
                        (chaputThreads.isNotEmpty && _chaputSheetExtent > _chaputSheetMin + 0.01))
                    ? const SizedBox.shrink()
                    : IgnorePointer(
                        ignoring: !_threeReady,
                        child: BlackGlass(
                          radius: 16,
                          blur: 10,
                          opacity: 0.55,
                          borderOpacity: 0.12,
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              onTap: (_silhouetteMode || _composerOpen)
                                  ? null
                                  : () async {
                                      if (decisionHasArchived && decisionThreadId.length == 32) {
                                        await _handleRevivePressed(
                                          threadIdHex: decisionThreadId,
                                          profileIdHex: profileIdHex,
                                          chaputArgs: chaputArgs,
                                          targetUser: targetLiteUser,
                                        );
                                        return;
                                      }
                                      if (showBindExhausted) {
                                        final purchase = await _openPaywall(feature: PaywallFeature.bind);
                                        if (purchase != null) {
                                          final ok = await _verifyPurchaseAndApply(purchase);
                                          if (ok) {
                                            _prepareComposer();
                                          }
                                        }
                                        return;
                                      }
                                      await _handleBindPressed(profileId: profileIdHex);
                                    },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      decisionHasArchived
                                          ? Icons.restore
                                          : showBindExhausted
                                              ? Icons.lock_clock
                                              : (_decisionPath == 'NEED_AD' ? Icons.play_circle : Icons.draw),
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      decisionHasArchived
                                          ? "Arşivden Kurtar"
                                          : showBindExhausted
                                              ? "Bugün Chaput Hakkın Bitti"
                                              : (_decisionPath == 'NEED_AD'
                                                  ? "Reklamla Chaput Bağla"
                                                  : "Bir Chaput Bağla"),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
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

            Positioned(
              left: 12,
              right: 12,
              bottom: 10 + kb,
              child: SafeArea(
                top: false,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: (!_composerOpen || _silhouetteMode)
                      ? const SizedBox.shrink()
                      : meAsync.when(
                    loading: () => ChatComposerBar(
                      controller: _msgCtrl,
                      focusNode: _msgFocus,
                      avatarUrl: null,
                      isDefaultAvatar: true,
                      onAvatarTap: _toggleProfileCard,
                      onSend: () => _sendChaputMessage(
                        profileId: profileIdHex,
                        viewerId: viewerId,
                        targetUserId: userId,
                        viewerLite: viewerLite,
                        chaputArgs: chaputArgs,
                      ),
                      anonEnabled: _anonMode,
                      highlightEnabled: _highlightMode,
                      onOptionsTap: _openComposerOptionsSheet,
                      onOptionsEmptyTap: _onOptionsEmptyTap,
                    ),
                    error: (_, __) => ChatComposerBar(
                      controller: _msgCtrl,
                      focusNode: _msgFocus,
                      avatarUrl: null,
                      isDefaultAvatar: true,
                      onAvatarTap: _toggleProfileCard,
                      onSend: () => _sendChaputMessage(
                        profileId: profileIdHex,
                        viewerId: viewerId,
                        targetUserId: userId,
                        viewerLite: viewerLite,
                        chaputArgs: chaputArgs,
                      ),
                      anonEnabled: _anonMode,
                      highlightEnabled: _highlightMode,
                      onOptionsTap: _openComposerOptionsSheet,
                      onOptionsEmptyTap: _onOptionsEmptyTap,
                    ),
                    data: (me) {
                      final meUser = me?.user;

                      final meAvatarUrl = (meUser?.profilePhotoUrl != null &&
                          meUser!.profilePhotoUrl!.isNotEmpty)
                          ? meUser.profilePhotoUrl
                          : meUser?.defaultAvatar;

                      final meIsDefault = (meUser?.profilePhotoUrl == null ||
                          (meUser!.profilePhotoUrl?.isEmpty ?? true));

                      return ChatComposerBar(
                        controller: _msgCtrl,
                        focusNode: _msgFocus,
                        avatarUrl: meAvatarUrl,
                        isDefaultAvatar: meIsDefault,
                        onAvatarTap: _toggleProfileCard,
                        onSend: () => _sendChaputMessage(
                          profileId: profileIdHex,
                          viewerId: viewerId,
                          targetUserId: userId,
                          viewerLite: viewerLite,
                          chaputArgs: chaputArgs,
                        ),
                        anonEnabled: _anonMode,
                        highlightEnabled: _highlightMode,
                        onOptionsTap: _openComposerOptionsSheet,
                        onOptionsEmptyTap: _onOptionsEmptyTap,
                      );
                    },
                  ),
                ),
              ),
            ),



          ],
        ),
      ),
    );

  }
}
