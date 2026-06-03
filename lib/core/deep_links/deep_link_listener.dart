import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  String? _lastHandledUri;

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
      _storeLink(uri, navigateNow: false);
    } catch (_) {
      // Initial links are non-critical. The app should still boot normally.
    }
  }

  void _handleRuntimeLink(Uri uri) {
    _storeLink(uri, navigateNow: true);
  }

  void _storeLink(Uri uri, {required bool navigateNow}) {
    final key = uri.toString();
    if (_lastHandledUri == key) return;

    final target = chaputDeepLinkTargetFromUri(uri);
    if (target == null) return;

    _lastHandledUri = key;
    ref.read(pendingDeepLinkProvider.notifier).state = target;

    if (navigateNow) {
      _navigate(target);
    }
  }

  void _navigate(DeepLinkTarget target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.router.go(target.location, extra: target.extra);
      ref.read(pendingDeepLinkProvider.notifier).state = null;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
