import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/config/env.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';

class ChaputNativeAdCard extends StatefulWidget {
  const ChaputNativeAdCard({super.key});

  static const double minAdHeight = 300.0;
  static const double minTotalHeight = 430.0;

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
    if (!mounted || _ad != null) {
      return;
    }
    final ad = _ChaputNativeAdCache.take();
    if (ad == null) {
      return;
    }
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

    final mediaQuery = MediaQuery.of(context);
    final safeBottom = mediaQuery.viewPadding.bottom > mediaQuery.padding.bottom
        ? mediaQuery.viewPadding.bottom
        : mediaQuery.padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        safeBottom > 0 ? safeBottom : 12,
      ),
      child: SizedBox(
        height: ChaputNativeAdCard.minTotalHeight,
        child: _loaded && _ad != null
            ? AdWidget(ad: _ad!)
            : Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.chaputNearBlack,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.chaputWhite.withOpacity(0.22),
                  ),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  context.t('ads.sponsored_content'),
                  style: TextStyle(
                    color: AppColors.chaputWhite.withOpacity(0.7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ChaputNativeAdCache {
  static NativeAd? _readyAd;
  static bool _loading = false;
  static final Set<VoidCallback> _listeners = {};

  static void preload() {
    if (_readyAd != null || _loading) {
      return;
    }
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
