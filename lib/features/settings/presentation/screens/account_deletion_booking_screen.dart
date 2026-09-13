import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';

class AccountDeletionBookingScreen extends StatefulWidget {
  const AccountDeletionBookingScreen({super.key, required this.initialUri});

  final Uri initialUri;

  @override
  State<AccountDeletionBookingScreen> createState() =>
      _AccountDeletionBookingScreenState();
}

class _AccountDeletionBookingScreenState
    extends State<AccountDeletionBookingScreen> {
  late final WebViewController _controller;
  bool _initialPageReady = false;
  bool _hasError = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.chaputLightGrey)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
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
            setState(() {
              _progress = 100;
              _initialPageReady = true;
            });
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false || !mounted) return;
            setState(() {
              _hasError = true;
              _initialPageReady = false;
              _progress = 0;
            });
          },
        ),
      )
      ..loadRequest(widget.initialUri);
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _initialPageReady = false;
      _progress = 0;
    });
    _controller.loadRequest(widget.initialUri);
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
