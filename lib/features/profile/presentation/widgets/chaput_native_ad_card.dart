import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/config/env.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/ui/responsive/chaput_responsive.dart';

class ChaputNativeAdCard extends StatefulWidget {
  const ChaputNativeAdCard({super.key});

  static const double minAdHeight = 260.0;
  static const double minTotalHeight = 440.0;

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
    _loadAd();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _loadAd() {
    final cached = _ChaputNativeAdCache.takeReady();
    if (cached != null) {
      if (!mounted) {
        cached.dispose();
        return;
      }
      setState(() {
        _ad = cached;
        _loaded = true;
      });
      _ChaputNativeAdCache.preload();
      return;
    }

    final ad = NativeAd(
      adUnitId: Env.nativeAdUnitId(isIOS: Platform.isIOS),
      factoryId: 'chaputNative',
      request: const AdRequest(),
      nativeAdOptions: NativeAdOptions(
        mediaAspectRatio: MediaAspectRatio.square,
        videoOptions: VideoOptions(
          startMuted: true,
          customControlsRequested: false,
          clickToExpandRequested: false,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _ad = ad as NativeAd;
            _loaded = true;
          });
          _ChaputNativeAdCache.preload();
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          if (!mounted) {
            return;
          }
          setState(() {
            _ad = null;
            _loaded = false;
          });
        },
      ),
    );
    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return const SizedBox.shrink();
    }

    final safeBottom = context.responsive.bottomSheetInnerPadding();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, safeBottom),
      child: SizedBox(
        height: ChaputNativeAdCard.minTotalHeight,
        child: _loaded && _ad != null
            ? AdWidget(key: ObjectKey(_ad), ad: _ad!)
            : Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.chaputNearBlack,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.chaputWhite.withOpacity(0.22),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  context.t('ads.sponsored_content'),
                  textAlign: TextAlign.center,
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

  static NativeAd? takeReady() {
    final ad = _readyAd;
    _readyAd = null;
    return ad;
  }

  static void preload() {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    if (_readyAd != null || _loading) {
      return;
    }
    _loading = true;
    final ad = NativeAd(
      adUnitId: Env.nativeAdUnitId(isIOS: Platform.isIOS),
      factoryId: 'chaputNative',
      request: const AdRequest(),
      nativeAdOptions: NativeAdOptions(
        mediaAspectRatio: MediaAspectRatio.square,
        videoOptions: VideoOptions(
          startMuted: true,
          customControlsRequested: false,
          clickToExpandRequested: false,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _loading = false;
          _readyAd?.dispose();
          _readyAd = ad as NativeAd;
        },
        onAdFailedToLoad: (ad, err) {
          _loading = false;
          ad.dispose();
        },
      ),
    );
    ad.load();
  }
}
