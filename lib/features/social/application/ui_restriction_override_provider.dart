import 'package:flutter_riverpod/flutter_riverpod.dart';

/// null = server state kullan
/// true/false = UI override (optimistic)
final uiRestrictedOverrideProvider =
AutoDisposeStateProviderFamily<bool?, String>(
      (ref, userId) => null,
);
