import 'dart:math' as math;

import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../feedback_launcher.dart';

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

  String get _currentRouteLocation {
    final routeInfoPath = widget.router.routeInformationProvider.value.uri
        .toString();
    if (routeInfoPath.isNotEmpty) return routeInfoPath;
    return widget.router.routerDelegate.currentConfiguration.uri.toString();
  }

  bool get _isProfileRoute {
    final path =
        widget.router.routeInformationProvider.value.uri.path.isNotEmpty
        ? widget.router.routeInformationProvider.value.uri.path
        : widget.router.routerDelegate.currentConfiguration.uri.path;
    return path.startsWith('${Routes.profileBase}/') ||
        path.startsWith('/u/') ||
        path.startsWith('/me/');
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
    _pointers[event.pointer] = event.position;

    if (_isProfileRoute) return;
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
      child: widget.child,
    );
  }
}
