import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../i18n/app_localizations.dart';
import 'app_availability_controller.dart';

class AppAvailabilityGate extends ConsumerWidget {
  const AppAvailabilityGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appAvailabilityProvider);
    return Stack(
      children: [
        child,
        if (state.blocksApp)
          Positioned.fill(
            child: _AvailabilityBlocker(
              mode: state.mode,
              message: state.message,
              onRetry: () =>
                  ref.read(appAvailabilityProvider.notifier).checkNow(),
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
    required this.onRetry,
  });

  final AppAvailabilityMode mode;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final maintenance = mode == AppAvailabilityMode.maintenance;
    final title = maintenance
        ? context.t('availability.maintenance_title')
        : context.t('availability.offline_title');
    final body = maintenance
        ? (message?.isNotEmpty == true
              ? message!
              : context.t('availability.maintenance_body'))
        : context.t('availability.offline_body');
    final icon = maintenance
        ? Icons.construction_rounded
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
                            onPressed: onRetry,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.chaputBlack,
                              foregroundColor: AppColors.chaputWhite,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              context.t('availability.retry'),
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
