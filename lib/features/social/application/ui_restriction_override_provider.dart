import 'package:flutter_riverpod/legacy.dart';

/// null = server state kullan
/// true/false = UI override (optimistic)
final uiRestrictedOverrideProvider = StateProvider.autoDispose
    .family<bool?, String>((ref, userId) => null);
