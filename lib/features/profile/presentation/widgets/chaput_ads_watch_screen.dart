import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/config/env.dart';

class ChaputAdsWatchScreen extends StatefulWidget {
  const ChaputAdsWatchScreen({
    super.key,
    required this.requiredAds,
    required this.onComplete,
  });

  final int requiredAds;
  final Future<bool> Function() onComplete;

  @override
  State<ChaputAdsWatchScreen> createState() => _ChaputAdsWatchScreenState();
}

class _ChaputAdsWatchScreenState extends State<ChaputAdsWatchScreen> {
  int _watched = 0;
  bool _watching = false;
  bool _canceled = false;
  String? _error;
  RewardedAd? _rewardedAd;
  bool _loading = false;
  bool _earnedThisAd = false;

  int get _remaining => (widget.requiredAds - _watched).clamp(0, widget.requiredAds);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoStart());
  }

  Future<void> _autoStart() async {
    if (_watching || _remaining == 0 || _loading) return;
    setState(() {
      _watching = true;
      _error = null;
    });
    await _loadAndShow();
  }

  Future<void> _loadAndShow() async {
    if (!mounted || _canceled || _remaining == 0) return;
    if (_loading) return;
    setState(() => _loading = true);
    final adUnitId = Env.rewardedAdUnitId(isIOS: Platform.isIOS);
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loading = false);
          _showAd(ad);
        },
        onAdFailedToLoad: (err) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _watching = false;
            _error = 'Reklam yüklenemedi. Lütfen tekrar dene.';
          });
        },
      ),
    );
  }

  Future<void> _finishRewards() async {
    if (!mounted) return;
    setState(() => _watching = false);
    final ok = await widget.onComplete();
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = 'Ödül doğrulanamadı.');
      return;
    }
    Navigator.pop(context, true);
  }

  void _showAd(RewardedAd ad) {
    if (!mounted || _canceled) {
      ad.dispose();
      return;
    }
    _earnedThisAd = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!mounted) return;
        if (_canceled) {
          setState(() => _watching = false);
          return;
        }
        if (_earnedThisAd) {
          setState(() => _watched += 1);
        }
        if (_remaining > 0) {
          _loadAndShow();
        } else {
          _finishRewards();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        if (!mounted) return;
        setState(() {
          _watching = false;
          _error = 'Reklam gösterilemedi. Lütfen tekrar dene.';
        });
      },
    );
    ad.show(onUserEarnedReward: (_, __) {
      _earnedThisAd = true;
    });
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Reklam İzle'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chaput hakkı kazanmak için $widget.requiredAds reklam izlemen gerekiyor.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'İzlenen: $_watched / ${widget.requiredAds}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_watching)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: widget.requiredAds == 0 ? 0 : _watched / widget.requiredAds,
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.12),
                        color: Colors.white,
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
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _remaining == 0
                        ? 'Tamamlandı'
                        : (_loading ? 'Reklam yükleniyor...' : 'Reklamlar izleniyor...'),
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
                  child: const Text(
                    'Vazgeç',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
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
