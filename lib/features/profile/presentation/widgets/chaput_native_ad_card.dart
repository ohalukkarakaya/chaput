import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/ui/responsive/chaput_responsive.dart';
import '../../../ads/data/chaput_ad_provider.dart';

class ChaputNativeAdCard extends StatefulWidget {
  const ChaputNativeAdCard({super.key});

  static const double minTotalHeight = 440.0;

  static bool get isAvailable => ChaputAdProvider.supportsNativeAds;

  static void preload() {
    if (!isAvailable) return;
    unawaited(ChaputAdProvider.initialize());
  }

  @override
  State<ChaputNativeAdCard> createState() => _ChaputNativeAdCardState();
}

class _ChaputNativeAdCardState extends State<ChaputNativeAdCard>
    implements LevelPlayNativeAdListener {
  LevelPlayNativeAd? _ad;
  bool _loaded = false;
  bool _loadRequested = false;

  @override
  void initState() {
    super.initState();
    unawaited(_prepareAd());
  }

  @override
  void dispose() {
    _ad?.destroyAd();
    super.dispose();
  }

  Future<void> _prepareAd() async {
    if (!ChaputNativeAdCard.isAvailable) return;

    final ready = await ChaputAdProvider.ensureLevelPlayReady();
    if (!mounted || !ready) return;

    final ad = LevelPlayNativeAd.builder().withListener(this).build();
    final placementName = ChaputAdProvider.nativePlacementName;
    if (placementName.isNotEmpty) {
      ad.setPlacementName(placementName);
    }

    setState(() {
      _ad = ad;
      _loaded = false;
    });
  }

  void _requestLoad() {
    if (_loadRequested || _ad == null) return;
    _loadRequested = true;
    _ad!.loadAd();
  }

  @override
  void onAdClicked(LevelPlayNativeAd nativeAd, AdInfo adInfo) {}

  @override
  void onAdImpression(LevelPlayNativeAd nativeAd, AdInfo adInfo) {}

  @override
  void onAdLoaded(LevelPlayNativeAd nativeAd, AdInfo adInfo) {
    if (!mounted || nativeAd != _ad) return;
    setState(() => _loaded = true);
  }

  @override
  void onAdLoadFailed(LevelPlayNativeAd nativeAd, IronSourceError error) {
    nativeAd.destroyAd();
    if (!mounted || nativeAd != _ad) return;
    setState(() {
      _ad = null;
      _loaded = false;
    });
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.chaputNearBlack,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.chaputWhite.withOpacity(0.22)),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if ((!Platform.isIOS && !Platform.isAndroid) ||
        !ChaputNativeAdCard.isAvailable ||
        ad == null) {
      return const SizedBox.shrink();
    }

    final safeBottom = context.responsive.bottomSheetInnerPadding();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, safeBottom),
      child: SizedBox(
        height: ChaputNativeAdCard.minTotalHeight,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              LevelPlayNativeAdView(
                key: ObjectKey(ad),
                nativeAd: ad,
                templateType: LevelPlayTemplateType.MEDIUM,
                width: constraints.maxWidth,
                height: ChaputNativeAdCard.minTotalHeight,
                onPlatformViewCreated: _requestLoad,
              ),
              if (!_loaded) _placeholder(context),
            ],
          ),
        ),
      ),
    );
  }
}
