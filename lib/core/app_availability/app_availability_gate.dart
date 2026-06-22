import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../i18n/app_localizations.dart';
import '../router/app_router.dart';
import '../router/routes.dart';
import 'app_availability_controller.dart';
import 'app_update_service.dart';

class AppAvailabilityGate extends ConsumerStatefulWidget {
  const AppAvailabilityGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppAvailabilityGate> createState() =>
      _AppAvailabilityGateState();
}

class _AppAvailabilityGateState extends ConsumerState<AppAvailabilityGate> {
  bool _retrying = false;
  bool _openingStore = false;

  Future<void> _retryAndGoHomeIfRecovered() async {
    if (_retrying) return;
    _retrying = true;
    try {
      final next = await ref.read(appAvailabilityProvider.notifier).checkNow();
      if (!mounted || next.blocksApp) return;
      _restartBootFlow();
    } finally {
      _retrying = false;
    }
  }

  void _restartBootFlow() {
    final router = ref.read(appRouterProvider);
    final bootRoute =
        '${Routes.boot}?availability_retry=${DateTime.now().millisecondsSinceEpoch}';
    router.go(bootRoute);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.maybeOf(context, rootNavigator: true);
      if (navigator != null && navigator.canPop()) {
        navigator.popUntil((route) => route.isFirst);
      }
      router.go(bootRoute);
    });

    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      router.go(bootRoute);
    });
  }

  Future<void> _openStoreForUpdate() async {
    if (_openingStore) return;
    _openingStore = true;
    try {
      await ref.read(appUpdateServiceProvider).openStore();
    } finally {
      _openingStore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appAvailabilityProvider);
    return Stack(
      children: [
        widget.child,
        if (state.blocksApp)
          Positioned.fill(
            child: _AvailabilityBlocker(
              mode: state.mode,
              message: state.message,
              storeVersion: state.storeVersion,
              storeName: state.storeName,
              onRetry: _retryAndGoHomeIfRecovered,
              onOpenStore: _openStoreForUpdate,
            ),
          ),
      ],
    );
  }
}

class _AvailabilityBlocker extends StatelessWidget {
  const _AvailabilityBlocker({
    required this.mode,
    required this.message,
    required this.storeVersion,
    required this.storeName,
    required this.onRetry,
    required this.onOpenStore,
  });

  final AppAvailabilityMode mode;
  final String? message;
  final String? storeVersion;
  final String? storeName;
  final Future<void> Function() onRetry;
  final Future<void> Function() onOpenStore;

  @override
  Widget build(BuildContext context) {
    final maintenance = mode == AppAvailabilityMode.maintenance;
    final updateRequired = mode == AppAvailabilityMode.updateRequired;
    final title = maintenance
        ? context.t('availability.maintenance_title')
        : updateRequired
        ? context.t('availability.update_title')
        : context.t('availability.offline_title');
    final body = maintenance
        ? (message?.isNotEmpty == true
              ? message!
              : context.t('availability.maintenance_body'))
        : updateRequired
        ? context
              .t('availability.update_body')
              .replaceAll('{store}', storeName ?? 'store')
              .replaceAll(
                '{version}',
                storeVersion == null || storeVersion!.isEmpty
                    ? ''
                    : ' $storeVersion',
              )
        : context.t('availability.offline_body');
    final icon = maintenance
        ? Icons.construction_rounded
        : updateRequired
        ? Icons.system_update_rounded
        : Icons.wifi_off_rounded;

    return Material(
      color: AppColors.chaputLightGrey,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: -90,
              top: 80,
              child: _Blob(
                size: 220,
                color: AppColors.chaputPink.withValues(alpha: 0.18),
              ),
            ),
            Positioned(
              right: -70,
              bottom: 120,
              child: _Blob(
                size: 240,
                color: AppColors.chaputOrange.withValues(alpha: 0.16),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                    decoration: BoxDecoration(
                      color: AppColors.chaputWhite,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.chaputBlack.withValues(alpha: 0.08),
                          blurRadius: 30,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.chaputBlack,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            icon,
                            color: AppColors.chaputWhite,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.chaputBlack.withValues(
                              alpha: 0.62,
                            ),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              if (updateRequired) {
                                onOpenStore();
                              } else {
                                onRetry();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.chaputBlack,
                              foregroundColor: AppColors.chaputWhite,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              updateRequired
                                  ? context.t('availability.update_button')
                                  : context.t('availability.retry'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
