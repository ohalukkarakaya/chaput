import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';

enum AppReviewPromptAction { liked, later }

Future<AppReviewPromptAction?> showAppReviewPromptSheet(BuildContext context) {
  return showModalBottomSheet<AppReviewPromptAction>(
    context: context,
    backgroundColor: AppColors.chaputTransparent,
    isScrollControlled: false,
    builder: (context) {
      return const _AppReviewPromptSheet();
    },
  );
}

class _AppReviewPromptSheet extends StatelessWidget {
  const _AppReviewPromptSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: BoxDecoration(
            color: AppColors.chaputBlack,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.chaputBlack.withValues(alpha: 0.28),
                blurRadius: 26,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.chaputWhite.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.t('review.prompt_title'),
                style: const TextStyle(
                  color: AppColors.chaputWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.t('review.prompt_body'),
                style: TextStyle(
                  color: AppColors.chaputWhite.withValues(alpha: 0.72),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(AppReviewPromptAction.liked);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.chaputWhite,
                    foregroundColor: AppColors.chaputBlack,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    context.t('review.prompt_positive'),
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
                    Navigator.of(context).pop(AppReviewPromptAction.later);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.chaputWhite.withValues(
                      alpha: 0.82,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: AppColors.chaputWhite.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                  child: Text(
                    context.t('review.prompt_later'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
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
