import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/routes.dart';
import 'deep_link_state.dart';

class DeepLinkListener extends ConsumerStatefulWidget {
  const DeepLinkListener({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends ConsumerState<DeepLinkListener> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = _appLinks.uriLinkStream.listen(_handleRuntimeLink);
    _readInitialLink();
  }

  Future<void> _readInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (!mounted || uri == null) return;
      await _storeLink(uri, navigateNow: false);
    } catch (_) {
      // Initial links are non-critical. The app should still boot normally.
    }
  }

  void _handleRuntimeLink(Uri uri) {
    unawaited(_storeLink(uri, navigateNow: true));
  }

  Future<void> _storeLink(Uri uri, {required bool navigateNow}) async {
    final target = chaputDeepLinkTargetFromUri(uri);
    if (target == null) return;

    ref.read(pendingDeepLinkProvider.notifier).state = target;

    if (navigateNow) {
      _restartFromBoot();
    } else {
      _scheduleInitialTargetFallback();
    }
  }

  void _scheduleInitialTargetFallback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isBootRoute()) return;
      _restartFromBoot();
    });
  }

  void _restartFromBoot() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.router.go(Routes.boot);
    });
  }

  bool _isBootRoute() {
    try {
      return widget.router.routerDelegate.currentConfiguration.uri.path ==
          Routes.boot;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
