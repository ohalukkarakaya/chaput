import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_status_api.dart';

final appAvailabilityProvider =
    NotifierProvider<AppAvailabilityController, AppAvailabilityState>(
      AppAvailabilityController.new,
    );

enum AppAvailabilityMode { available, offline, maintenance }

class AppAvailabilityState {
  const AppAvailabilityState({
    required this.mode,
    this.message,
    this.checking = false,
  });

  const AppAvailabilityState.available({bool checking = false})
    : this(mode: AppAvailabilityMode.available, checking: checking);

  const AppAvailabilityState.offline({String? message})
    : this(mode: AppAvailabilityMode.offline, message: message);

  const AppAvailabilityState.maintenance({String? message})
    : this(mode: AppAvailabilityMode.maintenance, message: message);

  final AppAvailabilityMode mode;
  final String? message;
  final bool checking;

  bool get blocksApp => mode != AppAvailabilityMode.available;
}

class AppAvailabilityController extends Notifier<AppAvailabilityState> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _pollTimer;
  bool _checking = false;

  @override
  AppAvailabilityState build() {
    final connectivity = Connectivity();
    _connectivitySub = connectivity.onConnectivityChanged.listen((_) {
      unawaited(checkNow());
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(checkNow());
    });
    ref.onDispose(() {
      _connectivitySub?.cancel();
      _pollTimer?.cancel();
    });
    Future<void>.microtask(checkNow);
    return const AppAvailabilityState.available(checking: true);
  }

  Future<void> checkNow() async {
    if (_checking) return;
    _checking = true;
    if (!state.blocksApp) {
      state = const AppAvailabilityState.available(checking: true);
    }

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (_isOffline(connectivity)) {
        state = const AppAvailabilityState.offline();
        return;
      }

      final status = await ref.read(appStatusApiProvider).fetchStatus();
      if (status.maintenance) {
        state = AppAvailabilityState.maintenance(message: status.message);
      } else {
        state = const AppAvailabilityState.available();
      }
    } catch (_) {
      state = const AppAvailabilityState.offline();
    } finally {
      _checking = false;
    }
  }

  bool _isOffline(List<ConnectivityResult> results) {
    return results.isEmpty ||
        results.every((item) => item == ConnectivityResult.none);
  }
}
