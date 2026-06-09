import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/routes.dart';
import '../storage/secure_storage_provider.dart';
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
      await _storeLink(uri, navigateNow: false);
    } catch (_) {
      // Initial links are non-critical. The app should still boot normally.
    }
  }

  void _handleRuntimeLink(Uri uri) {
    unawaited(_storeLink(uri, navigateNow: true));
  }

  Future<void> _storeLink(Uri uri, {required bool navigateNow}) async {
    final key = uri.toString();
    if (_lastHandledUri == key) return;

    final target = chaputDeepLinkTargetFromUri(uri);
    if (target == null) return;

    _lastHandledUri = key;
    if (!await _canOpenTarget(target)) {
      if (navigateNow) {
        _navigate(const DeepLinkTarget(location: Routes.onboarding));
      }
      return;
    }

    ref.read(pendingDeepLinkProvider.notifier).state = target;

    if (navigateNow) {
      _navigate(target);
    } else {
      _scheduleInitialTargetFallback(target);
    }
  }

  void _scheduleInitialTargetFallback(DeepLinkTarget target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_tryOpenInitialTarget(target)) {
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          _tryOpenInitialTarget(target);
        });
      }
    });
  }

  Future<bool> _canOpenTarget(DeepLinkTarget target) async {
    if (!chaputDeepLinkTargetRequiresAuth(target)) return true;
    final refresh = await ref.read(tokenStorageProvider).readRefreshToken();
    final canOpen = refresh != null && refresh.isNotEmpty;
    if (!canOpen) {
      ref.read(pendingDeepLinkProvider.notifier).state = null;
    }
    return canOpen;
  }

  void _navigate(DeepLinkTarget target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isBootRoute() && chaputDeepLinkTargetRequiresAuth(target)) return;
      _pushOrGoTarget(target);
      ref.read(pendingDeepLinkProvider.notifier).state = null;
    });
  }

  bool _tryOpenInitialTarget(DeepLinkTarget target) {
    final pending = ref.read(pendingDeepLinkProvider);
    if (pending?.location != target.location) return true;
    if (_isBootRoute()) return false;
    _pushOrGoTarget(target);
    ref.read(pendingDeepLinkProvider.notifier).state = null;
    return true;
  }

  void _pushOrGoTarget(DeepLinkTarget target) {
    if (target.location == Routes.home ||
        target.location == Routes.onboarding ||
        target.location == Routes.login) {
      widget.router.go(target.location, extra: target.extra);
      return;
    }
    widget.router.push(target.location, extra: target.extra);
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
