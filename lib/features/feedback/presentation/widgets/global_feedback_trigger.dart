import 'dart:math' as math;

import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../feedback_launcher.dart';

/// Suspends the global pinch shortcut while an interactive screen is mounted.
class FeedbackGestureBlocker extends StatefulWidget {
  const FeedbackGestureBlocker({super.key, required this.child});

  final Widget child;

  @override
  State<FeedbackGestureBlocker> createState() => _FeedbackGestureBlockerState();
}

class _FeedbackGestureBlockerState extends State<FeedbackGestureBlocker> {
  _GlobalFeedbackTriggerState? _trigger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final trigger = context
        .findAncestorStateOfType<_GlobalFeedbackTriggerState>();
    if (identical(trigger, _trigger)) return;
    _trigger?._changeGestureBlockers(-1);
    _trigger = trigger;
    _trigger?._changeGestureBlockers(1);
  }

  @override
  void dispose() {
    _trigger?._changeGestureBlockers(-1);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class GlobalFeedbackTrigger extends ConsumerStatefulWidget {
  const GlobalFeedbackTrigger({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<GlobalFeedbackTrigger> createState() =>
      _GlobalFeedbackTriggerState();
}

class _GlobalFeedbackTriggerState extends ConsumerState<GlobalFeedbackTrigger> {
  static const int _requiredPointers = 2;
  static const double _minimumStartDistance = 72;
  static const double _triggerScale = 0.76;

  final Map<int, Offset> _pointers = <int, Offset>{};
  double? _initialDistance;
  bool _hasTriggered = false;
  int _gestureBlockers = 0;
  BuildContext? _routeContext;

  void _changeGestureBlockers(int delta) {
    _gestureBlockers += delta;
    _pointers.clear();
    _resetGesture();
  }

  String get _currentRouteLocation {
    final routeContext = _routeContext;
    if (routeContext != null) {
      try {
        final uri = GoRouterState.of(routeContext).uri.toString();
        if (uri.isNotEmpty) return uri;
      } catch (_) {}

      final routeName = ModalRoute.of(routeContext)?.settings.name;
      if (routeName != null && routeName.isNotEmpty) return routeName;
    }

    final routeInfoPath = widget.router.routeInformationProvider.value.uri
        .toString();
    if (routeInfoPath.isNotEmpty) return routeInfoPath;
    return widget.router.routerDelegate.currentConfiguration.uri.toString();
  }

  bool get _isGestureBlockedRoute {
    final path =
        widget.router.routeInformationProvider.value.uri.path.isNotEmpty
        ? widget.router.routeInformationProvider.value.uri.path
        : widget.router.routerDelegate.currentConfiguration.uri.path;
    return _isBlockedGestureRoutePath(path);
  }

  void _resetGesture() {
    _initialDistance = null;
    _hasTriggered = false;
  }

  double? _distanceBetweenActivePointers() {
    if (_pointers.length != _requiredPointers) return null;
    final values = _pointers.values.toList(growable: false);
    final first = values[0];
    final second = values[1];
    final dx = first.dx - second.dx;
    final dy = first.dy - second.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_gestureBlockers > 0) return;
    _pointers[event.pointer] = event.position;
    if (_pointers.length > _requiredPointers) {
      _resetGesture();
      return;
    }

    if (_pointers.length == _requiredPointers) {
      final distance = _distanceBetweenActivePointers();
      if (distance != null && distance >= _minimumStartDistance) {
        _initialDistance = distance;
        _hasTriggered = false;
      }
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_gestureBlockers > 0) return;
    _pointers[event.pointer] = event.position;

    if (_isGestureBlockedRoute) return;
    if (_hasTriggered || _initialDistance == null) return;
    if (_pointers.length != _requiredPointers) return;

    final controller = BetterFeedback.of(context);
    if (controller.isVisible) return;

    final currentDistance = _distanceBetweenActivePointers();
    if (currentDistance == null || _initialDistance == null) return;
    if (_initialDistance! <= 0) return;

    final scale = currentDistance / _initialDistance!;
    if (scale > _triggerScale) return;

    _hasTriggered = true;
    HapticFeedback.selectionClick();

    showAppFeedbackSheet(
      context,
      ref,
      triggerSource: 'gesture',
      routePathOverride: _currentRouteLocation,
    );
  }

  void _handlePointerUp(int pointer) {
    _pointers.remove(pointer);
    if (_pointers.length < _requiredPointers) {
      _resetGesture();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: (event) => _handlePointerUp(event.pointer),
      onPointerCancel: (event) => _handlePointerUp(event.pointer),
      child: Builder(
        builder: (routeContext) {
          _routeContext = routeContext;
          return widget.child;
        },
      ),
    );
  }
}

bool _isBlockedGestureRoutePath(String routePath) {
  final uri = Uri.tryParse(routePath);
  final path = uri?.path ?? routePath;

  if (path == Routes.boot ||
      path == Routes.onboarding ||
      path == Routes.login ||
      path == Routes.register) {
    return true;
  }

  return path.startsWith('${Routes.profileBase}/') ||
      path.startsWith('/u/') ||
      path.startsWith('/me/');
}
