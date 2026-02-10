import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';
import 'sheet_handle.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

class ChaputAdOfferSheet extends StatelessWidget {
  const ChaputAdOfferSheet({
    super.key,
    required this.requiredAds,
    required this.canWatch,
  });

  final int requiredAds;
  final bool canWatch;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomInset = mq.padding.bottom;
    final safeRequired = requiredAds <= 0 ? 1 : requiredAds;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 14),
              decoration: BoxDecoration(
                color: AppColors.chaputBlack.withOpacity(0.78),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.chaputWhite.withOpacity(0.10)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SheetHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t('ads.offer_title'),
                                style: TextStyle(
                                  color: AppColors.chaputWhite,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                canWatch
                                    ? context.t(
                                        'ads.offer_desc',
                                        params: {'count': safeRequired.toString()},
                                      )
                                    : context.t('ads.offer_desc_unavailable'),
                                style: TextStyle(
                                  color: AppColors.chaputWhite.withOpacity(0.72),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkResponse(
                          radius: 22,
                          onTap: () => Navigator.pop(context, false),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.chaputWhite.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 20, color: AppColors.chaputWhite),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.chaputWhite,
                                side: BorderSide(color: AppColors.chaputWhite.withOpacity(0.25)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(
                                context.t('common.cancel'),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: canWatch ? () => Navigator.pop(context, true) : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.chaputWhite,
                                foregroundColor: AppColors.chaputBlack,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: Text(
                                context.t('ads.watch_title'),
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
