import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/config/env.dart';
import '../../../../core/i18n/app_localizations.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

class ChaputNativeAdCard extends StatefulWidget {
  const ChaputNativeAdCard({super.key});

  static const double minAdHeight = 240.0;
  static const double minTotalHeight = 340.0;

  static void preload() {
    _ChaputNativeAdCache.preload();
  }

  @override
  State<ChaputNativeAdCard> createState() => _ChaputNativeAdCardState();
}

class _ChaputNativeAdCardState extends State<ChaputNativeAdCard> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ChaputNativeAdCache.addListener(_onCacheReady);
    _ad = _ChaputNativeAdCache.take();
    _loaded = _ad != null;
    _ChaputNativeAdCache.preload();
  }

  void _onCacheReady() {
    if (!mounted || _ad != null) return;
    final ad = _ChaputNativeAdCache.take();
    if (ad == null) return;
    setState(() {
      _ad = ad;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ChaputNativeAdCache.removeListener(_onCacheReady);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final card = Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.chaputNearBlack,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.chaputWhite.withOpacity(0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.t('ads.sponsored'),
                style: TextStyle(
                  color: AppColors.chaputWhite.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (_loaded && _ad != null)
                SizedBox(
                  height: ChaputNativeAdCard.minAdHeight,
                  child: AdWidget(ad: _ad!),
                )
              else
                Container(
                  height: ChaputNativeAdCard.minAdHeight,
                  decoration: BoxDecoration(
                    color: AppColors.chaputWhite.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    context.t('ads.sponsored_content'),
                    style: TextStyle(
                      color: AppColors.chaputWhite.withOpacity(0.7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ),
            ],
          ),
        );

        final content = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: card,
        );

        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.bottomCenter,
            minHeight: ChaputNativeAdCard.minTotalHeight,
            maxHeight: ChaputNativeAdCard.minTotalHeight,
            child: SizedBox(
              height: ChaputNativeAdCard.minTotalHeight,
              child: content,
            ),
          ),
        );
      },
    );
  }
}

class _ChaputNativeAdCache {
  static NativeAd? _readyAd;
  static bool _loading = false;
  static final Set<VoidCallback> _listeners = {};

  static void preload() {
    if (_readyAd != null || _loading) return;
    _loading = true;
    final ad = NativeAd(
      adUnitId: Env.nativeAdUnitId(isIOS: Platform.isIOS),
      factoryId: 'chaputNative',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _readyAd = ad as NativeAd;
          _loading = false;
          _notify();
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _loading = false;
          _notify();
        },
      ),
    );
    ad.load();
  }

  static NativeAd? take() {
    final ad = _readyAd;
    _readyAd = null;
    if (ad != null) {
      preload();
    }
    return ad;
  }

  static void addListener(VoidCallback cb) {
    _listeners.add(cb);
  }

  static void removeListener(VoidCallback cb) {
    _listeners.remove(cb);
  }

  static void _notify() {
    for (final cb in _listeners.toList()) {
      cb();
    }
  }
}
