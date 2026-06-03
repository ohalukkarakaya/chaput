import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/routes.dart';

class DeepLinkTarget {
  const DeepLinkTarget({required this.location, this.extra});

  final String location;
  final Object? extra;
}

final pendingDeepLinkProvider = StateProvider<DeepLinkTarget?>((ref) => null);

DeepLinkTarget? chaputDeepLinkTargetFromUri(Uri uri) {
  if (!_isSupportedChaputUri(uri)) return null;

  final segments = uri.pathSegments
      .where((segment) => segment.isNotEmpty)
      .toList();
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
  return scheme == 'https' &&
      (host == 'chaput.app' || host == 'www.chaput.app');
}

String _withQuery(String path, Uri source) {
  if (!source.hasQuery) return path;
  return '$path?${source.query}';
}
