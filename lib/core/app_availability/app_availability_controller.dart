import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_status_api.dart';
import 'app_update_service.dart';

final appAvailabilityProvider =
    NotifierProvider<AppAvailabilityController, AppAvailabilityState>(
      AppAvailabilityController.new,
    );

enum AppAvailabilityMode { available, offline, maintenance, updateRequired }

class AppAvailabilityState {
  const AppAvailabilityState({
    required this.mode,
    this.message,
    this.storeVersion,
    this.storeName,
    this.checking = false,
  });

  const AppAvailabilityState.available({bool checking = false})
    : this(mode: AppAvailabilityMode.available, checking: checking);

  const AppAvailabilityState.offline({String? message})
    : this(mode: AppAvailabilityMode.offline, message: message);

  const AppAvailabilityState.maintenance({String? message})
    : this(mode: AppAvailabilityMode.maintenance, message: message);

  const AppAvailabilityState.updateRequired({
    String? message,
    String? storeVersion,
    String? storeName,
  }) : this(
         mode: AppAvailabilityMode.updateRequired,
         message: message,
         storeVersion: storeVersion,
         storeName: storeName,
       );

  final AppAvailabilityMode mode;
  final String? message;
  final String? storeVersion;
  final String? storeName;
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

  Future<AppAvailabilityState> checkNow({bool forceUpdateCheck = false}) async {
    if (_checking) return state;
    _checking = true;
    if (!state.blocksApp) {
      state = const AppAvailabilityState.available(checking: true);
    }

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (await _isConfirmedOffline(connectivity)) {
        state = const AppAvailabilityState.offline();
        return state;
      }

      final status = await ref.read(appStatusApiProvider).fetchStatus();
      if (status.maintenance) {
        state = AppAvailabilityState.maintenance(message: status.message);
      } else {
        final update = await ref
            .read(appUpdateServiceProvider)
            .checkForUpdate(force: forceUpdateCheck);
        if (update.updateRequired) {
          state = AppAvailabilityState.updateRequired(
            storeVersion: update.storeVersion,
            storeName: update.storeName,
          );
        } else {
          state = const AppAvailabilityState.available();
        }
      }
      return state;
    } catch (_) {
      state = const AppAvailabilityState.maintenance();
      return state;
    } finally {
      _checking = false;
    }
  }

  Future<bool> _isConfirmedOffline(List<ConnectivityResult> first) async {
    if (!_isOffline(first)) return false;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final second = await Connectivity().checkConnectivity();
    return _isOffline(second);
  }

  bool _isOffline(List<ConnectivityResult> results) {
    return results.isEmpty ||
        results.every((item) => item == ConnectivityResult.none);
  }
}
