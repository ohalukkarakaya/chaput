import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/router/routes.dart';
import '../../../me/application/me_controller.dart';
import '../../application/account_deletion_flow_controller.dart';
import '../../application/calendly_booking.dart';

class CalendlyBookingScreen extends ConsumerStatefulWidget {
  const CalendlyBookingScreen({super.key, required this.request});

  final CalendlyBookingRequest request;

  @override
  ConsumerState<CalendlyBookingScreen> createState() =>
      _CalendlyBookingScreenState();
}

class _CalendlyBookingScreenState extends ConsumerState<CalendlyBookingScreen> {
  late final WebViewController _controller;
  final CalendlyBookingCompletionGuard _completionGuard =
      CalendlyBookingCompletionGuard();
  bool _initialPageReady = false;
  bool _hasError = false;
  int _progress = 0;
  Timer? _readyFallbackTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.chaputLightGrey)
      ..addJavaScriptChannel(
        'ChaputCalendly',
        onMessageReceived: (message) {
          _handleCalendlyMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            _readyFallbackTimer?.cancel();
            setState(() {
              _hasError = false;
              _initialPageReady = false;
              _progress = 0;
            });
          },
          onProgress: (progress) {
            if (!mounted || _hasError) return;
            setState(() => _progress = progress.clamp(0, 100).toInt());
          },
          onPageFinished: (_) {
            if (!mounted || _hasError) return;
            setState(() => _progress = 100);
            _readyFallbackTimer?.cancel();
            _readyFallbackTimer = Timer(const Duration(milliseconds: 1800), () {
              if (!mounted || _hasError || _completionGuard.completed) return;
              _markReady();
            });
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            final failedUrl = error.url ?? '';
            final calendlyAssetFailed =
                failedUrl.contains('calendly.com') ||
                failedUrl.contains('assets.calendly.com');
            if (error.isForMainFrame == false && !calendlyAssetFailed) return;
            _readyFallbackTimer?.cancel();
            setState(() {
              _hasError = true;
              _initialPageReady = false;
              _progress = 0;
            });
          },
        ),
      )
      ..loadHtmlString(buildCalendlyEmbedHtml(widget.request.uri));
  }

  @override
  void dispose() {
    _readyFallbackTimer?.cancel();
    super.dispose();
  }

  void _handleCalendlyMessage(String message) {
    if (!mounted) return;
    if (isCalendlyLifecycleEventMessage(message)) {
      _markReady();
    }
    if (isCalendlyScheduledEventMessage(message)) {
      _completeBooking();
    }
  }

  void _markReady() {
    if (_initialPageReady || _hasError || !mounted) return;
    _readyFallbackTimer?.cancel();
    setState(() => _initialPageReady = true);
  }

  void _completeBooking() {
    if (!_completionGuard.markCompletedOnce() || !mounted) return;
    _readyFallbackTimer?.cancel();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('settings.support_booked_title'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(context.t('settings.support_booked_body')),
          ],
        ),
      ),
    );

    switch (widget.request.source) {
      case CalendlyBookingSource.accountDeletion:
        ref.read(accountDeletionFlowControllerProvider.notifier).clear();
        final userId = ref.read(meControllerProvider).value?.user.userId ?? '';
        context.go(userId.isEmpty ? Routes.home : Routes.profilePath(userId));
        break;
      case CalendlyBookingSource.settingsSupport:
        context.pop(true);
        break;
    }
  }

  void _retry() {
    _readyFallbackTimer?.cancel();
    setState(() {
      _hasError = false;
      _initialPageReady = false;
      _progress = 0;
    });
    _controller.loadHtmlString(buildCalendlyEmbedHtml(widget.request.uri));
  }

  @override
  Widget build(BuildContext context) {
    final showLoading = !_hasError && !_initialPageReady;
    final progress = (_progress / 100).clamp(0.08, 1.0).toDouble();

    return Scaffold(
      backgroundColor: AppColors.chaputLightGrey,
      appBar: AppBar(
        backgroundColor: AppColors.chaputLightGrey,
        foregroundColor: AppColors.chaputBlack,
        elevation: 0,
        title: Text(
          context.t('settings.delete_help_booking_title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!_hasError)
              AnimatedOpacity(
                opacity: _initialPageReady ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: WebViewWidget(controller: _controller),
              ),
            if (showLoading)
              _BookingLoadingOverlay(
                progress: progress,
                label: context.t('settings.delete_help_webview_loading'),
              ),
            if (_hasError)
              _BookingErrorState(
                onRetry: _retry,
                title: context.t('settings.delete_help_webview_error_title'),
                body: context.t('settings.delete_help_webview_error_body'),
              ),
          ],
        ),
      ),
    );
  }
}

class _BookingLoadingOverlay extends StatelessWidget {
  const _BookingLoadingOverlay({required this.progress, required this.label});

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.chaputLightGrey,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    color: AppColors.chaputBlack,
                    backgroundColor: AppColors.chaputBlack.withValues(
                      alpha: 0.08,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.chaputBlack.withValues(alpha: 0.62),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingErrorState extends StatelessWidget {
  const _BookingErrorState({
    required this.onRetry,
    required this.title,
    required this.body,
  });

  final VoidCallback onRetry;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
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
                child: const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.chaputWhite,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.chaputBlack.withValues(alpha: 0.62),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 54,
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
                    context.t('common.retry'),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
