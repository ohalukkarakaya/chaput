import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../constants/app_colors.dart';
import '../i18n/app_localizations.dart';

class LegalWebViewScreen extends StatefulWidget {
  const LegalWebViewScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<LegalWebViewScreen> createState() => _LegalWebViewScreenState();
}

class _LegalWebViewScreenState extends State<LegalWebViewScreen> {
  late final WebViewController _controller;
  var _isLoading = true;
  var _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.chaputWhite)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _isLoading = false);
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chaputWhite,
      appBar: AppBar(
        backgroundColor: AppColors.chaputWhite,
        foregroundColor: AppColors.chaputBlack,
        elevation: 0,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          if (!_hasError) WebViewWidget(controller: _controller),
          if (_isLoading && !_hasError)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.chaputBlack,
                backgroundColor: AppColors.chaputLightGrey,
              ),
            ),
          if (_hasError)
            Center(
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
                          Icons.description_outlined,
                          color: AppColors.chaputWhite,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        context.t('legal.webview_error_title'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.t('legal.webview_error_body'),
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
                          onPressed: () => _controller.reload(),
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
            ),
        ],
      ),
    );
  }
}
