import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:ui';

import 'package:chaput/core/ui/chaput_circle_avatar/chaput_circle_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_math/three_js_math.dart' as three_math;

import '../../../../chaput/application/chaput_decision_controller.dart';
import '../../../../chaput/application/chaput_messages_controller.dart';
import '../../../../chaput/application/chaput_threads_controller.dart';
import '../../../../chaput/data/chaput_socket.dart';
import '../../../../chaput/domain/chaput_decision.dart';
import '../../../../chaput/domain/chaput_message.dart';
import '../../../../chaput/domain/chaput_thread.dart';
import '../../../../core/config/env.dart';
import '../../../../core/utils/backend_time.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/router/route_observer.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/storage/tutorial_storage.dart';
import '../../../../core/ui/responsive/chaput_responsive.dart';
import '../../../../core/ux/chaput_sound_service.dart';
import '../../../billing/data/billing_api_provider.dart';
import '../../../billing/domain/billing_verify_result.dart';
import '../../../me/application/me_controller.dart';
import '../../../reports/data/reports_api.dart';
import '../../../reports/presentation/widgets/report_content_sheet.dart';
import '../../../revenuecat/data/revenue_cat_service.dart';
import '../../../settings/data/account_api.dart';
import '../../../helpers/string_helpers/safe_text_rules.dart';
import '../../../user/domain/lite_user.dart';
import '../../application/profile_visit_history_controller.dart';
import '../../domain/profile_preview.dart';
import '../../../recommended_users/application/recommended_user_controller.dart';
import '../../../social/application/follow_state.dart';
import '../../../social/application/ui_restriction_override_provider.dart';
import '../../../user_search/application/user_search_controller.dart';
import '../../../user/application/profile_controller.dart';
import '../../../user/data/user_api_provider.dart';
import '../../domain/tree_catalog.dart';

import '../../../social/application/follow_controller.dart';
import '../profile_composer_visibility.dart';
import '../utils/profile_tree_bounds.dart';
import '../utils/tree_model_cache.dart';
import '../widgets/black_glass.dart';
import '../widgets/chaput_composer_bar.dart';
import '../widgets/chaput_composer_options_sheet.dart';
import '../widgets/chaput_paywall_sheet.dart';
import '../widgets/chaput_reply_bar.dart';
import '../widgets/glass_toast_overlay.dart';
import '../widgets/empty_chaput_sheet.dart';
import '../widgets/profile_actions_sheet.dart';
import '../widgets/profile_stat_chip.dart';
import '../widgets/profile_avatar_hero.dart';
import '../widgets/tree_silhouette_shimmer.dart';
import 'follow_list_screen.dart';
import '../../../social/application/follow_list_controller.dart';
import '../widgets/subscription_replace_sheet.dart';
import '../widgets/chaput_thread_sheet.dart';
import 'package:chaput/core/constants/app_colors.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    required this.userId,
    this.initialThreadId,
    this.initialMessageId,
    this.initialProfilePreview,
  });

  final String userId;
  final String? initialThreadId;
  final String? initialMessageId;
  final ProfilePreview? initialProfilePreview;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

enum _ProfileTutorialStep {
  menuOpen,
  settings,
  menuClose,
  chaputPull,
  chaputSwipe,
}

extension on _ProfileTutorialStep {
  String get storageKey => switch (this) {
    _ProfileTutorialStep.menuOpen => 'profile_menu_open',
    _ProfileTutorialStep.settings => 'profile_settings',
    _ProfileTutorialStep.menuClose => 'profile_menu_close',
    _ProfileTutorialStep.chaputPull => 'chaput_sheet_pull',
    _ProfileTutorialStep.chaputSwipe => 'chaput_thread_swipe',
  };
}

String? _firstNonEmpty(String? primary, String? fallback) {
  if (primary != null && primary.isNotEmpty) return primary;
  if (fallback != null && fallback.isNotEmpty) return fallback;
  return null;
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin, RouteAware, WidgetsBindingObserver {
  OverlayEntry? _toastEntry;
  bool _toastShowing = false;
  bool _isDisposed = false;
  bool _rebuildTreeAfterResume = false;
  bool _treeSuspendedForCoveredRoute = false;

  static const List<String> _emptyChaputMessageKeysOther = [
    'profile.empty_chaput_1',
    'profile.empty_chaput_2',
    'profile.empty_chaput_3',
    'profile.empty_chaput_4',
    'profile.empty_chaput_5',
    'profile.empty_chaput_6',
    'profile.empty_chaput_7',
    'profile.empty_chaput_8',
  ];
  static const List<String> _emptyChaputMessageKeysSelf = [
    'profile.empty_chaput_self_1',
    'profile.empty_chaput_self_2',
    'profile.empty_chaput_self_3',
    'profile.empty_chaput_self_4',
  ];

  int? _emptyChaputIndex;
  String? _emptyChaputProfileId;
  bool? _emptyChaputIsMe;
  bool _emptyChaputAnchorPicked = false;
  String? _emptyChaputVisualSignature;

  late final AnimationController _profileCardCtrl;
  late final Animation<double> _profileCardT;
  bool _profileCardOpen = false;

  final GlobalKey _profileMenuShowcaseKey = GlobalKey();
  final GlobalKey _settingsShowcaseKey = GlobalKey();
  final GlobalKey _profileCloseShowcaseKey = GlobalKey();
  final GlobalKey _chaputSheetShowcaseKey = GlobalKey();
  final GlobalKey _chaputThreadSwipeShowcaseKey = GlobalKey();
  _ProfileTutorialStep? _activeProfileTutorial;
  bool _profileTutorialCheckQueued = false;
  bool _profileTutorialCheckInFlight = false;
  int _profileTutorialGeneration = 0;
  String _profileTutorialViewerId = '';
  String _profileTutorialProfileId = '';
  bool _profileTutorialProfileReady = false;
  bool _profileTutorialIsMe = false;
  bool _profileTutorialChaputAllowed = false;
  bool _profileTutorialThreadSheetVisible = false;
  int _profileTutorialThreadCount = 0;
  String? _profileTutorialActiveThreadId;
  final Set<_ProfileTutorialStep> _completedProfileTutorials = {};
  int _treePreservingOverlayDepth = 0;
  DateTime? _suppressChaputSwipeSoundUntil;

  bool _pendingTreeModeShift = false;
  bool _treeModeShiftDoneThisGesture = false;

  bool? _uiIsFollowing;
  int _uiFollowerDelta = 0;
  bool _uiFollowLoading = false;
  bool? _uiRequestedFollow;
  String? _lastFollowStateSyncSignature;

  // ===== COMPOSER (Chaput bağla) =====
  final TextEditingController _msgCtrl = TextEditingController();
  final FocusNode _msgFocus = FocusNode();

  late final ChaputSocketClient _socketClient;
  StreamSubscription<ChaputSocketEvent>? _socketSub;
  String? _socketProfileId;
  String? _socketThreadId;
  final Map<String, Set<String>> _typingUsersByThread = {};
  final Map<String, Timer> _typingExpiryTimers = {};
  final ValueNotifier<int> _typingRevision = ValueNotifier(0);
  bool _activeThreadIsParticipant = false;
  String? _activeThreadId;
  ChaputThreadsArgs? _lastChaputArgs;
  Timer? _typingIdleTimer;
  String? _typingSentThreadId;
  bool _typingSent = false;
  bool _typingSoundActive = false;
  String? _typingSoundThreadId;

  bool _composerOpen = false; // input bar açık mı?
  three.Vector3? _draftAnchor; // mesaj varken hatırlanan anchor
  double _composerPitchBias = 0.0;

  // ================= FOCUS / ANCHOR =================
  three.Vector3? _focusAnchor; // leaf üstündeki world space nokta
  final ValueNotifier<Offset?> _focusScreen = ValueNotifier<Offset?>(null);

  bool _isInteracting = false;

  // snap back animasyonu
  late double _snapFromYaw, _snapToYaw;
  late double _snapFromPitch, _snapToPitch;

  bool _snapActive = false;
  double _snapT = 0.0;

  late three.Vector3 _snapFromCenter;
  late three.Vector3 _snapToCenter;

  double _defaultRadius = 3.0;
  double _snapFromRadius = 3.0;
  double _snapToRadius = 3.0;

  three.ThreeJS? _threeJs;

  bool _threeReady = false;
  String? _threeError;
  bool _navToOtherProfile = false;
  bool _routeSubscribed = false;
  bool _forceTreeReload = false;
  bool _reloadOnPopNext = false;

  String? _lastTreeId;
  String? _lastProfileUserId;
  int _threeLoadEpoch = 0;
  int _threeSurfaceGeneration = 0;
  Timer? _threeCreateTimer;
  String? _pendingThreeTreeId;

  three.Group? _treeGroup;
  three.Mesh? _ground;
  ChaputThreadItem? _pendingThreadFocus;
  String? _pendingInitialThreadId;
  String? _pendingInitialMessageId;
  bool _initialThreadApplied = false;
  String? _pendingThreadProfileId;

  // orbit
  double _yaw = 0.0;
  double _pitch = -0.20;
  double _radius = 3.0;

  // gesture snapshot
  double _startRadius = 3.0;

  // zoom limits
  double _minRadius = 0.6;
  double _maxRadius = 12.0;

  // pitch limits
  static const double _minPitchHard = -1.15;
  static const double _maxPitch = 0.45;

  // orbit merkez (ağacın merkezi) + bakış hedefi
  three.Vector3 _treeCenter = three.Vector3(0, 0.9, 0); // sabit: ağacın merkezi
  three.Vector3 _orbitCenter = three.Vector3(
    0,
    0.9,
    0,
  ); // dinamik: treeCenter - focusAnchor
  three.Vector3 _lookAt = three.Vector3(
    0,
    0.9,
    0,
  ); // genelde orbitCenter ile aynı gider

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
  bool _anonMode = false; // "Kimliğini gizle"
  bool _highlightMode = false; // "Öne çıkar" (şimdilik dummy)

  // ===== CHAPUT DECISION / ENTITLEMENTS =====
  bool _chaputThreadCreated = false;
  bool _chaputSendLoading = false;
  bool _reviveFlowBusy = false;
  String? _reviveArchiveOverrideProfileId;
  String? _reviveArchiveOverrideThreadId;
  String? _sessionThreadOrderProfileId;
  List<String> _sessionThreadOrderIds = const [];
  String? _pendingCreatedThreadId;
  final PageController _chaputPageCtrl = PageController();
  static const double _chaputSwipeHapticThreshold = 0.34;
  int _chaputFeedbackBasePageIndex = 0;
  int? _chaputHapticTargetPageIndex;
  int? _chaputSwipeFeedbackFromPageIndex;
  bool _chaputSwipeSoundPlayed = false;
  bool _chaputUserSwipeInProgress = false;
  double _chaputSwipeFeedbackProgress = 0;
  Timer? _chaputSwipeFeedbackCleanupTimer;
  int _chaputActiveIndex = 0;
  static const double _chaputSheetMin = 0.12;
  static const double _chaputSheetMid = 0.33;
  static const double _chaputSheetMax = 0.95;
  static const double _chaputSheetCollapsedTapTolerance = 0.035;
  static const double _chaputSheetMaxTolerance = 0.01;

  double _chaputSheetExtent = _chaputSheetMin;
  final ValueNotifier<double> _chaputSheetExtentListenable = ValueNotifier(
    _chaputSheetMin,
  );
  double _chaputSheetPrevExtent = _chaputSheetMin;
  final DraggableScrollableController _chaputSheetCtrl =
      DraggableScrollableController();
  bool _sheetAutoExpanded = false;
  double _sheetExtentBeforeKeyboard = _chaputSheetMin;
  String? _chaputProfileId;
  String? _focusedThreadId;
  String? _decisionProfileId;
  DateTime? _lastDecisionFetchAt;
  ChaputMessage? _replyTarget;
  String? _replyTargetThreadId;

  String _planType = 'FREE';
  String? _planPeriod;
  int _creditNormal = 0;
  int _creditHidden = 0;
  int _creditSpecial = 0;
  int _creditRevive = 0;

  String _decisionPath = 'FORBIDDEN';
  bool _decisionCanStart = false;
  bool _decisionLoaded = false;
  bool _decisionHasThread = false;

  bool get canHideCredentials => _creditHidden > 0;
  bool get canBoost => _creditSpecial > 0;

  bool _replyWhisperMode = false;

  int _pageIndexForThreadIndex(int threadIndex) => threadIndex;

  int _threadIndexForPageIndex(int pageIndex) => pageIndex;

  List<ChaputThreadItem> _stableSessionThreads({
    required String profileIdHex,
    required List<ChaputThreadItem> source,
  }) {
    if (_sessionThreadOrderProfileId != profileIdHex) {
      _sessionThreadOrderProfileId = profileIdHex;
      _sessionThreadOrderIds = source
          .map((t) => t.threadId)
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      _pendingCreatedThreadId = null;
      return source;
    }

    if (source.isEmpty) {
      _sessionThreadOrderIds = const [];
      return source;
    }

    final byId = <String, ChaputThreadItem>{
      for (final thread in source)
        if (thread.threadId.isNotEmpty) thread.threadId: thread,
    };
    final nextOrder = _sessionThreadOrderIds
        .where(byId.containsKey)
        .toList(growable: true);
    final seen = nextOrder.toSet();

    for (final thread in source) {
      final tid = thread.threadId;
      if (tid.isEmpty || seen.contains(tid)) continue;
      if (_pendingCreatedThreadId != null && tid == _pendingCreatedThreadId) {
        nextOrder.insert(0, tid);
      } else {
        nextOrder.add(tid);
      }
      seen.add(tid);
    }

    _sessionThreadOrderIds = nextOrder.toList(growable: false);

    final ordered = <ChaputThreadItem>[];
    for (final tid in _sessionThreadOrderIds) {
      final thread = byId[tid];
      if (thread != null) {
        ordered.add(thread);
      }
    }
    if (ordered.length == source.length) {
      return ordered;
    }
    for (final thread in source) {
      if (!ordered.any((it) => it.threadId == thread.threadId)) {
        ordered.add(thread);
      }
    }
    return ordered;
  }

  // orijinal material'ları saklamak için
  final Map<three.Mesh, dynamic> _origMaterials = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _socketClient = ref.read(chaputSocketProvider);
    _lastProfileUserId = widget.userId;
    _pendingInitialThreadId = widget.initialThreadId;
    _pendingInitialMessageId = widget.initialMessageId;
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
    _profileCardCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _queueProfileTutorialCheck();
      }
    });
    _msgFocus.addListener(() {
      if (!_msgFocus.hasFocus) {
        _onComposerUnfocus();
      } else {
        _onComposerFocus();
      }
    });
    _msgCtrl.addListener(_onComposerTextChanged);
    _chaputPageCtrl.addListener(_handleChaputPageScroll);
  }

  Future<void> _ensureSocket(String profileIdHex) async {
    if (profileIdHex.length != 32) return;
    try {
      _socketSub ??= _socketClient.events.listen(
        _handleSocketEvent,
        onError: (_, _) {},
      );
      await _socketClient.ensureConnected();
      if (_socketProfileId != profileIdHex) {
        if (_socketProfileId != null) {
          _socketClient.unsubscribeProfile(_socketProfileId!);
        }
        _socketClient.subscribeProfile(profileIdHex);
        _socketProfileId = profileIdHex;
      }
    } catch (_) {}
  }

  void _subscribeThreadSocket(String threadId, String profileIdHex) {
    if (threadId.isEmpty) return;
    if (_socketThreadId != null && _socketThreadId != threadId) {
      _clearTypingForThread(_socketThreadId!);
      _socketClient.unsubscribeThread(_socketThreadId!);
    }
    if (_socketThreadId != threadId) {
      _clearTypingForThread(threadId);
    }
    _socketClient.subscribeThread(threadId, profileId: profileIdHex);
    _socketThreadId = threadId;
  }

  void _clearSocketSubscriptions() {
    _resetTypingForThreadChange(null);
    if (_socketProfileId != null) {
      _socketClient.unsubscribeProfile(_socketProfileId!);
    }
    if (_socketThreadId != null) {
      _socketClient.unsubscribeThread(_socketThreadId!);
    }
    _socketProfileId = null;
    _socketThreadId = null;
    _typingIdleTimer?.cancel();
    _typingSent = false;
    _typingSentThreadId = null;
    _typingUsersByThread.clear();
    _clearTypingExpiryTimers();
    _markTypingUsersChanged();
  }

  void _playSmallFeedback(ChaputSoundEffect effect, {double playbackRate = 1}) {
    if (effect == ChaputSoundEffect.sendMessage) {
      unawaited(HapticFeedback.mediumImpact());
    } else {
      unawaited(HapticFeedback.selectionClick());
    }
    unawaited(
      ChaputSoundService.instance.play(effect, playbackRate: playbackRate),
    );
  }

  void _syncChaputFeedbackBasePage(int pageIndex) {
    _chaputFeedbackBasePageIndex = pageIndex;
    if (_chaputSwipeFeedbackFromPageIndex == null) {
      _chaputHapticTargetPageIndex = null;
    }
  }

  void _resetChaputSwipeFeedback() {
    _chaputSwipeFeedbackCleanupTimer?.cancel();
    _chaputSwipeFeedbackCleanupTimer = null;
    _chaputSwipeFeedbackFromPageIndex = null;
    _chaputSwipeSoundPlayed = false;
    _chaputUserSwipeInProgress = false;
    _chaputSwipeFeedbackProgress = 0;
    _chaputHapticTargetPageIndex = null;
  }

  void _scheduleChaputSwipeFeedbackIdle() {
    _chaputSwipeFeedbackCleanupTimer?.cancel();
    _chaputSwipeFeedbackCleanupTimer = Timer(
      const Duration(milliseconds: 120),
      () {
        final progress = _chaputSwipeFeedbackProgress;
        if (progress <= 0.01 || progress >= 0.99) {
          _resetChaputSwipeFeedback();
        }
      },
    );
  }

  void _handleChaputPageScroll() {
    if (!_chaputPageCtrl.hasClients) return;
    double? page;
    try {
      page = _chaputPageCtrl.page;
    } catch (_) {
      return;
    }
    if (page == null || !page.isFinite) return;

    final startOffset = page - _chaputFeedbackBasePageIndex;
    if (_chaputSwipeFeedbackFromPageIndex == null) {
      if (startOffset.abs() < 0.001) return;
      _chaputSwipeFeedbackFromPageIndex = _chaputFeedbackBasePageIndex;
      _chaputSwipeFeedbackProgress = 0;
    }

    final feedbackFromPage = _chaputSwipeFeedbackFromPageIndex!;
    final offsetFromBase = page - feedbackFromPage;
    final progress = offsetFromBase.abs().clamp(0, 1).toDouble();
    _chaputSwipeFeedbackProgress = progress;
    if (_chaputUserSwipeInProgress && !_chaputSwipeSoundPlayed) {
      _chaputSwipeSoundPlayed = true;
      final suppressSwipeSound =
          _suppressChaputSwipeSoundUntil?.isAfter(DateTime.now()) ?? false;
      if (!suppressSwipeSound) {
        unawaited(
          ChaputSoundService.instance.play(ChaputSoundEffect.cardSwipe),
        );
      }
    }
    _scheduleChaputSwipeFeedbackIdle();

    if (!_chaputUserSwipeInProgress || progress < _chaputSwipeHapticThreshold) {
      _chaputHapticTargetPageIndex = null;
      return;
    }

    final direction = offsetFromBase.sign.toInt();
    if (direction == 0) return;
    final targetPageIndex = feedbackFromPage + direction;
    if (targetPageIndex < 0) return;
    if (_chaputHapticTargetPageIndex == targetPageIndex) return;

    _chaputHapticTargetPageIndex = targetPageIndex;
    HapticFeedback.selectionClick();
  }

  void _suppressNextChaputSwipeSound([
    Duration duration = const Duration(milliseconds: 700),
  ]) {
    _suppressChaputSwipeSoundUntil = DateTime.now().add(duration);
  }

  void _setChaputUserSwipeInProgress(bool active) {
    if (_chaputUserSwipeInProgress == active) return;
    _chaputUserSwipeInProgress = active;
    if (!active) _scheduleChaputSwipeFeedbackIdle();
  }

  DateTime? _parseSocketTime(dynamic v) {
    return parseBackendUtcDateTime(v);
  }

  Map<String, dynamic>? _normalizeSocketMap(dynamic value) {
    if (value is! Map) return null;
    return value.map((key, val) => MapEntry(key.toString(), val));
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
        threadSlug: data['thread_slug']?.toString() ?? '',
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
      String? previousState;
      if (args != null) {
        for (final thread
            in ref.read(chaputThreadsControllerProvider(args)).items) {
          if (thread.threadId == threadId) {
            previousState = thread.state;
            break;
          }
        }
        ref
            .read(chaputThreadsControllerProvider(args).notifier)
            .upsertThreadFromSocket(item, args);
        final missingIds = <String>{};
        if (!ref
            .read(chaputThreadsControllerProvider(args))
            .usersById
            .containsKey(item.userAId)) {
          missingIds.add(item.userAId);
        }
        if (!ref
            .read(chaputThreadsControllerProvider(args))
            .usersById
            .containsKey(item.userBId)) {
          missingIds.add(item.userBId);
        }
        if (missingIds.isNotEmpty) {
          final api = ref.read(userApiProvider);
          final res = await api.batchLite(
            userIds: missingIds.toList(growable: false),
          );
          final map = <String, LiteUser>{};
          for (final u in res.items) {
            map[u.id] = u;
          }
          ref
              .read(chaputThreadsControllerProvider(args).notifier)
              .addUsers(map);
        }
      }
      if (_chaputProfileId != null &&
          _activeThreadId == threadId &&
          _activeThreadIsParticipant &&
          previousState == 'PENDING' &&
          item.state == 'OPEN') {
        _subscribeThreadSocket(threadId, _chaputProfileId!);
        unawaited(
          ref
              .read(
                chaputMessagesControllerProvider(
                  ChaputMessagesArgs(
                    threadId: threadId,
                    profileId: _chaputProfileId!,
                  ),
                ).notifier,
              )
              .refresh(),
        );
      }
      return;
    }

    if (ev.type == 'chaput.message.created') {
      final threadId = data['thread_id']?.toString() ?? '';
      final msg = _normalizeSocketMap(data['message']);
      if (threadId.isEmpty || msg == null) return;
      if (_chaputProfileId == null) return;
      final senderId = msg['sender_id']?.toString() ?? '';
      final args = ChaputMessagesArgs(
        threadId: threadId,
        profileId: _chaputProfileId!,
      );
      final parsed = ChaputMessage.fromJson(msg);
      final message = parsed.createdAt == null
          ? ChaputMessage(
              id: parsed.id,
              senderId: parsed.senderId,
              kind: parsed.kind,
              body: parsed.body,
              createdAt: DateTime.now().toUtc(),
              replyToId: parsed.replyToId,
              replyToSenderId: parsed.replyToSenderId,
              replyToBody: parsed.replyToBody,
              likeCount: parsed.likeCount,
              likedByMe: parsed.likedByMe,
              delivered: parsed.delivered,
              readByOther: parsed.readByOther,
              topLikers: parsed.topLikers,
            )
          : parsed;
      ref
          .read(chaputMessagesControllerProvider(args).notifier)
          .upsertMessageFromSocket(message);

      if (senderId.isNotEmpty) {
        final argsThreads = _lastChaputArgs;
        if (argsThreads != null) {
          final state = ref.read(chaputThreadsControllerProvider(argsThreads));
          if (!state.usersById.containsKey(senderId)) {
            try {
              final api = ref.read(userApiProvider);
              final res = await api.batchLite(userIds: [senderId]);
              if (res.items.isNotEmpty) {
                ref
                    .read(chaputThreadsControllerProvider(argsThreads).notifier)
                    .addUsers({for (final u in res.items) u.id: u});
              }
            } catch (_) {}
          }
        }
      }

      if (_activeThreadId == threadId && _activeThreadIsParticipant) {
        try {
          await ref
              .read(chaputApiProvider)
              .markThreadRead(threadIdHex: threadId);
        } catch (_) {}
      }
      return;
    }

    if (ev.type == 'chaput.message.like') {
      final threadId = data['thread_id']?.toString() ?? '';
      final msgId = data['message_id']?.toString() ?? '';
      if (threadId.isEmpty || msgId.isEmpty || _chaputProfileId == null) return;
      final args = ChaputMessagesArgs(
        threadId: threadId,
        profileId: _chaputProfileId!,
      );
      final likerId = data['user_id']?.toString() ?? '';
      final likeCount = (data['like_count'] ?? 0) as int;
      final liked = data['liked'] == true;
      ChaputMessageLiker? liker;
      final likerJson = _normalizeSocketMap(data['liker']);
      if (likerJson != null) {
        liker = ChaputMessageLiker.fromJson(likerJson);
      }
      ref
          .read(chaputMessagesControllerProvider(args).notifier)
          .applyLikeFromSocket(
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
      final meId = ref.read(meControllerProvider).value?.user.userId ?? '';
      final meNorm = meId.toLowerCase();
      final readerNorm = readerId.toLowerCase();
      if (meId.isNotEmpty && readerNorm == meNorm) return;
      final argsThreads = _lastChaputArgs;
      if (argsThreads == null) return;
      final thread = ref
          .read(chaputThreadsControllerProvider(argsThreads))
          .items
          .where((t) => t.threadId == threadId)
          .cast<ChaputThreadItem?>()
          .firstWhere((t) => t != null, orElse: () => null);
      if (thread == null) return;
      final otherId = thread.userAId.toLowerCase() == meNorm
          ? thread.userBId
          : thread.userBId.toLowerCase() == meNorm
          ? thread.userAId
          : '';
      if (otherId.isEmpty || readerNorm != otherId.toLowerCase()) return;
      final args = ChaputMessagesArgs(
        threadId: threadId,
        profileId: _chaputProfileId!,
      );
      ref
          .read(chaputMessagesControllerProvider(args).notifier)
          .markReadByOther();
      return;
    }

    if (ev.type == 'chaput.typing') {
      final threadId = data['thread_id']?.toString() ?? '';
      final userId = data['user_id']?.toString() ?? '';
      final isTyping = data['is_typing'] == true;
      if (threadId.isEmpty || userId.isEmpty) return;
      final userIdNorm = userId.toLowerCase();
      final viewerNorm =
          (_lastChaputArgs?.viewerId ??
                  ref.read(meControllerProvider).value?.user.userId ??
                  '')
              .toLowerCase();
      if (viewerNorm.isEmpty) return;
      if (viewerNorm.isNotEmpty && userIdNorm == viewerNorm) {
        _removeTypingUser(threadId, userIdNorm);
        return;
      }
      final argsThreads = _lastChaputArgs;
      if (argsThreads != null) {
        final state = ref.read(chaputThreadsControllerProvider(argsThreads));
        if (!state.usersById.containsKey(userId) &&
            !state.usersById.containsKey(userId.toUpperCase()) &&
            !state.usersById.containsKey(userIdNorm)) {
          try {
            final api = ref.read(userApiProvider);
            final res = await api.batchLite(userIds: [userId.toUpperCase()]);
            if (res.items.isNotEmpty) {
              ref
                  .read(chaputThreadsControllerProvider(argsThreads).notifier)
                  .addUsers({for (final u in res.items) u.id: u});
            }
          } catch (_) {}
        }
      }
      if (isTyping) {
        _setTypingUser(threadId, userIdNorm);
      } else {
        _removeTypingUser(threadId, userIdNorm);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeSubscribed) return;
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void didPushNext() {
    if (_treePreservingOverlayDepth > 0) return;
    if (!routeObserver.isCoveredByPageRoute(ModalRoute.of(context))) return;
    _stopTypingSound();
    _resetChaputSwipeFeedback();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _treePreservingOverlayDepth > 0) return;
      if (!routeObserver.isCoveredByPageRoute(ModalRoute.of(context))) return;
      _suspendTreeForCoveredRoute();
    });
  }

  void _setTreePreservingOverlayVisible(bool visible) {
    if (visible) {
      _treePreservingOverlayDepth += 1;
      return;
    }
    if (_treePreservingOverlayDepth > 0) {
      _treePreservingOverlayDepth -= 1;
    }
  }

  Future<T?> _showTreePreservingOverlay<T>(
    Future<T?> Function() showOverlay,
  ) async {
    _setTreePreservingOverlayVisible(true);
    try {
      return await showOverlay();
    } finally {
      _setTreePreservingOverlayVisible(false);
    }
  }

  Future<T?> _pushTreePreservingRoute<T>(
    Future<T?> Function() pushRoute,
  ) async {
    _stopTypingSound();
    _resetChaputSwipeFeedback();
    try {
      return await _showTreePreservingOverlay<T>(pushRoute);
    } finally {
      if (mounted) _syncTypingSound();
    }
  }

  void _openFollowListPreservingTree({
    required String username,
    required FollowListKind kind,
    required bool isMe,
    required String title,
  }) {
    unawaited(
      _pushTreePreservingRoute<void>(
        () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => FollowListScreen(
              username: username,
              kind: kind,
              isMe: isMe,
              title: title,
            ),
          ),
        ),
      ),
    );
  }

  void _openSettingsPreservingTree() {
    HapticFeedback.selectionClick();
    unawaited(
      _pushTreePreservingRoute<void>(() => context.push<void>(Routes.settings)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncTypingSound();
      if (_rebuildTreeAfterResume && !_treeSuspendedForCoveredRoute) {
        _rebuildTreeAfterResume = false;
        _recreateTreeAfterRendererPause();
      }
    } else {
      _stopTypingSound();
      _resetChaputSwipeFeedback();
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached) {
        // iOS can discard the ANGLE/Metal texture context while the app is
        // backgrounded. Rebuild only after a real background transition.
        _rebuildTreeAfterResume =
            _threeJs != null && !_treeSuspendedForCoveredRoute;
      }
    }
  }

  void _recreateTreeAfterRendererPause() {
    if (!mounted || _isDisposed || _treeSuspendedForCoveredRoute) return;
    final treeId = ref.read(profileControllerProvider(widget.userId)).treeId;
    if (treeId == null || treeId.isEmpty) return;

    // Rebuilding the renderer resets the scene's focus anchor. Make the
    // current thread eligible for the normal focus pipeline again so build()
    // queues it until the replacement Threejs scene is ready.
    if (_focusAnchor != null && _focusedThreadId != null) {
      _focusedThreadId = null;
    }

    _disposeThree();
    _lastTreeId = null;
    _threeError = null;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed) return;
      _createThreeIfNeeded(treeId);
    });
  }

  void _suspendTreeForCoveredRoute() {
    _treeSuspendedForCoveredRoute = true;

    // A covered profile remains in the navigation stack. Pausing its ticker
    // still leaves a native ANGLE surface alive beneath the next profile,
    // which can corrupt GLB textures/materials on iOS. Unmount it completely;
    // cached model bytes make the recreation on return fast.
    _disposeThree();
    _lastTreeId = null;
    _threeError = null;
    if (mounted) setState(() {});
  }

  void _resumeTreeAfterCoveredRoute() {
    if (!_treeSuspendedForCoveredRoute || !mounted || _isDisposed) return;
    _treeSuspendedForCoveredRoute = false;

    final js = _threeJs;
    if (js != null && _threeReady) {
      js.pause = false;
      try {
        final ticker = js.ticker;
        if (ticker != null && !ticker.isActive) ticker.start();
      } catch (_) {}
      return;
    }

    // A surface whose setup finished while this route was covered never
    // reached a usable frame. Recreate it instead of resuming an incomplete
    // ANGLE scene with stale GPU resources.
    if (js != null) {
      _disposeThree();
      if (mounted) setState(() {});
    }

    _lastTreeId = null;
    final treeId = ref.read(profileControllerProvider(widget.userId)).treeId;
    if (treeId == null || treeId.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed || _treeSuspendedForCoveredRoute) return;
      _createThreeIfNeeded(treeId);
    });
  }

  @override
  void didPopNext() {
    _syncTypingSound();
    _resumeTreeAfterCoveredRoute();
    if (!mounted || !_reloadOnPopNext) return;
    _reloadOnPopNext = false;
    _navToOtherProfile = false;
    _disposeThree();
    _lastTreeId = null;
    _threeError = null;
    _threeReady = false;
    setState(() {});
    final st = ref.read(profileControllerProvider(widget.userId));
    final tid = st.treeId;
    if (tid == null) {
      ref.read(profileControllerProvider(widget.userId).notifier).refetch();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _createThreeIfNeeded(tid);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userId != widget.userId) {
      _resetChaputSwipeFeedback();
      _treeSuspendedForCoveredRoute = false;
      _disposeThree(); // user değiştiyse 3D sıfırla
      _lastTreeId = null;
      _threeError = null;
      _threeReady = false;
      _lastProfileUserId = widget.userId;
      _navToOtherProfile = false;
      _chaputThreadCreated = false;
      _decisionProfileId = null;
      _anonMode = false;
      _highlightMode = false;
      _pendingInitialThreadId = widget.initialThreadId;
      _pendingInitialMessageId = widget.initialMessageId;
      _initialThreadApplied = false;
      _msgCtrl.clear();
    } else if (oldWidget.initialThreadId != widget.initialThreadId ||
        oldWidget.initialMessageId != widget.initialMessageId) {
      _pendingInitialThreadId = widget.initialThreadId;
      _pendingInitialMessageId = widget.initialMessageId;
      _initialThreadApplied = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopTypingSound();
    _resetChaputSwipeFeedback();
    WidgetsBinding.instance.removeObserver(this);
    if (_routeSubscribed) {
      routeObserver.unsubscribe(this);
      _routeSubscribed = false;
    }
    _disposeThree();
    _focusScreen.dispose();
    _profileCardCtrl.dispose();
    _msgCtrl.removeListener(_onComposerTextChanged);
    _msgCtrl.dispose();
    _msgFocus.dispose();
    _chaputPageCtrl.removeListener(_handleChaputPageScroll);
    _chaputPageCtrl.dispose();
    _typingIdleTimer?.cancel();
    _socketSub?.cancel();
    _socketSub = null;
    _clearSocketSubscriptions();
    _chaputSheetExtentListenable.dispose();
    _typingRevision.dispose();
    super.dispose();
  }

  void _toggleProfileCard() {
    HapticFeedback.selectionClick();
    setState(() => _profileCardOpen = !_profileCardOpen);
    if (_profileCardOpen) {
      _profileCardCtrl.forward(from: 0);
    } else {
      _profileCardCtrl.reverse(from: 1);
    }
  }

  void _syncProfileTutorialState({
    required String viewerId,
    required String profileId,
    required bool profileReady,
    required bool isMe,
    required bool chaputAllowed,
    required bool threadSheetVisible,
    required int threadCount,
    required String? activeThreadId,
  }) {
    final viewerChanged = viewerId != _profileTutorialViewerId;
    if (viewerChanged) {
      _profileTutorialGeneration += 1;
      _profileTutorialCheckInFlight = false;
      _activeProfileTutorial = null;
      _completedProfileTutorials.clear();
    }

    final changed =
        viewerChanged ||
        profileId != _profileTutorialProfileId ||
        profileReady != _profileTutorialProfileReady ||
        isMe != _profileTutorialIsMe ||
        chaputAllowed != _profileTutorialChaputAllowed ||
        threadSheetVisible != _profileTutorialThreadSheetVisible ||
        threadCount != _profileTutorialThreadCount ||
        activeThreadId != _profileTutorialActiveThreadId;

    _profileTutorialViewerId = viewerId;
    _profileTutorialProfileId = profileId;
    _profileTutorialProfileReady = profileReady;
    _profileTutorialIsMe = isMe;
    _profileTutorialChaputAllowed = chaputAllowed;
    _profileTutorialThreadSheetVisible = threadSheetVisible;
    _profileTutorialThreadCount = threadCount;
    _profileTutorialActiveThreadId = activeThreadId;

    if (changed) _queueProfileTutorialCheck();
  }

  void _queueProfileTutorialCheck() {
    if (_profileTutorialCheckQueued || !mounted) return;
    _profileTutorialCheckQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _profileTutorialCheckQueued = false;
      if (!mounted) return;
      unawaited(_tryStartNextProfileTutorial());
    });
  }

  Future<void> _tryStartNextProfileTutorial() async {
    if (_profileTutorialCheckInFlight ||
        _activeProfileTutorial != null ||
        !_profileTutorialProfileReady ||
        _profileTutorialViewerId.isEmpty ||
        _isProfileShowcaseRunning()) {
      return;
    }

    _profileTutorialCheckInFlight = true;
    final expectedGeneration = _profileTutorialGeneration;
    final expectedViewerId = _profileTutorialViewerId;
    final expectedProfileId = _profileTutorialProfileId;
    final storage = ref.read(tutorialStorageProvider);

    try {
      for (final step in _ProfileTutorialStep.values) {
        if (!_canShowProfileTutorial(step) ||
            _completedProfileTutorials.contains(step)) {
          continue;
        }

        final shouldShow = await storage.shouldShow(
          expectedViewerId,
          step.storageKey,
        );
        if (!mounted ||
            expectedGeneration != _profileTutorialGeneration ||
            expectedViewerId != _profileTutorialViewerId ||
            expectedProfileId != _profileTutorialProfileId ||
            _activeProfileTutorial != null ||
            _isProfileShowcaseRunning()) {
          return;
        }
        if (!shouldShow) continue;

        // The UI may have changed while storage was being read. Re-check the
        // live condition before showing a target that may no longer exist.
        if (!_canShowProfileTutorial(step)) {
          _queueProfileTutorialCheck();
          return;
        }

        _activeProfileTutorial = step;
        try {
          ShowcaseView.get().startShowCase([_profileTutorialKey(step)]);
        } catch (_) {
          _activeProfileTutorial = null;
          _queueProfileTutorialCheck();
        }
        return;
      }
    } finally {
      if (expectedGeneration == _profileTutorialGeneration) {
        _profileTutorialCheckInFlight = false;
      }
    }
  }

  bool _canShowProfileTutorial(_ProfileTutorialStep step) {
    if (!_profileTutorialProfileReady) return false;

    return switch (step) {
      _ProfileTutorialStep.menuOpen => !_profileCardOpen,
      _ProfileTutorialStep.settings =>
        _profileCardOpen &&
            _profileCardCtrl.status == AnimationStatus.completed &&
            _profileTutorialIsMe,
      _ProfileTutorialStep.menuClose =>
        _profileCardOpen &&
            _profileCardCtrl.status == AnimationStatus.completed,
      _ProfileTutorialStep.chaputPull =>
        !_profileCardOpen &&
            _profileTutorialChaputAllowed &&
            _profileTutorialThreadSheetVisible &&
            _profileTutorialThreadCount >= 1,
      _ProfileTutorialStep.chaputSwipe =>
        !_profileCardOpen &&
            _profileTutorialChaputAllowed &&
            _profileTutorialThreadSheetVisible &&
            _profileTutorialThreadCount >= 2 &&
            (_profileTutorialActiveThreadId?.isNotEmpty ?? false),
    };
  }

  GlobalKey _profileTutorialKey(_ProfileTutorialStep step) => switch (step) {
    _ProfileTutorialStep.menuOpen => _profileMenuShowcaseKey,
    _ProfileTutorialStep.settings => _settingsShowcaseKey,
    _ProfileTutorialStep.menuClose => _profileCloseShowcaseKey,
    _ProfileTutorialStep.chaputPull => _chaputSheetShowcaseKey,
    _ProfileTutorialStep.chaputSwipe => _chaputThreadSwipeShowcaseKey,
  };

  _ProfileTutorialStep? _profileTutorialStepForKey(GlobalKey key) {
    for (final step in _ProfileTutorialStep.values) {
      if (_profileTutorialKey(step) == key) return step;
    }
    return null;
  }

  bool _isProfileShowcaseRunning() {
    try {
      return ShowcaseView.get().isShowcaseRunning;
    } catch (_) {
      return false;
    }
  }

  void _completeProfileTutorialFromCard(_ProfileTutorialStep step) {
    if (_activeProfileTutorial != step) return;
    try {
      ShowcaseView.get().completed(_profileTutorialKey(step));
    } catch (_) {}
  }

  void _handleProfileShowcaseComplete(int? _, GlobalKey key) {
    final step = _profileTutorialStepForKey(key);
    if (step == null || step != _activeProfileTutorial) return;

    final viewerId = _profileTutorialViewerId;
    _activeProfileTutorial = null;
    _completedProfileTutorials.add(step);
    if (viewerId.isNotEmpty) {
      unawaited(
        ref.read(tutorialStorageProvider).markShown(viewerId, step.storageKey),
      );
    }
    _queueProfileTutorialCheck();
  }

  void _handleProfileShowcaseDismiss(GlobalKey? key) {
    if (key == null ||
        _profileTutorialStepForKey(key) == _activeProfileTutorial) {
      _activeProfileTutorial = null;
    }
  }

  bool _isCurrentThreeRequest(three.ThreeJS threeJsRef, int epoch) {
    return mounted &&
        !_isDisposed &&
        epoch == _threeLoadEpoch &&
        identical(_threeJs, threeJsRef);
  }

  void _disposeThreeRef(three.ThreeJS threeJsRef) {
    // ThreeJS declares scene/camera as late fields. A route can disappear
    // while the platform view is still initializing, so guard every access.
    try {
      threeJsRef.dispose();
      return;
    } catch (_) {
      // If ThreeJS.dispose exits before its native cleanup because setup did
      // not finish, release each independent resource best-effort.
      try {
        threeJsRef.ticker?.dispose();
      } catch (_) {}
      try {
        threeJsRef.renderer?.dispose();
      } catch (_) {}
      try {
        threeJsRef.renderTarget?.dispose();
      } catch (_) {}
      try {
        threeJsRef.angle?.dispose([threeJsRef.texture]);
      } catch (_) {}
    }
  }

  void _disposeThree({bool cancelPending = true}) {
    if (cancelPending) {
      _threeCreateTimer?.cancel();
      _threeCreateTimer = null;
      _pendingThreeTreeId = null;
    }
    _threeLoadEpoch++;
    _threeSurfaceGeneration++;
    final threeJs = _threeJs;
    if (threeJs != null) {
      _disposeThreeRef(threeJs);
    }
    _threeJs = null;
    _treeGroup = null;
    _ground = null;
    _threeReady = false;
    _origMaterials.clear();
    _silhouetteApplied = false;
  }

  void _createThreeIfNeeded(String treeId) {
    if (_treeSuspendedForCoveredRoute) return;
    if (_lastTreeId == treeId &&
        (_threeJs != null || _pendingThreeTreeId == treeId)) {
      return;
    }

    _lastTreeId = treeId;
    _threeError = null;
    _threeReady = false;

    // Give ANGLE one frame to release the old surface before creating the
    // next renderer. Two active renderers at once can produce black or split
    // GLB materials on iOS devices.
    _disposeThree(cancelPending: false);
    _threeCreateTimer?.cancel();
    _pendingThreeTreeId = treeId;
    final epoch = _threeLoadEpoch;
    unawaited(TreeModelCache.instance.ensureWarm(treeId));

    // Physically unmount the old platform view before constructing its
    // replacement. Keeping both renderers alive even briefly can corrupt GLB
    // material/texture state on iOS ANGLE.
    if (mounted) {
      setState(() {});
    }

    _threeCreateTimer = Timer(const Duration(milliseconds: 16), () {
      _threeCreateTimer = null;
      if (!mounted ||
          _isDisposed ||
          epoch != _threeLoadEpoch ||
          _pendingThreeTreeId != treeId) {
        return;
      }

      late final three.ThreeJS js;
      js = three.ThreeJS(
        // Use native device pixel density. The old 1.0 multiplier visibly
        // downsampled the tree on high-density displays.
        setup: () => _setup(threeJsRef: js, treeId: treeId, epoch: epoch),
        onSetupComplete: () {
          if (!_isCurrentThreeRequest(js, epoch)) {
            _disposeThreeRef(js);
            return;
          }
          if (_treeSuspendedForCoveredRoute) {
            js.pause = true;
            try {
              js.ticker?.stop(canceled: false);
            } catch (_) {}
            return;
          }
          setState(() => _threeReady = true);
          _applyPendingThreadFocus();
        },
      );

      _pendingThreeTreeId = null;
      if (!mounted || _isDisposed || epoch != _threeLoadEpoch) {
        _disposeThreeRef(js);
        return;
      }
      setState(() {
        _threeJs = js;
      });
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
    required int epoch,
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
      threeJsRef.scene.add(three.AmbientLight(AppColors.chaputWhiteHex, 0.75));

      final dir = three.DirectionalLight(AppColors.chaputWhiteHex, 0.95);
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

      final tree = await TreeModelCache.instance.loadFreshScene(treeId);
      if (!_isCurrentThreeRequest(threeJsRef, epoch)) {
        _disposeThreeRef(threeJsRef);
        return;
      }

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
      _modelMaxDim = math
          .max(size2.x, math.max(size2.y, size2.z))
          .clamp(0.1, 1000.0);

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
      _modelMaxDim = math
          .max(size3.x, math.max(size3.y, size3.z))
          .clamp(0.1, 1000.0);

      _groundY = 0.0;

      if (!_isCurrentThreeRequest(threeJsRef, epoch)) {
        _disposeThreeRef(threeJsRef);
        return;
      }

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
        if (!_isCurrentThreeRequest(threeJsRef, epoch)) return;
        _tickCenterShift(dt);
        _tickSnap(dt);
        _updateCamera(threeJsRef, dt);
      });
    } catch (e, st) {
      log('ThreeJS setup error: $e', stackTrace: st);
      if (!_isCurrentThreeRequest(threeJsRef, epoch)) return;
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

    final local = three.Vector3(pos.getX(i), pos.getY(i), pos.getZ(i));

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
  }

  int _resolveEmptyChaputIndex(String userId, bool isMe) {
    if (_emptyChaputProfileId != userId ||
        _emptyChaputIndex == null ||
        _emptyChaputIsMe != isMe) {
      _emptyChaputProfileId = userId;
      _emptyChaputIsMe = isMe;
      final keys = isMe
          ? _emptyChaputMessageKeysSelf
          : _emptyChaputMessageKeysOther;
      _emptyChaputIndex = math.Random().nextInt(keys.length);
    }
    return _emptyChaputIndex!;
  }

  void _scheduleEmptyChaputAnchorPick() {
    if (_emptyChaputAnchorPicked || !_threeReady || _treeGroup == null) return;
    _emptyChaputAnchorPicked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_treeGroup == null) return;
      _pickNewRandomAnchorAndSnap();
    });
  }

  void _clearEmptyChaputState() {
    _emptyChaputAnchorPicked = false;
    _emptyChaputIndex = null;
    _emptyChaputProfileId = null;
    _emptyChaputIsMe = null;
    _emptyChaputVisualSignature = null;
  }

  void _ensureEmptyChaputFocus({
    required String profileId,
    required bool isMe,
    String? profilePhotoKey,
    String? profilePhotoUrl,
  }) {
    final signature =
        '$profileId|$isMe|${profilePhotoKey ?? ''}|${profilePhotoUrl ?? ''}';
    final needsRepick =
        _emptyChaputVisualSignature != signature ||
        _focusAnchor == null ||
        !_emptyChaputAnchorPicked;

    if (!needsRepick) return;

    _emptyChaputVisualSignature = signature;
    _emptyChaputAnchorPicked = false;
    _focusAnchor = null;
    _isInteracting = false;
    _pendingTreeModeShift = false;
    _treeModeShiftDoneThisGesture = false;
    _resetMarkerStabilizer();
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

    _resetMarkerStabilizer();

    // ✅ mevcut durumdan -> yeni anchor'a smooth geç
    _startSnapToNewAnchor();
  }

  bool _isBlankDraft() {
    // sadece whitespace ise boş kabul
    return _msgCtrl.text.trim().isEmpty;
  }

  void _setChaputSheetExtent(double value) {
    if ((_chaputSheetExtent - value).abs() < 0.0001) return;
    _chaputSheetExtent = value;
    if ((_chaputSheetExtentListenable.value - value).abs() >= 0.0001) {
      _chaputSheetExtentListenable.value = value;
    }
  }

  void _openCollapsedChaputSheet() {
    if (!_chaputSheetCtrl.isAttached ||
        _chaputSheetExtent >
            _chaputSheetMin + _chaputSheetCollapsedTapTolerance ||
        _composerOpen ||
        _silhouetteMode) {
      return;
    }
    HapticFeedback.selectionClick();
    _chaputSheetPrevExtent = _chaputSheetMid;
    _chaputSheetCtrl.animateTo(
      _chaputSheetMid,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _openInitialThreadSheet() {
    _openChaputSheetToExtent(_chaputSheetMax);
  }

  void _openCreatedThreadSheet() {
    _openChaputSheetToExtent(_chaputSheetMid);
  }

  void _openChaputSheetToExtent(double targetExtent) {
    if (_silhouetteMode) return;
    final clampedTarget = targetExtent.clamp(_chaputSheetMin, _chaputSheetMax);
    _chaputSheetPrevExtent = clampedTarget;
    _setChaputSheetExtent(clampedTarget);

    void expand() {
      if (!mounted || !_chaputSheetCtrl.isAttached) return;
      _chaputSheetCtrl.animateTo(
        clampedTarget,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }

    expand();
    WidgetsBinding.instance.addPostFrameCallback((_) => expand());
    Future<void>.delayed(const Duration(milliseconds: 180), expand);
    Future<void>.delayed(const Duration(milliseconds: 520), expand);
  }

  void _handleInitialMessageRevealed(String messageId) {
    if (_pendingInitialMessageId != messageId) return;
    if (!mounted) return;
    setState(() {
      _pendingInitialThreadId = null;
      _pendingInitialMessageId = null;
    });
  }

  void _markTypingUsersChanged() {
    _typingRevision.value = _typingRevision.value + 1;
    _syncTypingSound();
  }

  String _typingKey(String threadId, String userId) =>
      '$threadId:${userId.toLowerCase()}';

  void _clearTypingExpiryTimers() {
    for (final timer in _typingExpiryTimers.values) {
      timer.cancel();
    }
    _typingExpiryTimers.clear();
  }

  void _clearTypingForThread(String threadId) {
    final ids = _typingUsersByThread.remove(threadId);
    if (ids == null || ids.isEmpty) return;
    for (final id in ids) {
      _typingExpiryTimers.remove(_typingKey(threadId, id))?.cancel();
    }
    _markTypingUsersChanged();
  }

  void _setTypingUser(String threadId, String userId) {
    final normalized = userId.toLowerCase();
    final set = _typingUsersByThread.putIfAbsent(threadId, () => <String>{});
    final changed = set.add(normalized);
    final key = _typingKey(threadId, normalized);
    _typingExpiryTimers.remove(key)?.cancel();
    _typingExpiryTimers[key] = Timer(const Duration(seconds: 4), () {
      _removeTypingUser(threadId, normalized);
    });
    if (changed) {
      _markTypingUsersChanged();
    }
  }

  void _removeTypingUser(String threadId, String userId) {
    final normalized = userId.toLowerCase();
    _typingExpiryTimers.remove(_typingKey(threadId, normalized))?.cancel();
    final set = _typingUsersByThread[threadId];
    if (set == null) return;
    final changed = set.remove(normalized);
    if (set.isEmpty) {
      _typingUsersByThread.remove(threadId);
    }
    if (changed) {
      _markTypingUsersChanged();
    }
  }

  Map<String, List<LiteUser>> _resolveTypingUsersByThread(
    Map<String, LiteUser> usersById,
    String viewerId,
  ) {
    final typingUsersByThread = <String, List<LiteUser>>{};
    final viewerNorm = viewerId.toLowerCase();
    _typingUsersByThread.forEach((threadId, ids) {
      final list = <LiteUser>[];
      for (final id in ids) {
        if (id.toLowerCase() == viewerNorm) continue;
        LiteUser? u = usersById[id];
        u ??= usersById[id.toUpperCase()];
        u ??= usersById[id.toLowerCase()];
        if (u != null) list.add(u);
      }
      if (list.isNotEmpty) {
        typingUsersByThread[threadId] = list;
      }
    });
    return typingUsersByThread;
  }

  bool _hasRemoteTypingForActiveThread() {
    final threadId = _activeThreadId;
    if (threadId == null || threadId.isEmpty) return false;
    final ids = _typingUsersByThread[threadId];
    if (ids == null || ids.isEmpty) return false;
    final viewerNorm =
        (_lastChaputArgs?.viewerId ??
                ref.read(meControllerProvider).value?.user.userId ??
                '')
            .toLowerCase();
    return ids.any((id) => id.toLowerCase() != viewerNorm);
  }

  void _syncTypingSound() {
    if (_isDisposed) return;
    final activeThreadId = _activeThreadId;
    final shouldPlay =
        _activeThreadIsParticipant && _hasRemoteTypingForActiveThread();
    if (!shouldPlay || activeThreadId == null || activeThreadId.isEmpty) {
      _stopTypingSound();
      return;
    }
    if (_typingSoundActive && _typingSoundThreadId == activeThreadId) return;
    if (_typingSoundActive) {
      unawaited(ChaputSoundService.instance.stopTypingLoop());
    }
    _typingSoundActive = true;
    _typingSoundThreadId = activeThreadId;
    unawaited(ChaputSoundService.instance.startTypingLoop());
  }

  void _stopTypingSound() {
    if (!_typingSoundActive) return;
    _typingSoundActive = false;
    _typingSoundThreadId = null;
    unawaited(ChaputSoundService.instance.stopTypingLoop());
  }

  bool _shouldShowReplyBar({
    required double extent,
    required bool canReplyOnActive,
    required String? activeThreadId,
  }) {
    if (activeThreadId == null || activeThreadId.isEmpty) {
      return false;
    }
    final replyScopedToAnotherThread =
        _replyTargetThreadId != null && _replyTargetThreadId != activeThreadId;
    return canReplyOnActive &&
        !replyScopedToAnotherThread &&
        extent >= _chaputSheetMid - 0.01 &&
        !_composerOpen &&
        !_silhouetteMode;
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

  Future<void> _openComposerOptionsSheet() async {
    // Klavye açıkken sheet görünür alanı aşmasın diye kb’yi alıyoruz
    final kb = context.responsive.keyboardInset;
    if (kb > 0 &&
        !_composerOpen &&
        _chaputSheetExtent < _chaputSheetMax - _chaputSheetMaxTolerance) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_chaputSheetCtrl.isAttached) return;
        _chaputSheetCtrl.animateTo(
          _chaputSheetMax,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }

    await _showTreePreservingOverlay<void>(
      () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.chaputTransparent,
        isScrollControlled: true,
        builder: (sheetContext) {
          final responsive = sheetContext.responsive;
          return Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              // sheet’i klavyenin üstüne "oturt"
              bottom: responsive.bottomFixedOffset(base: 10),
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
      ),
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

    const composerH = 72.0;
    const gap = 12.0;

    final bottom = context.responsive.bottomFixedOffset(base: composerH + gap);

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

  void _handleFollowActionError(Object error) {
    if (error is FollowActionException &&
        error.code == 'follow_request_rate_limited') {
      _showGlassToast(
        context.t('profile.follow_rate_limited'),
        icon: Icons.hourglass_top_rounded,
        duration: const Duration(seconds: 2),
      );
    }
  }

  void _syncProfileFollowState(ProfilePreview preview, {required bool isMe}) {
    if (isMe || preview.id.isEmpty) return;
    final requestPending = preview.isFollowing ? false : preview.requestPending;
    final signature = '${preview.id}|${preview.isFollowing}|$requestPending';
    if (_lastFollowStateSyncSignature == signature) return;
    _lastFollowStateSyncSignature = signature;

    final syncedPreview = preview.copyWith(requestPending: requestPending);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _isDisposed ||
          _lastFollowStateSyncSignature != signature) {
        return;
      }
      ref
          .read(profileVisitHistoryProvider.notifier)
          .updateFollowState(syncedPreview);
      if (ref.exists(userSearchControllerProvider)) {
        ref
            .read(userSearchControllerProvider.notifier)
            .updateFollowState(
              userId: syncedPreview.id,
              isFollowing: syncedPreview.isFollowing,
              requestPending: syncedPreview.requestPending,
            );
      }
      if (ref.exists(recommendedUserControllerProvider)) {
        ref
            .read(recommendedUserControllerProvider.notifier)
            .updateFollowState(
              userId: syncedPreview.id,
              isFollowing: syncedPreview.isFollowing,
              requestPending: syncedPreview.requestPending,
            );
      }
    });
  }

  String _resolveProfileId(Map<String, dynamic>? profileJson, String fallback) {
    if (profileJson == null) return fallback;
    final user = (profileJson['user'] is Map)
        ? (profileJson['user'] as Map)
        : null;
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
    unawaited(
      ref.read(meControllerProvider.notifier).fetchAndStoreMe().catchError((_) {
        return ref.read(meControllerProvider).value;
      }),
    );
  }

  Future<bool> _verifyPurchaseAndApply(PaywallPurchase purchase) async {
    try {
      final confirmed = await _confirmReplaceSubscriptionIfNeeded(purchase);
      if (!confirmed) return false;
      final api = ref.read(billingApiProvider);
      BillingVerifyResult? res;
      Object? lastError;
      final attempts = purchase.provider == 'REVENUECAT' ? 6 : 1;
      for (int i = 0; i < attempts; i++) {
        try {
          res = await api.verifyPurchase(
            provider: purchase.provider,
            productId: purchase.productId,
            transactionId: purchase.transactionId,
            devToken: Env.devBillingToken,
          );
          break;
        } catch (e) {
          lastError = e;
          if (purchase.provider != 'REVENUECAT' ||
              !e.toString().contains('pending_webhook') ||
              i == attempts - 1) {
            rethrow;
          }
          await Future.delayed(Duration(milliseconds: 850 + (i * 450)));
        }
      }
      if (res == null) throw lastError ?? Exception('verify_failed');
      _applyBillingResult(res);
      return true;
    } catch (_) {
      if (!mounted) return false;
      _showGlassToast(
        context.t('profile.toast.purchase_verify_failed'),
        icon: Icons.error_outline,
      );
      return false;
    }
  }

  Future<PaywallPurchase?> _purchaseWithRevenueCat(String productId) async {
    final userId = ref.read(meControllerProvider).value?.user.userId;
    if (userId == null || userId.isEmpty) {
      log('RevenueCat purchase blocked: missing backend user id');
      _showGlassToast(
        context.t('paywall.purchase_failed'),
        icon: Icons.error_outline,
      );
      return null;
    }

    final loginResult = await RevenueCatService.instance.logInWithBackendUserId(
      userId,
    );
    if (!loginResult.isSuccess) {
      log(
        'RevenueCat login before purchase failed status=${loginResult.status} '
        'code=${loginResult.errorCode} message=${loginResult.message}',
        error: loginResult.exception,
      );
      if (!mounted) return null;
      _showGlassToast(
        _revenueCatFailureText(loginResult),
        icon: Icons.error_outline,
      );
      return null;
    }

    final result = await RevenueCatService.instance.purchaseProductId(
      productId,
    );
    if (result.isCancelled) return null;
    if (!result.isSuccess || result.data == null) {
      if (!mounted) return null;
      log(
        'RevenueCat purchase failed product=$productId status=${result.status} '
        'code=${result.errorCode} message=${result.message}',
        error: result.exception,
      );
      _showGlassToast(
        _revenueCatFailureText(result),
        icon: Icons.error_outline,
      );
      return null;
    }

    final transaction = result.data!.storeTransaction;
    final transactionId = transaction.transactionIdentifier.isNotEmpty
        ? transaction.transactionIdentifier
        : 'revenuecat_${DateTime.now().millisecondsSinceEpoch}_$productId';

    return PaywallPurchase(
      productId: result.data!.productId,
      provider: 'REVENUECAT',
      transactionId: transactionId,
    );
  }

  String _revenueCatFailureText(RevenueCatResult<dynamic> result) {
    return switch (result.status) {
      RevenueCatResultStatus.invalidRequest ||
      RevenueCatResultStatus.notInitialized => context.t(
        'paywall.purchase_not_configured',
      ),
      RevenueCatResultStatus.productNotFound => context.t(
        'paywall.product_not_found',
      ),
      RevenueCatResultStatus.networkError => context.t(
        'paywall.purchase_network_failed',
      ),
      _ => context.t('paywall.purchase_failed'),
    };
  }

  Future<bool> _restorePurchasesWithRevenueCat() async {
    final userId = ref.read(meControllerProvider).value?.user.userId;
    if (userId != null && userId.isNotEmpty) {
      await RevenueCatService.instance.logInWithBackendUserId(userId);
    }

    final revenueCatResult = await RevenueCatService.instance
        .restorePurchases();
    if (!revenueCatResult.isSuccess) {
      return false;
    }

    final restored = await ref.read(accountApiProvider).restorePurchases();
    await ref.read(meControllerProvider.notifier).fetchAndStoreMe();
    return restored || revenueCatResult.data?.hasChaputSubscription == true;
  }

  Future<bool> _confirmReplaceSubscriptionIfNeeded(
    PaywallPurchase purchase,
  ) async {
    const subscriptionProducts = <String>{
      'chaput_plus_month',
      'chaput_pro_month',
      'chaput_pro_year',
    };
    if (!subscriptionProducts.contains(purchase.productId)) return true;

    final meAsync = ref.read(meControllerProvider);
    var me = meAsync.value;
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
      if (expiresAt != null &&
          !expiresAt.isUtc &&
          !expiresAtRaw.contains('Z')) {
        expiresAt = DateTime.parse('${expiresAtRaw}Z');
      }
    }

    if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
      return true;
    }

    // Only warn when we have a non-free active plan.
    if (plan == 'FREE') return true;

    final untilText = expiresAt?.toLocal().toString().split('.').first;
    final res = await _showTreePreservingOverlay<bool>(
      () => showModalBottomSheet<bool>(
        context: context,
        backgroundColor: AppColors.chaputTransparent,
        isScrollControlled: true,
        builder: (_) => SubscriptionReplaceSheet(untilText: untilText),
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
                  color: AppColors.chaputBlack.withValues(alpha: 0.12 * t),
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

    final mask = _showNavMask();
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 220), () {
        if (mask.mounted) {
          mask.remove();
        }
      }),
    );
    final router = GoRouter.of(context);
    _reloadOnPopNext = true;
    setState(() {
      _navToOtherProfile = true;
    });
    _disposeThree();
    await router.push('/profile/$userId', extra: {'threadId': threadId});
    if (!mounted) return;
    if (mask.mounted) mask.remove();
  }

  void _handleReplyRequested(ChaputThreadItem thread, ChaputMessage message) {
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _replyTarget = message;
      _replyTargetThreadId = thread.threadId;
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
    final messageBody = cleanUserTextForSubmit(body, maxLength: 2000);
    if (messageBody.isEmpty) return;
    final api = ref.read(chaputApiProvider);
    final kind = whisper ? 'WHISPER' : 'NORMAL';
    final replyToId =
        (_replyTarget != null && _replyTargetThreadId == thread.threadId)
        ? _replyTarget!.id
        : null;
    final replyTarget =
        (_replyTarget != null && _replyTargetThreadId == thread.threadId)
        ? _replyTarget
        : null;
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final meId = ref.read(meControllerProvider).value?.user.userId ?? viewerId;
    final msg = ChaputMessage(
      id: localId,
      senderId: meId.isNotEmpty ? meId.toLowerCase() : '',
      kind: kind,
      body: messageBody,
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
            ChaputMessagesArgs(
              threadId: thread.threadId,
              profileId: profileIdHex,
            ),
          ).notifier,
        )
        .addLocalMessage(msg);
    _playSmallFeedback(ChaputSoundEffect.sendMessage);
    if (replyTarget != null) {
      setState(() {
        _replyTarget = null;
        _replyTargetThreadId = null;
      });
    }

    try {
      final serverMsg = await api.sendMessage(
        threadIdHex: thread.threadId,
        body: messageBody,
        kind: kind,
        replyToId: replyToId,
      );
      ref
          .read(
            chaputMessagesControllerProvider(
              ChaputMessagesArgs(
                threadId: thread.threadId,
                profileId: profileIdHex,
              ),
            ).notifier,
          )
          .confirmDelivered(localId: localId, serverMessage: serverMsg);

      if (thread.state == 'PENDING') {
        ref
            .read(chaputThreadsControllerProvider(chaputArgs).notifier)
            .updateThreadState(
              threadId: thread.threadId,
              newState: 'OPEN',
              pendingExpiresAt: null,
            );
      }
    } catch (_) {
      // leave local message as-is; UI already shows it as sent but undelivered
    }
  }

  Future<void> _makeThreadHidden({
    required ChaputThreadItem thread,
    required String profileIdHex,
    required ChaputThreadsArgs chaputArgs,
  }) async {
    final api = ref.read(chaputApiProvider);

    // ✅ 1) fresh decision'ı direkt API sonucundan al (race yok)
    final decisionNotifier = ref.read(
      chaputDecisionControllerProvider(profileIdHex).notifier,
    );

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
      if (freshDecision.plan.period != null &&
          freshDecision.plan.period!.isNotEmpty) {
        decisionNotifier.applyPlanPeriod(freshDecision.plan.period!);
      }
    } catch (_) {
      freshDecision = await decisionNotifier.fetchDecisionAndReturn();
    }
    final freshHidden = freshDecision?.credits.hidden ?? 0;

    Future<bool> hideNow() async {
      try {
        await api.hideThread(threadIdHex: thread.threadId);
        return true;
      } catch (_) {
        return false;
      }
    }

    // ✅ 2) kredi varsa direkt gizle
    if (freshHidden > 0) {
      final ok = await hideNow();
      if (!ok) {
        _showGlassToast(
          context.t('profile.toast.chaput_hide_failed'),
          icon: Icons.error_outline,
        );
        return;
      }

      // UI/State: 1 kredi düş
      decisionNotifier.applyCreditsDelta(hidden: -1);
      final nextKind = thread.isSpecial ? 'HIDDEN_SPECIAL' : 'HIDDEN';
      ref
          .read(chaputThreadsControllerProvider(chaputArgs).notifier)
          .updateThreadKind(thread.threadId, nextKind);

      _showGlassToast(
        context.t('profile.toast.chaput_hidden'),
        icon: Icons.lock_outline,
      );
      return;
    }

    // ✅ 3) kredi yoksa paywall
    final purchase = await _openPaywall(
      feature: PaywallFeature.hideCredentials,
    );
    if (purchase == null) return;

    final verified = await _verifyPurchaseAndApply(purchase);
    if (!verified) return;

    // Satın aldıktan sonra tekrar dene (istersen tekrar fetch yap)
    final ok = await hideNow();
    if (!ok) {
      _showGlassToast(
        context.t('profile.toast.chaput_hide_failed'),
        icon: Icons.error_outline,
      );
      return;
    }

    // satın alma doğrulandıysa server zaten krediyi yazmış olmalı,
    // ama UI için güvenli şekilde local düşür / güncelle
    decisionNotifier.applyCreditsDelta(hidden: -1);
    final nextKind = thread.isSpecial ? 'HIDDEN_SPECIAL' : 'HIDDEN';
    ref
        .read(chaputThreadsControllerProvider(chaputArgs).notifier)
        .updateThreadKind(thread.threadId, nextKind);

    _showGlassToast(
      context.t('profile.toast.chaput_hidden'),
      icon: Icons.lock_outline,
    );
  }

  Future<void> _archiveThread({
    required ChaputThreadItem thread,
    required String profileIdHex,
    required ChaputThreadsArgs chaputArgs,
  }) async {
    if (thread.threadId.length != 32) {
      _showGlassToast(
        context.t('profile.toast.chaput_not_found'),
        icon: Icons.error_outline,
      );
      return;
    }

    try {
      await ref
          .read(chaputApiProvider)
          .archiveThread(threadIdHex: thread.threadId);
      if (!mounted) return;

      setState(() {
        _chaputActiveIndex = 0;
        _replyWhisperMode = false;
        _replyTarget = null;
        _replyTargetThreadId = null;
      });

      final threadsNotifier = ref.read(
        chaputThreadsControllerProvider(chaputArgs).notifier,
      );
      threadsNotifier.removeThread(thread.threadId);
      if (_chaputPageCtrl.hasClients) {
        _syncChaputFeedbackBasePage(0);
        _chaputPageCtrl.jumpToPage(0);
      }
      unawaited(threadsNotifier.refresh());
      if (_decisionProfileId != null) {
        unawaited(
          ref
              .read(chaputDecisionControllerProvider(profileIdHex).notifier)
              .fetchDecision(),
        );
      }
      _showGlassToast(
        context.t('profile.toast.chaput_archived'),
        icon: Icons.archive_outlined,
      );
    } catch (_) {
      _showGlassToast(
        context.t('profile.toast.chaput_archive_failed'),
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _reportThread(ChaputThreadItem thread) async {
    if (thread.threadId.length != 32) {
      _showGlassToast(
        context.t('reports.toast.failed'),
        icon: Icons.error_outline,
      );
      return;
    }

    final draft = await _showTreePreservingOverlay<ReportContentDraft>(
      () =>
          showReportContentSheet(context, targetType: ReportTargetType.chaput),
    );
    if (draft == null) return;

    try {
      await ref
          .read(reportsApiProvider)
          .reportChaput(
            chaputIdHex: thread.threadId,
            reasonCode: draft.reasonCode,
            details: draft.details,
          );
      _showGlassToast(
        context.t('reports.toast.thread_success'),
        icon: Icons.flag_outlined,
      );
    } catch (error) {
      final raw = error.toString();
      final key = raw.contains('already_reported_recently')
          ? 'reports.toast.already_sent'
          : ((raw.contains('not_allowed') || raw.contains('cannot_report_self'))
                ? 'reports.toast.not_allowed'
                : 'reports.toast.failed');
      _showGlassToast(context.t(key), icon: Icons.error_outline);
    }
  }

  Future<void> _reportMessage(ChaputMessage message) async {
    if (message.id.length != 32) {
      _showGlassToast(
        context.t('reports.toast.failed'),
        icon: Icons.error_outline,
      );
      return;
    }

    final draft = await _showTreePreservingOverlay<ReportContentDraft>(
      () =>
          showReportContentSheet(context, targetType: ReportTargetType.message),
    );
    if (draft == null) return;

    try {
      await ref
          .read(reportsApiProvider)
          .reportMessage(
            messageIdHex: message.id,
            reasonCode: draft.reasonCode,
            details: draft.details,
          );
      _showGlassToast(
        context.t('reports.toast.message_success'),
        icon: Icons.flag_outlined,
      );
    } catch (error) {
      final raw = error.toString();
      final key = raw.contains('already_reported_recently')
          ? 'reports.toast.already_sent'
          : ((raw.contains('not_allowed') || raw.contains('cannot_report_self'))
                ? 'reports.toast.not_allowed'
                : 'reports.toast.failed');
      _showGlassToast(context.t(key), icon: Icons.error_outline);
    }
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
      _showGlassToast(
        context.t('profile.toast.profile_not_found'),
        icon: Icons.error_outline,
      );
      return;
    }
    final text = cleanUserTextForSubmit(
      _msgCtrl.text,
      maxLength: kInitialChaputMessageMaxLength,
    );
    if (text.isEmpty) {
      _showGlassToast(
        context.t('profile.toast.enter_message'),
        icon: Icons.edit_outlined,
      );
      return;
    }

    setState(() => _chaputSendLoading = true);
    try {
      final api = ref.read(chaputApiProvider);
      final kind = (_highlightMode && _anonMode)
          ? 'HIDDEN_SPECIAL'
          : (_highlightMode ? 'SPECIAL' : (_anonMode ? 'HIDDEN' : 'NORMAL'));

      final anchor = _focusAnchor ?? _draftAnchor;

      final out = await api.startThread(profileIdHex: profileId, kind: kind);

      if (out.threadId.isNotEmpty && anchor != null) {
        unawaited(() async {
          try {
            await api.setThreadNode(
              threadIdHex: out.threadId,
              profileIdHex: profileId,
              x: anchor.x,
              y: anchor.y,
              z: anchor.z,
            );
          } catch (error, st) {
            log('thread node persist failed: $error', stackTrace: st);
          }
        }());
      }

      if (out.threadId.isNotEmpty) {
        final now = DateTime.now().toUtc();
        final created = ChaputThreadItem(
          threadId: out.threadId,
          threadSlug: out.threadSlug,
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
        final chaputCtrl = ref.read(
          chaputThreadsControllerProvider(chaputArgs).notifier,
        );
        _pendingCreatedThreadId = out.threadId;
        _activeThreadId = out.threadId;
        _activeThreadIsParticipant = true;
        chaputCtrl.addThreadOptimistic(created, chaputArgs);
        if (viewerLite != null) {
          chaputCtrl.addUsers({viewerLite.id: viewerLite});
        }
        await api.sendMessage(threadIdHex: out.threadId, body: text);
        _playSmallFeedback(ChaputSoundEffect.sendMessage);

        final nextThreads = _stableSessionThreads(
          profileIdHex: profileId,
          source: ref.read(chaputThreadsControllerProvider(chaputArgs)).items,
        );
        final createdIndex = nextThreads.indexWhere(
          (t) => t.threadId == out.threadId,
        );
        final targetIndex = createdIndex >= 0 ? createdIndex : 0;

        if (mounted) {
          setState(() {
            _chaputThreadCreated = true;
            _chaputActiveIndex = targetIndex;
          });
        } else {
          _chaputThreadCreated = true;
          _chaputActiveIndex = targetIndex;
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final currentThreads = _stableSessionThreads(
            profileIdHex: profileId,
            source: ref.read(chaputThreadsControllerProvider(chaputArgs)).items,
          );
          if (currentThreads.isEmpty) return;
          final idx = currentThreads.indexWhere(
            (t) => t.threadId == out.threadId,
          );
          final safeIndex = idx >= 0
              ? idx
              : (targetIndex < currentThreads.length
                    ? targetIndex
                    : currentThreads.length - 1);
          final targetThread = currentThreads[safeIndex];
          if (_chaputPageCtrl.hasClients) {
            final pageIdx = _pageIndexForThreadIndex(safeIndex);
            _syncChaputFeedbackBasePage(pageIdx);
            _chaputPageCtrl.jumpToPage(pageIdx);
          }
          setState(() => _chaputActiveIndex = safeIndex);
          _subscribeThreadSocket(targetThread.threadId, profileId);
          _activeThreadId = targetThread.threadId;
          _activeThreadIsParticipant = true;
          _syncTypingSound();
          _focusToThreadAnchor(targetThread, profileId);
          _openCreatedThreadSheet();
          _pendingCreatedThreadId = null;
        });
      }

      _msgCtrl.clear();
      _closeComposer();
      _showGlassToast(
        context.t('profile.toast.chaput_sent'),
        icon: Icons.check_circle_outline,
      );
      if (_decisionProfileId != null) {
        ref
            .read(
              chaputDecisionControllerProvider(_decisionProfileId!).notifier,
            )
            .fetchDecision();
      }
    } catch (e) {
      _pendingCreatedThreadId = null;
      _showGlassToast(
        context.t('profile.toast.chaput_send_failed'),
        icon: Icons.error_outline,
      );
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
    if (_reviveFlowBusy) return;
    HapticFeedback.selectionClick();
    if (threadIdHex.length != 32) {
      _showGlassToast(
        context.t('profile.toast.chaput_not_found'),
        icon: Icons.error_outline,
      );
      return;
    }
    final api = ref.read(chaputApiProvider);
    final isPro = _planType == 'PRO';
    final hasRevive = _creditRevive > 0;
    var revived = false;

    setState(() {
      _reviveFlowBusy = true;
      _reviveArchiveOverrideProfileId = profileIdHex;
      _reviveArchiveOverrideThreadId = threadIdHex;
    });

    try {
      if (!isPro && !hasRevive) {
        final reviveTarget = targetUser == null
            ? null
            : PaywallReviveTarget(
                avatarUrl:
                    (targetUser.profilePhotoPath != null &&
                        targetUser.profilePhotoPath!.isNotEmpty)
                    ? targetUser.profilePhotoPath!
                    : targetUser.defaultAvatar,
                isDefaultAvatar:
                    targetUser.profilePhotoPath == null ||
                    targetUser.profilePhotoPath!.isEmpty,
                fullName: targetUser.fullName,
                username: targetUser.username ?? '',
              );
        final purchase = await _openPaywall(
          feature: PaywallFeature.revive,
          reviveTarget: reviveTarget,
        );
        if (purchase == null) return;
        final ok = await _verifyPurchaseAndApply(purchase);
        if (!ok) return;
      }

      await api.reviveThread(threadIdHex: threadIdHex);
      revived = true;
      ref.read(chaputThreadsControllerProvider(chaputArgs).notifier).refresh();
      if (_decisionProfileId != null) {
        ref
            .read(chaputDecisionControllerProvider(profileIdHex).notifier)
            .fetchDecision();
      }
      _showGlassToast(
        context.t('profile.toast.chaput_revived'),
        icon: Icons.check_circle_outline,
      );
      unawaited(HapticFeedback.mediumImpact());
    } catch (e) {
      _showGlassToast(
        context.t('profile.toast.chaput_revive_failed'),
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) {
        setState(() {
          _reviveFlowBusy = false;
          if (revived) {
            _reviveArchiveOverrideProfileId = null;
            _reviveArchiveOverrideThreadId = null;
          }
        });
      }
    }
  }

  void _onOptionsEmptyTap() {
    _showGlassToast(
      context.t('profile.toast.enter_message'),
      icon: Icons.edit_outlined,
    );
  }

  Future<void> _handleBindPressed({required String profileId}) async {
    if (_chaputThreadCreated || _composerOpen) return;
    HapticFeedback.selectionClick();
    if (profileId.length != 32) {
      _showGlassToast(
        context.t('profile.toast.profile_not_found'),
        icon: Icons.error_outline,
      );
      return;
    }
    if (_decisionProfileId == null) {
      _showGlassToast(
        context.t('profile.toast.chaput_rights_loading'),
        icon: Icons.hourglass_empty,
      );
      return;
    }
    if (!_decisionLoaded) {
      _showGlassToast(
        context.t('profile.toast.chaput_rights_loading'),
        icon: Icons.hourglass_empty,
      );
      return;
    }
    if (_decisionHasThread) {
      _showGlassToast(
        context.t('profile.toast.chaput_exists'),
        icon: Icons.chat_bubble_outline,
      );
      return;
    }

    if (!_decisionCanStart || _decisionPath == 'FORBIDDEN') {
      _showGlassToast(
        context.t('profile.toast.chaput_cannot_start'),
        icon: Icons.block,
      );
      return;
    }

    final isPro = _planType == 'PRO';
    final hasNormalCredit = _creditNormal > 0;

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
              .read(
                chaputDecisionControllerProvider(_decisionProfileId!).notifier,
              )
              .fetchDecision();
        }
        _prepareComposer();
      }
      return;
    }

    // Rewarded-ad continuation is intentionally disabled. A free user whose
    // daily entitlement is exhausted is offered the existing paywall above.
  }

  Future<PaywallPurchase?> _openPaywall({
    required PaywallFeature feature,
    PaywallReviveTarget? reviveTarget,
  }) async {
    final me = ref.read(meControllerProvider).value;
    final subPlan = me?.subscription.plan;
    final effectivePlanType = (_planType.isNotEmpty && _planType != 'FREE')
        ? _planType
        : (subPlan ?? _planType);
    final effectivePlanPeriod = _planPeriod;
    return _showTreePreservingOverlay<PaywallPurchase>(
      () => showModalBottomSheet<PaywallPurchase>(
        context: context,
        backgroundColor: AppColors.chaputTransparent,
        isScrollControlled: true,
        useSafeArea: false,
        builder: (_) => FakePaywallSheet(
          feature: feature,
          planType: effectivePlanType,
          planPeriod: effectivePlanPeriod,
          appUserId: me?.user.userId,
          reviveTarget: reviveTarget,
          onPurchaseProduct: _purchaseWithRevenueCat,
          onRestorePurchases: _restorePurchasesWithRevenueCat,
        ),
      ),
    );
  }

  Future<void> _openHiddenPaywall() async {
    final purchase = await _openPaywall(
      feature: PaywallFeature.hideCredentials,
    );
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
    if (!_isBlankDraft()) {
      _emitTyping(true);
    }
    // Eğer mesaj var ve daha önce anchor hatırlanmışsa, aynı anchor’a geri focus ol
    if (_draftAnchor != null) {
      _focusAnchor = _draftAnchor!.clone();
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
    _snapActive = false;

    _startCenterShift(toCenter: _treeCenter, toLookAt: _treeCenter);

    // composer açık kalsın, sadece unfocus edildi (UI aynı kalsın)
  }

  void _emitTyping(bool isTyping) {
    if (!_activeThreadIsParticipant) return;
    final threadId = _activeThreadId;
    if (threadId == null || threadId.isEmpty) return;
    _sendTyping(threadId, isTyping);
  }

  void _onComposerTextChanged() {
    final threadId = _activeThreadId;
    if (!_composerOpen ||
        !_activeThreadIsParticipant ||
        !_msgFocus.hasFocus ||
        threadId == null ||
        threadId.isEmpty) {
      return;
    }

    if (_msgCtrl.text.trim().isEmpty) {
      _typingIdleTimer?.cancel();
      _sendTyping(threadId, false);
      return;
    }

    _sendTyping(threadId, true);
    _typingIdleTimer?.cancel();
    _typingIdleTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      final activeThreadId = _activeThreadId;
      if (activeThreadId == null || activeThreadId.isEmpty) return;
      _sendTyping(activeThreadId, false);
    });
  }

  void _sendTyping(String threadId, bool isTyping) {
    if (threadId.isEmpty) return;
    if (isTyping) {
      if (_typingSent && _typingSentThreadId == threadId) return;
      _typingSent = true;
      _typingSentThreadId = threadId;
    } else {
      if (_typingSentThreadId == threadId) {
        _typingSent = false;
        _typingSentThreadId = null;
      }
    }
    ref.read(chaputSocketProvider).sendTyping(threadId, isTyping);
  }

  void _resetTypingForThreadChange(String? nextThreadId) {
    final prevThreadId = _typingSentThreadId;
    if (prevThreadId == null) return;
    if (nextThreadId == prevThreadId) return;
    _typingIdleTimer?.cancel();
    _sendTyping(prevThreadId, false);
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

  void _startTreeModeFast() {
    // kullanıcı dokununca hızlıca tree center’a geç
    _startCenterShift(toCenter: _treeCenter, toLookAt: _treeCenter);
  }

  void _updateCamera(three.ThreeJS js, double dt) {
    if (_isDisposed || !mounted) return;
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
        black.color = three_math.Color.fromHex32(
          AppColors.chaputBlack.toARGB32(),
        );

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
    if (_isDisposed || !mounted) return;
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
      _focusScreen.value = now;
    } else {
      _focusScreen.value = null;
    }
  }

  void _adjustCameraForComposer(three.ThreeJS js) {
    if (!_composerOpen) {
      _composerPitchBias = 0.0;
      return;
    }
    if (_focusAnchor == null) return;

    final mediaQuery = MediaQuery.of(context);
    final kb = mediaQuery.viewInsets.bottom;
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
    _composerPitchBias =
        _composerPitchBias + (desiredBias - _composerPitchBias) * 0.12;
  }

  double _lerpAngle(double a, double b, double t) {
    var d = (b - a);
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d < -math.pi) {
      d += 2 * math.pi;
    }
    return a + d * t;
  }

  void _startSnapBackTo({
    required double yaw,
    required double pitch,
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
      radius: _defaultRadius,
    );
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
    _pitch = (_snapFromPitch + (_snapToPitch - _snapFromPitch) * s).clamp(
      _minPitchHard,
      _maxPitch,
    );

    _orbitCenter = three.Vector3(
      _snapFromCenter.x + (_snapToCenter.x - _snapFromCenter.x) * s,
      _snapFromCenter.y + (_snapToCenter.y - _snapFromCenter.y) * s,
      _snapFromCenter.z + (_snapToCenter.z - _snapFromCenter.z) * s,
    );

    // focus'ta lookAt = center daha iyi hissettirir
    _lookAt = _orbitCenter.clone();

    _radius = (_snapFromRadius + (_snapToRadius - _snapFromRadius) * s).clamp(
      _minRadius,
      _maxRadius,
    );
  }

  void _onScaleStart(ScaleStartDetails d) {
    _isInteracting = true;
    _snapActive = false;

    _resetMarkerStabilizer();

    // Sadece "seçili nokta varsa" ve "gerçek drag başlarsa" yapacağız.
    _pendingTreeModeShift = (_focusAnchor != null);
    _treeModeShiftDoneThisGesture = false;

    _startRadius = _radius;

    if (_chaputSheetExtent > _chaputSheetMin + 0.01) {
      _chaputSheetPrevExtent = _chaputSheetExtent;
      _chaputSheetCtrl.animateTo(
        _chaputSheetMin,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    _isInteracting = false;
    _pendingTreeModeShift = false;
    _treeModeShiftDoneThisGesture = false;

    if (_focusAnchor == null) {
      return;
    }

    _snapViewToAnchor();

    if (_chaputSheetPrevExtent > _chaputSheetMin + 0.01) {
      _chaputSheetCtrl.animateTo(
        _chaputSheetPrevExtent.clamp(_chaputSheetMin, _chaputSheetMax),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    final dx = d.focalPointDelta.dx / (w == 0 ? 1 : w);
    final dy = d.focalPointDelta.dy / (h == 0 ? 1 : h);

    // Drag gerçekten başladı mı? (küçük eşik)
    final moved =
        (d.focalPointDelta.dx.abs() + d.focalPointDelta.dy.abs()) > 0.8;
    final scaled = (d.scale - 1.0).abs() > 0.002;

    if (_pendingTreeModeShift &&
        !_treeModeShiftDoneThisGesture &&
        (moved || scaled)) {
      _startTreeModeFast(); // artık tree center’a hızlı geç
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
    if (_forceTreeReload) {
      if (tid != null) {
        _forceTreeReload = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _createThreeIfNeeded(tid);
        });
      } else if (!st.isLoading) {
        ref.read(profileControllerProvider(widget.userId).notifier).refetch();
      }
    }

    final preset = (tid == null) ? null : TreeCatalog.resolve(tid);
    final bg = Color(preset?.bgColor ?? AppColors.chaputBlack.toARGB32());

    final showPageLoading = st.profileJson == null && st.isLoading;
    final showTreeLoading =
        !showPageLoading && tid != null && !_threeReady && _threeError == null;

    final user = (st.profileJson?['user'] is Map)
        ? (st.profileJson!['user'] as Map)
        : null;

    final userId = user?['id']?.toString() ?? '';
    if (userId.isNotEmpty && userId != _lastProfileUserId) {
      final previousProfileUserId = _lastProfileUserId;
      _lastProfileUserId = userId;
      if (previousProfileUserId != null &&
          previousProfileUserId != widget.userId) {
        _lastTreeId = null;
        _disposeThree();
        _clearEmptyChaputState();
      }
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

    bool asBool(dynamic v) => v == true || v == 1 || v == '1';

    int asNonNegativeInt(dynamic value) {
      final parsed = switch (value) {
        int value => value,
        num value => value.toInt(),
        _ => int.tryParse(value?.toString() ?? ''),
      };
      return (parsed ?? 0).clamp(0, 1 << 30).toInt();
    }

    final isPublic = asBool(user?['is_public']);
    final initialPreview = widget.initialProfilePreview;
    final avatarPreview = ProfilePreview(
      id: userId.isNotEmpty ? userId : widget.userId,
      username: username.isNotEmpty ? username : initialPreview?.username,
      fullName: fullName.isNotEmpty
          ? fullName
          : (initialPreview?.fullName ?? ''),
      defaultAvatar:
          _firstNonEmpty(
            defaultAvatar?.toString(),
            initialPreview?.defaultAvatar,
          ) ??
          '',
      profilePhotoKey: _firstNonEmpty(
        profilePhotoKey,
        initialPreview?.profilePhotoKey,
      ),
      profilePhotoUrl: _firstNonEmpty(
        profilePhotoUrl,
        initialPreview?.profilePhotoUrl,
      ),
      isPublic: user == null ? (initialPreview?.isPublic ?? false) : isPublic,
      requestPending: initialPreview?.requestPending ?? false,
    );
    final hasProfileAvatar = avatarPreview.avatarImageUrl.isNotEmpty;
    final isPrivateTarget = !isPublic;
    final privateChaputCount = asNonNegativeInt(
      st.profileJson?['chaput_count'],
    );

    final viewerState = (st.profileJson?['viewer_state'] is Map)
        ? (st.profileJson!['viewer_state'] as Map)
        : null;

    final isFollowing = viewerState?['is_following'] == true;
    final isMe = viewerState?['is_me'] == true;
    final isBlocked = viewerState?['is_blocked'] == true;
    final iRequestedFollow = viewerState?['i_requested_follow'] == true;

    final iRestrictedHim = viewerState?['i_restricted_him'] == true;
    final heRestrictedMe = viewerState?['he_restricted_me'] == true;

    final uiRestrictedOverride = ref.watch(
      uiRestrictedOverrideProvider(widget.userId),
    );
    final effectiveIRestrictedHim = uiRestrictedOverride ?? iRestrictedHim;

    final int effectiveFollowerCount = (followerCount + _uiFollowerDelta).clamp(
      0,
      1 << 30,
    );
    bool effectiveIsFollowing = _uiIsFollowing ?? isFollowing;
    bool effectiveRequestedFollow = _uiRequestedFollow ?? iRequestedFollow;

    final followState = ref.watch(followControllerProvider(username));

    if (followState is FollowIdle) {
      if (followState.isFollowing != null) {
        effectiveIsFollowing = followState.isFollowing!;
      }
      if (followState.requestPending != null) {
        effectiveRequestedFollow = followState.requestPending!;
      }
    }

    if (viewerState != null && userId.isNotEmpty) {
      _syncProfileFollowState(
        avatarPreview.copyWith(
          isFollowing: effectiveIsFollowing,
          requestPending: effectiveRequestedFollow,
        ),
        isMe: isMe,
      );
    }

    final me = meAsync.value;
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
        profileIdHex.length == 32 &&
        !isMe &&
        !(isPrivateTarget && !effectiveIsFollowing);

    final decisionState = decisionAllowed
        ? ref.watch(chaputDecisionControllerProvider(profileIdHex))
        : ChaputDecisionState.empty;

    final decision = decisionState.decision;

    final planType = decision?.plan.type ?? 'FREE';
    final planPeriod = decision?.plan.period;

    final creditsNormal = decision?.credits.normal ?? 0;
    final creditsHidden = decision?.credits.hidden ?? 0;
    final creditsSpecial = decision?.credits.special ?? 0;
    final creditsRevive = decision?.credits.revive ?? 0;
    final creditsWhisper = decision?.credits.whisper ?? 0;

    final decisionPath = decision?.decision.path ?? 'FORBIDDEN';
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
        ref
            .read(chaputDecisionControllerProvider(profileIdHex).notifier)
            .fetchDecision();
      });
    } else if (decision == null && !decisionState.isLoading) {
      final now = DateTime.now();
      if (_lastDecisionFetchAt == null ||
          now.difference(_lastDecisionFetchAt!) > const Duration(seconds: 2)) {
        _lastDecisionFetchAt = now;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(chaputDecisionControllerProvider(profileIdHex).notifier)
              .fetchDecision();
        });
      }
    }

    final responsive = context.responsive;
    final double topInset = responsive.padding.top;
    const double topBarHeight = 72;

    final bool showRequestMode =
        !isMe && isPrivateTarget && !effectiveIsFollowing;
    final bool showPrivateFollowSheet =
        showRequestMode && !showPageLoading && !_composerOpen;

    final bool silhouetteMode =
        !isMe && isPrivateTarget && !effectiveIsFollowing;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_silhouetteMode != silhouetteMode) {
        _silhouetteMode = silhouetteMode;
        _applySilhouetteIfNeeded();
      }
    });

    final bool requestAlreadySent = showRequestMode && effectiveRequestedFollow;

    final bool followButtonDisabled =
        _uiFollowLoading || isBlocked || requestAlreadySent;

    final bool isProPlan = _planType == 'PRO';
    final bool hasNormalCredit = _creditNormal > 0;
    final bool canStartNow = decisionPath == 'CAN_START';
    final bool rawDecisionHasArchived =
        decisionHasThread && decisionThreadState == 'ARCHIVED';
    final bool reviveArchiveOverrideActive =
        _reviveArchiveOverrideProfileId == profileIdHex &&
        (_reviveArchiveOverrideThreadId?.length == 32);
    final String reviveThreadId = rawDecisionHasArchived
        ? decisionThreadId
        : (reviveArchiveOverrideActive
              ? _reviveArchiveOverrideThreadId!
              : decisionThreadId);
    final bool decisionHasArchived =
        rawDecisionHasArchived || reviveArchiveOverrideActive;
    final bool showBindExhausted =
        decisionLoaded &&
        !decisionHasThread &&
        !canStartNow &&
        !isProPlan &&
        !hasNormalCredit;

    final bool chaputAllowed =
        profileIdHex.length == 32 &&
        (!isPrivateTarget || effectiveIsFollowing || isMe);
    final chaputArgs = ChaputThreadsArgs(
      profileId: profileIdHex,
      viewerId: viewerId,
      ownerId: userId,
      restricted: heRestrictedMe,
    );
    _lastChaputArgs = chaputArgs;

    final ChaputThreadsState chaputThreadsState =
        chaputAllowed && viewerId.isNotEmpty
        ? ref.watch(chaputThreadsControllerProvider(chaputArgs))
        : ChaputThreadsState.empty;

    final chaputThreads = _stableSessionThreads(
      profileIdHex: profileIdHex,
      source: chaputThreadsState.items,
    );
    final bool showEmptyChaputSheet =
        chaputAllowed &&
        chaputThreads.isEmpty &&
        !showPageLoading &&
        !_composerOpen &&
        !_silhouetteMode;
    final bool showBottomInfoSheet =
        showEmptyChaputSheet || showPrivateFollowSheet;

    final String? emptyChaputMessage = showEmptyChaputSheet
        ? context.t(
            (isMe
                ? _emptyChaputMessageKeysSelf
                : _emptyChaputMessageKeysOther)[_resolveEmptyChaputIndex(
              userId,
              isMe,
            )],
          )
        : null;
    String compactChaputCount(int value) {
      if (value < 1000) return value.toString();
      final scaled = value / 1000;
      final text = scaled >= 10
          ? scaled.toStringAsFixed(0)
          : scaled.toStringAsFixed(1);
      return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}K';
    }

    final InlineSpan? privateFollowMessage = showPrivateFollowSheet
        ? TextSpan(
            children: [
              TextSpan(
                text: context.t(
                  privateChaputCount > 0
                      ? 'profile.private_follow_required_prefix'
                      : 'profile.private_follow_required_zero_prefix',
                ),
              ),
              if (privateChaputCount > 0) ...[
                TextSpan(
                  text: context.t(
                    'profile.private_follow_required_view_count',
                    params: {'count': compactChaputCount(privateChaputCount)},
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(
                  text: context.t('profile.private_follow_required_middle'),
                ),
              ],
              TextSpan(
                text: context.t('profile.private_follow_required_bind'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(
                text: context.t('profile.private_follow_required_suffix'),
              ),
            ],
          )
        : null;

    if (showEmptyChaputSheet || showPrivateFollowSheet) {
      _ensureEmptyChaputFocus(
        profileId: userId,
        isMe: isMe,
        profilePhotoKey: profilePhotoKey,
        profilePhotoUrl: profilePhotoUrl,
      );
      _scheduleEmptyChaputAnchorPick();
    } else if (chaputThreads.isNotEmpty) {
      _clearEmptyChaputState();
    }
    if (!_initialThreadApplied &&
        _pendingInitialThreadId != null &&
        chaputThreads.isNotEmpty) {
      final idx = chaputThreads.indexWhere(
        (t) => t.matchesShareRef(_pendingInitialThreadId!),
      );
      if (idx >= 0) {
        _initialThreadApplied = true;
        final targetThreadId = _pendingInitialThreadId;
        final targetMessageId = _pendingInitialMessageId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_chaputPageCtrl.hasClients) {
            final pageIdx = _pageIndexForThreadIndex(idx);
            _syncChaputFeedbackBasePage(pageIdx);
            _chaputPageCtrl.jumpToPage(pageIdx);
          } else {
            setState(() => _chaputActiveIndex = idx);
          }
          _focusToThreadAnchor(chaputThreads[idx], profileIdHex);
          if (targetMessageId != null && targetMessageId.isNotEmpty) {
            _openInitialThreadSheet();
            Future.delayed(const Duration(seconds: 20), () {
              if (!mounted) return;
              if (_pendingInitialThreadId == targetThreadId &&
                  _pendingInitialMessageId == targetMessageId) {
                setState(() {
                  _pendingInitialThreadId = null;
                  _pendingInitialMessageId = null;
                });
              }
            });
          } else {
            _openInitialThreadSheet();
            Future.delayed(const Duration(milliseconds: 1200), () {
              if (!mounted) return;
              if (_pendingInitialThreadId == targetThreadId &&
                  _pendingInitialMessageId == targetMessageId) {
                _pendingInitialThreadId = null;
                _pendingInitialMessageId = null;
              }
            });
          }
        });
      }
    }
    final String? preservedActiveThreadId = _activeThreadId;
    int resolvedActiveThreadIndex = _chaputActiveIndex;
    if (chaputThreads.isNotEmpty &&
        preservedActiveThreadId != null &&
        preservedActiveThreadId.isNotEmpty) {
      final preservedIndex = chaputThreads.indexWhere(
        (t) => t.threadId == preservedActiveThreadId,
      );
      if (preservedIndex >= 0) {
        resolvedActiveThreadIndex = preservedIndex;
        if (preservedIndex != _chaputActiveIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_chaputActiveIndex != preservedIndex) {
              setState(() => _chaputActiveIndex = preservedIndex);
            }
            if (_chaputPageCtrl.hasClients) {
              final pageIdx = _pageIndexForThreadIndex(preservedIndex);
              _syncChaputFeedbackBasePage(pageIdx);
              _chaputPageCtrl.jumpToPage(pageIdx);
            }
          });
        }
      } else if (resolvedActiveThreadIndex >= chaputThreads.length) {
        resolvedActiveThreadIndex = 0;
      }
    }

    final bool hasOurThread = chaputThreads.any(
      (t) =>
          (t.userAId == userId && t.userBId == viewerId) ||
          (t.userAId == viewerId && t.userBId == userId),
    );
    final ChaputThreadItem? activeThread =
        chaputThreads.isNotEmpty &&
            resolvedActiveThreadIndex < chaputThreads.length
        ? chaputThreads[resolvedActiveThreadIndex]
        : null;
    final bool activeIsParticipant =
        activeThread != null &&
        (activeThread.userAId == viewerId || activeThread.userBId == viewerId);
    final bool activeViewerIsStarter =
        activeThread != null && activeThread.starterId == viewerId;
    final bool activeIsPending =
        activeThread != null && activeThread.state == 'PENDING';
    final bool canReplyOnActive =
        activeIsParticipant && (!activeIsPending || !activeViewerIsStarter);
    final bool showProfileComposer = shouldShowProfileComposer(
      composerOpen: _composerOpen,
      silhouetteMode: _silhouetteMode,
      chaputAllowed: chaputAllowed,
      isMe: isMe,
      chaputThreadCount: chaputThreads.length,
    );
    _resetTypingForThreadChange(activeThread?.threadId);
    _activeThreadId = activeThread?.threadId;
    _activeThreadIsParticipant = activeIsParticipant;
    _syncTypingSound();

    if (_composerOpen && !showProfileComposer) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_composerOpen) _closeComposer();
      });
    }

    if (chaputAllowed &&
        activeThread != null &&
        activeThread.threadId.isNotEmpty) {
      if (_socketThreadId != activeThread.threadId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_socketThreadId == activeThread.threadId) return;
          _subscribeThreadSocket(activeThread.threadId, profileIdHex);
        });
      }
    }
    final ChaputMessage? replyTarget =
        (_replyTarget != null && _replyTargetThreadId == activeThread?.threadId)
        ? _replyTarget
        : null;
    final String? replyAuthor = replyTarget == null
        ? null
        : (replyTarget.senderId == viewerId
              ? context.t('chat_you')
              : (chaputThreadsState.usersById[replyTarget.senderId]?.fullName ??
                    ''));
    final String? replyBody = replyTarget?.body;
    if (_chaputProfileId != profileIdHex) {
      _chaputProfileId = profileIdHex;
      _clearSocketSubscriptions();
      if (chaputAllowed) {
        _ensureSocket(profileIdHex);
      }
      _chaputActiveIndex = 0;
      _focusedThreadId = null;
      _setChaputSheetExtent(_chaputSheetMin);
      _chaputSheetPrevExtent = _chaputSheetMin;
      _pendingThreadFocus = null;
      _pendingThreadProfileId = null;
      _replyWhisperMode = false;
      _replyTarget = null;
      _replyTargetThreadId = null;
      _focusAnchor = null;
      _snapActive = false;
      _silhouetteApplied = false;
      _applySilhouetteIfNeeded();
      if (_chaputPageCtrl.hasClients) {
        _syncChaputFeedbackBasePage(0);
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
          ref
              .read(chaputApiProvider)
              .markThreadRead(threadIdHex: t.threadId)
              .catchError((_) {});
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _focusToThreadAnchor(t, profileIdHex);
        });
      }
    }

    return ShowCaseWidget(
      onComplete: _handleProfileShowcaseComplete,
      onDismiss: _handleProfileShowcaseDismiss,
      builder: (_) {
        final mediaQuery = MediaQuery.of(context);
        final chaputSheetOuterOffset = context.responsive
            .bottomSheetOuterOffset();
        final chaputSheetAvailableHeight =
            mediaQuery.size.height - chaputSheetOuterOffset;
        final androidSystemBottomFillHeight = responsive.isAndroid
            ? (responsive.keyboardOpen
                  ? mediaQuery.viewInsets.bottom
                  : mediaQuery.viewPadding.bottom)
            : 0.0;

        final threadSheetVisible =
            chaputThreads.isNotEmpty &&
            !showProfileComposer &&
            !_silhouetteMode &&
            !_isInteracting;
        _syncProfileTutorialState(
          viewerId: viewerId,
          profileId: userId,
          profileReady:
              viewerId.isNotEmpty && userId.isNotEmpty && !showPageLoading,
          isMe: isMe,
          chaputAllowed: chaputAllowed,
          threadSheetVisible: threadSheetVisible,
          threadCount: chaputThreads.length,
          activeThreadId: activeThread?.threadId,
        );

        final Widget? threadSheetChild =
            chaputThreads.isNotEmpty && !showProfileComposer && !_silhouetteMode
            ? RepaintBoundary(
                child: ValueListenableBuilder<int>(
                  valueListenable: _typingRevision,
                  builder: (_, _, _) {
                    final typingUsersByThread = _resolveTypingUsersByThread(
                      chaputThreadsState.usersById,
                      viewerId,
                    );
                    return ChaputThreadSheet(
                      threads: chaputThreads,
                      usersById: chaputThreadsState.usersById,
                      typingUsersByThread: typingUsersByThread,
                      viewerUser: viewerLite,
                      viewerId: viewerId,
                      ownerId: userId,
                      profileId: profileIdHex,
                      profileUsername: username,
                      initialThreadId: _pendingInitialThreadId,
                      initialMessageId: _pendingInitialMessageId,
                      pageController: _chaputPageCtrl,
                      sheetController: _chaputSheetCtrl,
                      initialExtent: _chaputSheetExtent,
                      isCollapsed:
                          _chaputSheetExtent <=
                          _chaputSheetMin + _chaputSheetCollapsedTapTolerance,
                      onCollapsedTap: _openCollapsedChaputSheet,
                      onExtentChanged: (v) {
                        final previousExtent = _chaputSheetExtent;
                        final wasReplyBarVisible = _shouldShowReplyBar(
                          extent: previousExtent,
                          canReplyOnActive: canReplyOnActive,
                          activeThreadId: activeThread?.threadId,
                        );
                        final wasCollapsed =
                            previousExtent <=
                            _chaputSheetMin + _chaputSheetCollapsedTapTolerance;
                        _setChaputSheetExtent(v);
                        if (v > _chaputSheetMin + 0.01) {
                          _chaputSheetPrevExtent = v;
                        }
                        if (v <= _chaputSheetMid + 0.001 &&
                            context.responsive.keyboardOpen) {
                          FocusScope.of(context).unfocus();
                        }
                        final isReplyBarVisible = _shouldShowReplyBar(
                          extent: _chaputSheetExtent,
                          canReplyOnActive: canReplyOnActive,
                          activeThreadId: activeThread?.threadId,
                        );
                        final isCollapsed =
                            _chaputSheetExtent <=
                            _chaputSheetMin + _chaputSheetCollapsedTapTolerance;
                        if ((wasReplyBarVisible != isReplyBarVisible ||
                                wasCollapsed != isCollapsed) &&
                            mounted) {
                          setState(() {});
                        }
                      },
                      onPageChanged: (pageIndex, thread) async {
                        _syncChaputFeedbackBasePage(pageIndex);
                        final threadIndex = _threadIndexForPageIndex(pageIndex);
                        if (threadIndex < chaputThreads.length) {
                          setState(() => _chaputActiveIndex = threadIndex);
                        } else {
                          setState(() {
                            _replyTarget = null;
                            _replyTargetThreadId = null;
                          });
                        }
                        if (threadIndex < chaputThreads.length) {
                          final t = chaputThreads[threadIndex];
                          _subscribeThreadSocket(t.threadId, profileIdHex);
                          _focusToThreadAnchor(t, profileIdHex);
                          final isParticipant =
                              t.userAId == viewerId || t.userBId == viewerId;
                          _activeThreadId = t.threadId;
                          _activeThreadIsParticipant = isParticipant;
                          _syncTypingSound();
                          if (isParticipant) {
                            ref
                                .read(chaputApiProvider)
                                .markThreadRead(threadIdHex: t.threadId)
                                .catchError((_) {});
                          }
                        } else {
                          _activeThreadId = null;
                          _activeThreadIsParticipant = false;
                          _syncTypingSound();
                        }
                      },
                      onOpenProfile: (uid, tid) {
                        _openThreadCounterpartyProfile(
                          userId: uid,
                          threadId: tid,
                        );
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
                      onArchiveThread: (thread) async {
                        await _archiveThread(
                          thread: thread,
                          profileIdHex: profileIdHex,
                          chaputArgs: chaputArgs,
                        );
                      },
                      onReportThread: _reportThread,
                      onReportMessage: (_, message) => _reportMessage(message),
                      canMakeHidden: creditsHidden > 0,
                      onOpenWhisperPaywall: () async {
                        await ref
                            .read(
                              chaputDecisionControllerProvider(
                                profileIdHex,
                              ).notifier,
                            )
                            .fetchDecision();

                        final freshWhisper =
                            ref
                                .read(
                                  chaputDecisionControllerProvider(
                                    profileIdHex,
                                  ),
                                )
                                .decision
                                ?.credits
                                .whisper ??
                            0;

                        if (freshWhisper > 0) return;

                        final purchase = await _openPaywall(
                          feature: PaywallFeature.whisper,
                        );
                        if (purchase == null) return;
                        await _verifyPurchaseAndApply(purchase);
                      },
                      replyOverlay:
                          _shouldShowReplyBar(
                            extent: _chaputSheetExtent,
                            canReplyOnActive: canReplyOnActive,
                            activeThreadId: activeThread?.threadId,
                          )
                          ? 88.0
                          : 0.0,
                      whisperCredits: creditsWhisper,
                      onReplyMessage: _handleReplyRequested,
                      onReplyJumpStarted: _suppressNextChaputSwipeSound,
                      onInitialMessageRevealed: _handleInitialMessageRevealed,
                      onPageUserScrollChanged: _setChaputUserSwipeInProgress,
                      sheetShowcaseKey: _chaputSheetShowcaseKey,
                      swipeShowcaseKey: _chaputThreadSwipeShowcaseKey,
                      activeThreadId: activeThread?.threadId,
                      onSheetTutorialTap: () {
                        _completeProfileTutorialFromCard(
                          _ProfileTutorialStep.chaputPull,
                        );
                      },
                      onSwipeTutorialTap: () {
                        _completeProfileTutorialFromCard(
                          _ProfileTutorialStep.chaputSwipe,
                        );
                      },
                      onActionSheetVisibilityChanged:
                          _setTreePreservingOverlayVisible,
                    );
                  },
                ),
              )
            : null;

        return PopScope(
          canPop: !responsive.isAndroid,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (!responsive.isAndroid) return;
            final router = GoRouter.of(context);
            if (router.canPop()) {
              router.pop();
            } else {
              router.go(Routes.home);
            }
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              systemNavigationBarColor: AppColors.chaputBlack,
              systemNavigationBarDividerColor: AppColors.chaputBlack,
              systemNavigationBarIconBrightness: Brightness.light,
            ),
            child: Scaffold(
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
                          : KeyedSubtree(
                              key: ValueKey(
                                'profile-tree-$_threeSurfaceGeneration-${_lastTreeId ?? ''}',
                              ),
                              child: RepaintBoundary(
                                child: SizedBox.expand(
                                  child: _threeJs!.build(),
                                ),
                              ),
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

                    if (showPageLoading)
                      Positioned.fill(
                        child: AbsorbPointer(
                          child: ColoredBox(
                            color: bg,
                            child: Center(
                              child: TreeSilhouetteShimmer(
                                size: math.min(
                                  MediaQuery.of(context).size.width * 0.6,
                                  240,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (showTreeLoading)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: TreeSilhouetteShimmer(
                              size: math.min(
                                MediaQuery.of(context).size.width * 0.5,
                                200,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // TOP BAR (overlay – yer kaplamaz)
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Back button (aynı)
                            IgnorePointer(
                              ignoring:
                                  _profileCardOpen, // kart açıkken tıklanmasın
                              child: ClipOval(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 10,
                                    sigmaY: 10,
                                  ),
                                  child: Material(
                                    color: AppColors.chaputWhite.withValues(
                                      alpha: 0.35,
                                    ),
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        GoRouter.of(context).go(Routes.home);
                                      },
                                      customBorder: const CircleBorder(),
                                      child: const SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: Center(
                                          child: Icon(
                                            Icons.chevron_left,
                                            size: 30,
                                            color: AppColors.chaputBlack,
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
                      ),
                    ),

                    // SMALL AVATAR (sağ üst)
                    Positioned(
                      top: topInset + 10,
                      right: 14,
                      child: IgnorePointer(
                        ignoring: _profileCardOpen || showPageLoading,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: _profileCardOpen
                              ? 0.0
                              : 1.0, // kart açılınca kaybol
                          child: ClipOval(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Showcase.withWidget(
                                key: _profileMenuShowcaseKey,
                                targetPadding: const EdgeInsets.all(6),
                                targetShapeBorder: const CircleBorder(),
                                tooltipPosition: TooltipPosition.bottom,
                                toolTipMargin: 16,
                                targetTooltipGap: 12,
                                container: ChaputTutorialCard(
                                  title: context.t(
                                    'showcase.profile_menu_open_title',
                                  ),
                                  body: context.t(
                                    'showcase.profile_menu_open_body',
                                  ),
                                  onTap: () {
                                    _completeProfileTutorialFromCard(
                                      _ProfileTutorialStep.menuOpen,
                                    );
                                  },
                                ),
                                child: Material(
                                  color: AppColors.chaputWhite.withValues(
                                    alpha: 0.35,
                                  ),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: _toggleProfileCard,
                                    customBorder: const CircleBorder(),
                                    child: SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: Center(
                                        child: ClipOval(
                                          child: hasProfileAvatar
                                              ? ProfileAvatarHero(
                                                  preview: avatarPreview,
                                                  width: 40,
                                                  height: 40,
                                                  borderWidth: 4,
                                                  bgColor:
                                                      AppColors.chaputWhite,
                                                )
                                              : const ColoredBox(
                                                  color: AppColors
                                                      .chaputTransparent,
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
                          builder: (_, _) {
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
                                            filter: ImageFilter.blur(
                                              sigmaX: 12,
                                              sigmaY: 12,
                                            ),
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: AppColors.chaputWhite
                                                    .withValues(alpha: 0.35),
                                                border: Border.all(
                                                  color: AppColors.chaputWhite
                                                      .withValues(alpha: 0.25),
                                                  width: 1,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // ✅ İÇERİK: senin mevcut içerik aynen
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Showcase.withWidget(
                                              key: _profileCloseShowcaseKey,
                                              targetPadding:
                                                  const EdgeInsets.all(6),
                                              targetShapeBorder:
                                                  const CircleBorder(),
                                              tooltipPosition:
                                                  TooltipPosition.bottom,
                                              toolTipMargin: 16,
                                              targetTooltipGap: 12,
                                              container: ChaputTutorialCard(
                                                title: context.t(
                                                  'showcase.profile_menu_close_title',
                                                ),
                                                body: context.t(
                                                  'showcase.profile_menu_close_body',
                                                ),
                                                onTap: () {
                                                  _completeProfileTutorialFromCard(
                                                    _ProfileTutorialStep
                                                        .menuClose,
                                                  );
                                                },
                                              ),
                                              child: InkWell(
                                                onTap: _toggleProfileCard,
                                                customBorder:
                                                    const CircleBorder(),
                                                child: SizedBox(
                                                  width: 44,
                                                  height: 44,
                                                  child: ClipOval(
                                                    child:
                                                        (defaultAvatar != null)
                                                        ? ChaputCircleAvatar(
                                                            isDefaultAvatar:
                                                                profilePhotoKey ==
                                                                    null ||
                                                                profilePhotoKey ==
                                                                    "",
                                                            imageUrl:
                                                                profilePhotoUrl !=
                                                                        null &&
                                                                    profilePhotoUrl !=
                                                                        ""
                                                                ? profilePhotoUrl
                                                                : defaultAvatar,
                                                          )
                                                        : const ColoredBox(
                                                            color: AppColors
                                                                .chaputTransparent,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 10),

                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              fullName,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: const TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                            Text(
                                                              '@$username',
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              softWrap: false,
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                color: AppColors
                                                                    .chaputBlack
                                                                    .withValues(
                                                                      alpha:
                                                                          0.65,
                                                                    ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 6,
                                                            ),
                                                            Wrap(
                                                              spacing: 8,
                                                              runSpacing: 6,
                                                              children: [
                                                                ProfileStatChip(
                                                                  value:
                                                                      effectiveFollowerCount,
                                                                  label: context.t(
                                                                    'profile.followers_label',
                                                                  ),
                                                                  onTap: () {
                                                                    if (heRestrictedMe ||
                                                                        (isPrivateTarget &&
                                                                            !effectiveIsFollowing &&
                                                                            !isMe)) {
                                                                      ScaffoldMessenger.of(
                                                                        context,
                                                                      ).showSnackBar(
                                                                        SnackBar(
                                                                          content: Text(
                                                                            context.t(
                                                                              'profile.follow_list_forbidden',
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      );
                                                                      return;
                                                                    }
                                                                    _openFollowListPreservingTree(
                                                                      username:
                                                                          username,
                                                                      kind: FollowListKind
                                                                          .followers,
                                                                      isMe:
                                                                          isMe,
                                                                      title: context.t(
                                                                        'profile.followers_title',
                                                                      ),
                                                                    );
                                                                  },
                                                                ),
                                                                ProfileStatChip(
                                                                  value:
                                                                      followingCount,
                                                                  label: context.t(
                                                                    'profile.following_label',
                                                                  ),
                                                                  onTap: () {
                                                                    if (heRestrictedMe ||
                                                                        (isPrivateTarget &&
                                                                            !effectiveIsFollowing &&
                                                                            !isMe)) {
                                                                      ScaffoldMessenger.of(
                                                                        context,
                                                                      ).showSnackBar(
                                                                        SnackBar(
                                                                          content: Text(
                                                                            context.t(
                                                                              'profile.follow_list_forbidden',
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      );
                                                                      return;
                                                                    }
                                                                    _openFollowListPreservingTree(
                                                                      username:
                                                                          username,
                                                                      kind: FollowListKind
                                                                          .following,
                                                                      isMe:
                                                                          isMe,
                                                                      title: context.t(
                                                                        'profile.following_title',
                                                                      ),
                                                                    );
                                                                  },
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),

                                                      // ================= ACTION BUTTON =================
                                                      if (isMe)
                                                        Showcase.withWidget(
                                                          key:
                                                              _settingsShowcaseKey,
                                                          targetPadding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 6,
                                                                vertical: 4,
                                                              ),
                                                          targetShapeBorder:
                                                              RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                              ),
                                                          tooltipPosition:
                                                              TooltipPosition
                                                                  .top,
                                                          toolTipMargin: 16,
                                                          targetTooltipGap: 12,
                                                          container: ChaputTutorialCard(
                                                            title: context.t(
                                                              'showcase.profile_settings_title',
                                                            ),
                                                            body: context.t(
                                                              'showcase.profile_settings_body',
                                                            ),
                                                            onTap: () {
                                                              _completeProfileTutorialFromCard(
                                                                _ProfileTutorialStep
                                                                    .settings,
                                                              );
                                                            },
                                                          ),
                                                          child: TextButton(
                                                            onPressed:
                                                                _openSettingsPreservingTree,
                                                            style: TextButton.styleFrom(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical: 6,
                                                                  ),
                                                              backgroundColor:
                                                                  AppColors
                                                                      .chaputBlack,
                                                              foregroundColor:
                                                                  AppColors
                                                                      .chaputWhite,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              context.t(
                                                                'profile.settings',
                                                              ),
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                  ),
                                                            ),
                                                          ),
                                                        )
                                                      else
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            // FOLLOW / UNFOLLOW
                                                            TextButton(
                                                              onPressed:
                                                                  followButtonDisabled
                                                                  ? null
                                                                  : () async {
                                                                      if (isBlocked) {
                                                                        return;
                                                                      }
                                                                      HapticFeedback.selectionClick();

                                                                      setState(
                                                                        () => _uiFollowLoading =
                                                                            true,
                                                                      );

                                                                      // PRIVATE + not following: follow -> request gönderme modu
                                                                      if (showRequestMode) {
                                                                        // optimistic: anında "İstek Gönderildi"
                                                                        setState(
                                                                          () => _uiRequestedFollow =
                                                                              true,
                                                                        );

                                                                        try {
                                                                          final ctrl = ref.read(
                                                                            followControllerProvider(
                                                                              username,
                                                                            ).notifier,
                                                                          );

                                                                          // follow() backend'de private ise follow_request oluşturmalı (senin sistemde genelde böyle)
                                                                          await ctrl
                                                                              .follow();
                                                                          unawaited(
                                                                            ChaputSoundService.instance.play(
                                                                              ChaputSoundEffect.refreshRecommendedUser,
                                                                            ),
                                                                          );
                                                                        } catch (
                                                                          error
                                                                        ) {
                                                                          // rollback
                                                                          setState(
                                                                            () =>
                                                                                _uiRequestedFollow = null,
                                                                          );
                                                                          _handleFollowActionError(
                                                                            error,
                                                                          );
                                                                        } finally {
                                                                          setState(
                                                                            () =>
                                                                                _uiFollowLoading = false,
                                                                          );
                                                                        }
                                                                        return;
                                                                      }

                                                                      // PUBLIC veya zaten following/unfollow normal akış
                                                                      setState(() {
                                                                        if (effectiveIsFollowing) {
                                                                          _uiIsFollowing =
                                                                              false;
                                                                          _uiFollowerDelta -=
                                                                              1;
                                                                        } else {
                                                                          _uiIsFollowing =
                                                                              true;
                                                                          _uiFollowerDelta +=
                                                                              1;
                                                                        }
                                                                      });

                                                                      try {
                                                                        final ctrl = ref.read(
                                                                          followControllerProvider(
                                                                            username,
                                                                          ).notifier,
                                                                        );
                                                                        if (effectiveIsFollowing) {
                                                                          await ctrl
                                                                              .unfollow();
                                                                        } else {
                                                                          await ctrl
                                                                              .follow();
                                                                        }
                                                                      } catch (
                                                                        _
                                                                      ) {
                                                                        setState(() {
                                                                          _uiIsFollowing =
                                                                              null;
                                                                          _uiFollowerDelta =
                                                                              0;
                                                                        });
                                                                      } finally {
                                                                        setState(
                                                                          () => _uiFollowLoading =
                                                                              false,
                                                                        );
                                                                      }
                                                                    },

                                                              style: TextButton.styleFrom(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          12,
                                                                      vertical:
                                                                          6,
                                                                    ),
                                                                backgroundColor:
                                                                    isBlocked
                                                                    ? AppColors
                                                                          .chaputRed200
                                                                    : requestAlreadySent
                                                                    ? AppColors
                                                                          .chaputMaterialBlue
                                                                    : effectiveIsFollowing
                                                                    ? AppColors
                                                                          .chaputGrey300
                                                                    : AppColors
                                                                          .chaputBlack,
                                                                foregroundColor:
                                                                    requestAlreadySent
                                                                    ? AppColors
                                                                          .chaputWhite
                                                                    : (effectiveIsFollowing
                                                                          ? AppColors.chaputBlack
                                                                          : AppColors.chaputWhite),

                                                                // disabled iken de beyaz kalsın
                                                                disabledForegroundColor:
                                                                    requestAlreadySent
                                                                    ? AppColors
                                                                          .chaputWhite
                                                                    : AppColors
                                                                          .chaputWhite70,

                                                                // disabled iken arka plan da mavi kalsın
                                                                disabledBackgroundColor:
                                                                    requestAlreadySent
                                                                    ? AppColors
                                                                          .chaputMaterialBlue
                                                                    : AppColors
                                                                          .chaputGrey300,

                                                                shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                ),
                                                              ),
                                                              child:
                                                                  _uiFollowLoading
                                                                  ? const SizedBox(
                                                                      width: 14,
                                                                      height:
                                                                          14,
                                                                      child: CircularProgressIndicator(
                                                                        strokeWidth:
                                                                            2,
                                                                      ),
                                                                    )
                                                                  : Text(
                                                                      requestAlreadySent
                                                                          ? context.t(
                                                                              'profile.follow_request_sent',
                                                                            )
                                                                          : (effectiveIsFollowing
                                                                                ? context.t(
                                                                                    'profile.unfollow',
                                                                                  )
                                                                                : context.t(
                                                                                    'profile.follow',
                                                                                  )),
                                                                      style: const TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                      ),
                                                                    ),
                                                            ),

                                                            const SizedBox(
                                                              width: 6,
                                                            ),

                                                            // THREE DOT MENU
                                                            ProfileActionsButton(
                                                              username:
                                                                  username,
                                                              userId: userId,
                                                              iRestrictedHim:
                                                                  effectiveIRestrictedHim,
                                                              onSheetVisibilityChanged:
                                                                  _setTreePreservingOverlayVisible,
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
                          builder: (_, off, _) {
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
                                          color: AppColors.chaputWhite
                                              .withValues(alpha: 0.6),
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

                    if (androidSystemBottomFillHeight > 0 &&
                        (threadSheetChild != null || showBottomInfoSheet))
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: -1,
                        height: androidSystemBottomFillHeight + 2,
                        child: const ColoredBox(color: AppColors.chaputBlack),
                      ),

                    if (threadSheetChild != null)
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: chaputSheetOuterOffset,
                            ),
                            child: IgnorePointer(
                              ignoring: _isInteracting,
                              child: AnimatedSlide(
                                duration: const Duration(milliseconds: 140),
                                curve: Curves.easeOutCubic,
                                offset: _isInteracting
                                    ? const Offset(0, 1.08)
                                    : Offset.zero,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 100),
                                  curve: Curves.easeOut,
                                  opacity: _isInteracting ? 0 : 1,
                                  child: threadSheetChild,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (showBottomInfoSheet &&
                        (emptyChaputMessage != null ||
                            privateFollowMessage != null))
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: chaputSheetOuterOffset,
                            ),
                            child: SizedBox(
                              height:
                                  (chaputSheetAvailableHeight *
                                      _chaputSheetMin) +
                                  context.responsive.bottomSheetInnerPadding(
                                    min: 0,
                                  ),
                              child: EmptyChaputSheet(
                                message: emptyChaputMessage ?? '',
                                messageSpan: privateFollowMessage,
                                height:
                                    (chaputSheetAvailableHeight *
                                        _chaputSheetMin) +
                                    context.responsive.bottomSheetInnerPadding(
                                      min: 0,
                                    ),
                                actionLabel: null,
                              ),
                            ),
                          ),
                        ),
                      ),

                    ValueListenableBuilder<double>(
                      valueListenable: _chaputSheetExtentListenable,
                      builder: (context, chaputSheetExtent, _) {
                        final showReplyBar = _shouldShowReplyBar(
                          extent: chaputSheetExtent,
                          canReplyOnActive: canReplyOnActive,
                          activeThreadId: activeThread?.threadId,
                        );
                        if (!showReplyBar) {
                          return const SizedBox.shrink();
                        }
                        return Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: AnimatedPadding(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOut,
                            padding: context.responsive.bottomFixedPadding(),
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
                              onTypingChanged: (isTyping) {
                                if (!mounted) return;
                                final threadId = activeThread?.threadId;
                                if (threadId == null || threadId.isEmpty) {
                                  return;
                                }
                                _sendTyping(threadId, isTyping);
                              },

                              onToggleWhisper: () async {
                                if (_replyWhisperMode) {
                                  setState(() => _replyWhisperMode = false);
                                  return;
                                }

                                final notifier = ref.read(
                                  chaputDecisionControllerProvider(
                                    profileIdHex,
                                  ).notifier,
                                );
                                ChaputDecision? freshDecision;
                                final api = ref.read(chaputApiProvider);
                                try {
                                  freshDecision = await api.getDecision(
                                    profileIdHex,
                                  );
                                  notifier.setCredits(
                                    normal: freshDecision.credits.normal,
                                    hidden: freshDecision.credits.hidden,
                                    special: freshDecision.credits.special,
                                    revive: freshDecision.credits.revive,
                                    whisper: freshDecision.credits.whisper,
                                  );
                                  notifier.applyPlanType(
                                    freshDecision.plan.type,
                                  );
                                  if (freshDecision.plan.period != null &&
                                      freshDecision.plan.period!.isNotEmpty) {
                                    notifier.applyPlanPeriod(
                                      freshDecision.plan.period!,
                                    );
                                  }
                                } catch (_) {
                                  freshDecision = await notifier
                                      .fetchDecisionAndReturn();
                                }
                                final freshWhisper =
                                    freshDecision?.credits.whisper ?? 0;

                                if (freshWhisper > 0) {
                                  setState(() => _replyWhisperMode = true);
                                  return;
                                }

                                final purchase = await _openPaywall(
                                  feature: PaywallFeature.whisper,
                                );
                                if (purchase == null) return;

                                final ok = await _verifyPurchaseAndApply(
                                  purchase,
                                );
                                if (!ok) return;

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
                                  if (after.plan.period != null &&
                                      after.plan.period!.isNotEmpty) {
                                    notifier.applyPlanPeriod(
                                      after.plan.period!,
                                    );
                                  }
                                } catch (_) {
                                  after = await notifier
                                      .fetchDecisionAndReturn();
                                }
                                final afterWhisper =
                                    after?.credits.whisper ?? 0;

                                if (afterWhisper > 0) {
                                  setState(() => _replyWhisperMode = true);
                                } else {
                                  _showGlassToast(
                                    context.t(
                                      'profile.toast.whisper_unavailable',
                                    ),
                                    icon: Icons.error_outline,
                                  );
                                }
                              },

                              onWhisperPaywall: () async {
                                final notifier = ref.read(
                                  chaputDecisionControllerProvider(
                                    profileIdHex,
                                  ).notifier,
                                );
                                ChaputDecision? freshDecision;
                                final api = ref.read(chaputApiProvider);
                                try {
                                  freshDecision = await api.getDecision(
                                    profileIdHex,
                                  );
                                  notifier.setCredits(
                                    normal: freshDecision.credits.normal,
                                    hidden: freshDecision.credits.hidden,
                                    special: freshDecision.credits.special,
                                    revive: freshDecision.credits.revive,
                                    whisper: freshDecision.credits.whisper,
                                  );
                                  notifier.applyPlanType(
                                    freshDecision.plan.type,
                                  );
                                  if (freshDecision.plan.period != null &&
                                      freshDecision.plan.period!.isNotEmpty) {
                                    notifier.applyPlanPeriod(
                                      freshDecision.plan.period!,
                                    );
                                  }
                                } catch (_) {
                                  freshDecision = await notifier
                                      .fetchDecisionAndReturn();
                                }
                                final freshWhisper =
                                    freshDecision?.credits.whisper ?? 0;

                                if (freshWhisper > 0) {
                                  setState(() => _replyWhisperMode = true);
                                  return;
                                }

                                final purchase = await _openPaywall(
                                  feature: PaywallFeature.whisper,
                                );
                                if (purchase == null) return;

                                final ok = await _verifyPurchaseAndApply(
                                  purchase,
                                );
                                if (!ok) return;

                                setState(() => _replyWhisperMode = true);
                              },

                              onSend: (text, ignored) async {
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
                                _emitTyping(true);
                                if (_chaputSheetExtent >=
                                    _chaputSheetMax -
                                        _chaputSheetMaxTolerance) {
                                  return;
                                }
                                _sheetAutoExpanded = true;
                                _sheetExtentBeforeKeyboard = _chaputSheetExtent;
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (!_chaputSheetCtrl.isAttached) return;
                                  if (context.responsive.isAndroid) {
                                    _setChaputSheetExtent(_chaputSheetMax);
                                    _chaputSheetCtrl.jumpTo(_chaputSheetMax);
                                  } else {
                                    _chaputSheetCtrl.animateTo(
                                      _chaputSheetMax,
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                });
                              },
                              onBlur: () {
                                _emitTyping(false);
                                if (!_sheetAutoExpanded) return;
                                _sheetAutoExpanded = false;
                                final target = _sheetExtentBeforeKeyboard;
                                if (target <
                                    _chaputSheetMax -
                                        _chaputSheetMaxTolerance) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (!_chaputSheetCtrl.isAttached) return;
                                    _chaputSheetCtrl.animateTo(
                                      target.clamp(
                                        _chaputSheetMin,
                                        _chaputSheetMax,
                                      ),
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                  });
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),

                    // BUTON
                    ValueListenableBuilder<double>(
                      valueListenable: _chaputSheetExtentListenable,
                      builder: (context, chaputSheetExtent, _) => Positioned(
                        right: 14,
                        bottom: (chaputThreads.isNotEmpty
                            ? (chaputSheetAvailableHeight * chaputSheetExtent +
                                  chaputSheetOuterOffset +
                                  10)
                            : ((showEmptyChaputSheet || showPrivateFollowSheet)
                                  ? (chaputSheetAvailableHeight *
                                            _chaputSheetMin +
                                        context.responsive
                                            .bottomSheetInnerPadding(min: 0) +
                                        chaputSheetOuterOffset +
                                        14)
                                  : 14)),
                        child: SafeArea(
                          top: false,
                          bottom:
                              !(showEmptyChaputSheet && chaputThreads.isEmpty),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            child:
                                (_composerOpen ||
                                    _isInteracting ||
                                    (_silhouetteMode &&
                                        !showPrivateFollowSheet) ||
                                    isMe ||
                                    _chaputThreadCreated ||
                                    hasOurThread ||
                                    (chaputThreads.isNotEmpty &&
                                        chaputSheetExtent >
                                            _chaputSheetMin +
                                                _chaputSheetCollapsedTapTolerance))
                                ? const SizedBox.shrink()
                                : IgnorePointer(
                                    ignoring:
                                        !_threeReady ||
                                        _reviveFlowBusy ||
                                        _uiFollowLoading,
                                    child: BlackGlass(
                                      radius: 16,
                                      blur: 10,
                                      opacity: 0.55,
                                      borderOpacity: 0.12,
                                      child: Material(
                                        type: MaterialType.transparency,
                                        child: InkWell(
                                          onTap:
                                              ((_silhouetteMode &&
                                                      !showPrivateFollowSheet) ||
                                                  _composerOpen)
                                              ? null
                                              : () async {
                                                  if (showPrivateFollowSheet) {
                                                    if (isBlocked ||
                                                        followButtonDisabled) {
                                                      return;
                                                    }

                                                    HapticFeedback.selectionClick();

                                                    setState(() {
                                                      _uiFollowLoading = true;
                                                      _uiRequestedFollow = true;
                                                    });

                                                    try {
                                                      final ctrl = ref.read(
                                                        followControllerProvider(
                                                          username,
                                                        ).notifier,
                                                      );
                                                      await ctrl.follow();
                                                      unawaited(
                                                        ChaputSoundService
                                                            .instance
                                                            .play(
                                                              ChaputSoundEffect
                                                                  .refreshRecommendedUser,
                                                            ),
                                                      );
                                                    } catch (error) {
                                                      if (!mounted) return;
                                                      setState(
                                                        () =>
                                                            _uiRequestedFollow =
                                                                null,
                                                      );
                                                      _handleFollowActionError(
                                                        error,
                                                      );
                                                    } finally {
                                                      if (!mounted) return;
                                                      setState(
                                                        () => _uiFollowLoading =
                                                            false,
                                                      );
                                                    }

                                                    return;
                                                  }
                                                  if (decisionHasArchived &&
                                                      reviveThreadId.length ==
                                                          32) {
                                                    await _handleRevivePressed(
                                                      threadIdHex:
                                                          reviveThreadId,
                                                      profileIdHex:
                                                          profileIdHex,
                                                      chaputArgs: chaputArgs,
                                                      targetUser:
                                                          targetLiteUser,
                                                    );
                                                    return;
                                                  }
                                                  if (showBindExhausted) {
                                                    HapticFeedback.selectionClick();
                                                    final purchase =
                                                        await _openPaywall(
                                                          feature:
                                                              PaywallFeature
                                                                  .bind,
                                                        );
                                                    if (purchase != null) {
                                                      final ok =
                                                          await _verifyPurchaseAndApply(
                                                            purchase,
                                                          );
                                                      if (ok) {
                                                        _prepareComposer();
                                                      }
                                                    }
                                                    return;
                                                  }
                                                  await _handleBindPressed(
                                                    profileId: profileIdHex,
                                                  );
                                                },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  showPrivateFollowSheet
                                                      ? (requestAlreadySent
                                                            ? Icons
                                                                  .schedule_rounded
                                                            : Icons.add_rounded)
                                                      : decisionHasArchived
                                                      ? Icons.restore
                                                      : Icons.draw,
                                                  size: 18,
                                                  color: AppColors.chaputWhite,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  showPrivateFollowSheet
                                                      ? (requestAlreadySent
                                                            ? context.t(
                                                                'profile.follow_request_sent',
                                                              )
                                                            : context.t(
                                                                'profile.follow',
                                                              ))
                                                      : decisionHasArchived
                                                      ? context.t(
                                                          'profile.bind.restore_archive',
                                                        )
                                                      : context.t(
                                                          'profile.bind.start_one',
                                                        ),
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        AppColors.chaputWhite,
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
                    ),

                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 0,
                      child: AnimatedPadding(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOut,
                        padding: context.responsive.bottomFixedPadding(
                          base: 10,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: !showProfileComposer
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
                                  error: (_, _) => ChatComposerBar(
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

                                    final meAvatarUrl =
                                        (meUser?.profilePhotoUrl != null &&
                                            meUser!.profilePhotoUrl!.isNotEmpty)
                                        ? meUser.profilePhotoUrl
                                        : meUser?.defaultAvatar;

                                    final meIsDefault =
                                        (meUser?.profilePhotoUrl == null ||
                                        (meUser!.profilePhotoUrl?.isEmpty ??
                                            true));

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
            ),
          ),
        );
      },
    );
  }
}
