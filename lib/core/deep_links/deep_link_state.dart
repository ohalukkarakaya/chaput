import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/routes.dart';

class DeepLinkTarget {
  const DeepLinkTarget({required this.location, this.extra});

  final String location;
  final Object? extra;
}

final pendingDeepLinkProvider = StateProvider<DeepLinkTarget?>((ref) => null);

bool chaputDeepLinkTargetRequiresAuth(DeepLinkTarget target) {
  final path = Uri.parse(target.location).path;
  if (path == Routes.boot ||
      path == Routes.onboarding ||
      path == Routes.login ||
      path == Routes.register ||
      path == Routes.legal) {
    return false;
  }
  return true;
}

DeepLinkTarget? chaputDeepLinkTargetFromUri(Uri uri) {
  if (!_isSupportedChaputUri(uri)) return null;

  final segments = _chaputPathSegments(uri);
  if (segments.isEmpty) {
    return DeepLinkTarget(location: _withQuery(Routes.boot, uri));
  }

  final first = segments.first;
  if (segments.length >= 2) {
    final id = segments[1];
    switch (first) {
      case 'u':
        return DeepLinkTarget(location: _withQuery(Routes.treePath(id), uri));
      case 'c':
        return DeepLinkTarget(location: _withQuery(Routes.chaputPath(id), uri));
      case 'post':
        return DeepLinkTarget(location: _withQuery(Routes.postPath(id), uri));
      case 'profile':
        return DeepLinkTarget(
          location: _withQuery(Routes.profilePath(id), uri),
        );
      case 'me':
        return DeepLinkTarget(location: _withQuery('/me/$id', uri));
    }
  }

  // Keep future app routes working without changing native link configuration.
  return DeepLinkTarget(location: _withQuery(uri.path, uri));
}

bool _isSupportedChaputUri(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  if (scheme == 'https') {
    return host == 'chaput.app' || host == 'www.chaput.app';
  }
  if (scheme != 'app.chaput') return false;
  return host.isEmpty ||
      host == 'chaput.app' ||
      host == 'www.chaput.app' ||
      _isKnownDeepLinkRoot(host);
}

List<String> _chaputPathSegments(Uri uri) {
  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (uri.scheme.toLowerCase() != 'app.chaput') return segments;

  final host = uri.host.toLowerCase();
  if (_isKnownDeepLinkRoot(host)) {
    return [host, ...segments];
  }
  return segments;
}

bool _isKnownDeepLinkRoot(String value) {
  return value == 'me' ||
      value == 'u' ||
      value == 'c' ||
      value == 'post' ||
      value == 'profile';
}

String _withQuery(String path, Uri source) {
  if (!source.hasQuery) return path;
  return '$path?${source.query}';
}
