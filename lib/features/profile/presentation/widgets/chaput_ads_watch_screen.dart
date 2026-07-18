import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../ads/data/chaput_ad_provider.dart';

class ChaputAdsWatchScreen extends StatefulWidget {
  const ChaputAdsWatchScreen({
    super.key,
    required this.requiredAds,
    required this.onComplete,
  });

  final int requiredAds;
  final Future<bool> Function(ChaputAdNetwork network) onComplete;

  @override
  State<ChaputAdsWatchScreen> createState() => _ChaputAdsWatchScreenState();
}

class _ChaputAdsWatchScreenState extends State<ChaputAdsWatchScreen>
    implements LevelPlayRewardedAdListener {
  int _watched = 0;
  bool _watching = false;
  bool _canceled = false;
  bool _loading = false;
  bool _earnedThisAd = false;
  bool _attemptSettled = false;
  bool _completing = false;
  String? _error;
  LevelPlayRewardedAd? _rewardedAd;
  Timer? _loadTimeout;
  Timer? _displayTimeout;

  int get _remaining =>
      (widget.requiredAds - _watched).clamp(0, widget.requiredAds).toInt();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoStart());
  }

  Future<void> _autoStart() async {
    if (_watching || _loading || _completing || _remaining == 0 || _canceled) {
      return;
    }
    setState(() {
      _watching = true;
      _loading = true;
      _error = null;
      _earnedThisAd = false;
      _attemptSettled = false;
    });

    final network = await ChaputAdProvider.resolveNetwork();
    if (!mounted || _canceled) return;
    if (network == null) {
      _creditUnavailableAttempt();
      return;
    }

    final ad = LevelPlayRewardedAd(adUnitId: ChaputAdProvider.rewardedAdUnitId);
    _rewardedAd = ad;
    ad.setListener(this);
    _loadTimeout = Timer(
      const Duration(seconds: 12),
      _creditUnavailableAttempt,
    );
    try {
      await ad.loadAd();
    } catch (_) {
      _creditUnavailableAttempt();
    }
  }

  Future<void> _showRewarded(LevelPlayRewardedAd ad) async {
    if (!mounted || _canceled || !identical(_rewardedAd, ad)) return;
    try {
      if (!await ad.isAdReady()) {
        _creditUnavailableAttempt();
        return;
      }
      _displayTimeout = Timer(
        const Duration(seconds: 8),
        _creditUnavailableAttempt,
      );
      await ad.showAd();
    } catch (_) {
      _creditUnavailableAttempt();
    }
  }

  void _creditUnavailableAttempt() {
    if (!mounted || _canceled || _attemptSettled) return;
    _attemptSettled = true;
    _disposeRewardedAd();
    setState(() {
      _watched += 1;
      _loading = false;
      _watching = false;
    });
    if (_remaining > 0) {
      unawaited(_autoStart());
    } else {
      unawaited(_finishRewards());
    }
  }

  void _creditCompletedAttempt() {
    if (!mounted || _canceled || _attemptSettled) return;
    _attemptSettled = true;
    _disposeRewardedAd();
    setState(() {
      _watched += 1;
      _loading = false;
      _watching = false;
    });
    if (_remaining > 0) {
      unawaited(_autoStart());
    } else {
      unawaited(_finishRewards());
    }
  }

  void _adClosedWithoutReward() {
    if (!mounted || _canceled || _attemptSettled) return;
    _attemptSettled = true;
    _disposeRewardedAd();
    setState(() {
      _loading = false;
      _watching = false;
      _error = context.t('ads.show_failed');
    });
  }

  void _disposeRewardedAd() {
    _loadTimeout?.cancel();
    _loadTimeout = null;
    _displayTimeout?.cancel();
    _displayTimeout = null;
    final ad = _rewardedAd;
    _rewardedAd = null;
    if (ad != null) {
      unawaited(ad.dispose());
    }
  }

  Future<void> _finishRewards() async {
    if (!mounted || _completing || _canceled) return;
    _completing = true;
    setState(() => _watching = false);
    final ok = await widget.onComplete(ChaputAdNetwork.levelPlay);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _completing = false;
        _error = context.t('ads.reward_verify_failed');
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {
    final ad = _rewardedAd;
    if (!mounted || _canceled || ad == null) return;
    _loadTimeout?.cancel();
    _loadTimeout = null;
    setState(() => _loading = false);
    unawaited(_showRewarded(ad));
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    _creditUnavailableAttempt();
  }

  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {
    _displayTimeout?.cancel();
    _displayTimeout = null;
  }

  @override
  void onAdDisplayFailed(LevelPlayAdError error, LevelPlayAdInfo adInfo) {
    _creditUnavailableAttempt();
  }

  @override
  void onAdClosed(LevelPlayAdInfo adInfo) {
    if (_earnedThisAd) {
      _creditCompletedAttempt();
    } else {
      _adClosedWithoutReward();
    }
  }

  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}

  @override
  void onAdInfoChanged(LevelPlayAdInfo adInfo) {}

  @override
  void onAdRewarded(LevelPlayReward reward, LevelPlayAdInfo adInfo) {
    _earnedThisAd = true;
  }

  @override
  void dispose() {
    _disposeRewardedAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retryable = !_watching && !_loading && !_completing && _remaining > 0;

    return Scaffold(
      backgroundColor: AppColors.chaputBlack,
      appBar: AppBar(
        backgroundColor: AppColors.chaputBlack,
        foregroundColor: AppColors.chaputWhite,
        elevation: 0,
        title: Text(context.t('ads.watch_title')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t(
                  'ads.watch_desc',
                  params: {'count': widget.requiredAds.toString()},
                ),
                style: const TextStyle(
                  color: AppColors.chaputWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.chaputWhite.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.chaputWhite.withOpacity(0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.t(
                              'ads.watched_progress',
                              params: {'count': _watched.toString()},
                            ),
                            style: const TextStyle(
                              color: AppColors.chaputWhite,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_watching || _loading || _completing)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.chaputWhite,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: widget.requiredAds == 0
                            ? 0
                            : _watched / widget.requiredAds,
                        minHeight: 6,
                        backgroundColor: AppColors.chaputWhite.withOpacity(
                          0.12,
                        ),
                        color: AppColors.chaputWhite,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: retryable ? _autoStart : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.chaputWhite,
                    foregroundColor: AppColors.chaputBlack,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _remaining == 0
                        ? context.t('ads.completed')
                        : (_loading || _watching
                              ? context.t('ads.watching')
                              : context.t('ads.watch_title')),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () {
                    _canceled = true;
                    Navigator.pop(context, false);
                  },
                  child: Text(
                    context.t('common.cancel'),
                    style: const TextStyle(
                      color: AppColors.chaputWhite70,
                      fontWeight: FontWeight.w700,
                    ),
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
