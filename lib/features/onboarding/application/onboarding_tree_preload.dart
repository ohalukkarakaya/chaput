import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/domain/tree_catalog.dart';
import '../../profile/presentation/utils/tree_model_cache.dart';

final onboardingTreePreloadProvider =
    ChangeNotifierProvider<OnboardingTreePreloadController>((ref) {
      return OnboardingTreePreloadController();
    });

class OnboardingTreePreloadController extends ChangeNotifier {
  final math.Random _random = math.Random();
  TreePreset? _preset;
  Future<void>? _activeWarmup;

  TreePreset get preset {
    return _preset ?? TreeCatalog.resolve('2');
  }

  Future<void> prepareRandom({bool forceNew = false}) {
    if (!forceNew && _activeWarmup != null) return _activeWarmup!;
    if (!forceNew && _preset != null) return Future.value();

    final next = TreeCatalog.all[_random.nextInt(TreeCatalog.all.length)];
    _preset = next;
    notifyListeners();

    final warmup = TreeModelCache.instance.ensureWarm(next.id);
    _activeWarmup = warmup.whenComplete(() {
      if (identical(_activeWarmup, warmup)) {
        _activeWarmup = null;
      }
    });
    return _activeWarmup!;
  }
}
