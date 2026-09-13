import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/ui/responsive/chaput_responsive.dart';
import '../../../me/application/me_controller.dart';
import '../../application/calendly_booking.dart';

class SettingsSupportIntroScreen extends ConsumerStatefulWidget {
  const SettingsSupportIntroScreen({super.key});

  @override
  ConsumerState<SettingsSupportIntroScreen> createState() =>
      _SettingsSupportIntroScreenState();
}

class _SettingsSupportIntroScreenState
    extends ConsumerState<SettingsSupportIntroScreen> {
  bool _openingBooking = false;

  void _openBooking() {
    if (_openingBooking) return;
    setState(() => _openingBooking = true);
    HapticFeedback.selectionClick();
    final user = ref.read(meControllerProvider).value?.user;
    final uri = buildChaputHelpCalendlyUri(
      fullName: user?.fullName ?? '',
      email: user?.email ?? '',
    );
    context.pushReplacement(
      Routes.calendlyBooking,
      extra: CalendlyBookingRequest(
        source: CalendlyBookingSource.settingsSupport,
        uri: uri,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Scaffold(
      backgroundColor: AppColors.chaputLightGrey,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                responsive.bottomFixedOffset(base: 18).toDouble(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).maybePop();
                      },
                      icon: const Icon(Icons.chevron_left, size: 30),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              context.t('settings.support_intro_title'),
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              context.t('settings.support_intro_question'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              context.t('settings.support_intro_body'),
                              style: TextStyle(
                                color: AppColors.chaputBlack.withValues(
                                  alpha: 0.66,
                                ),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.36,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              context.t('settings.delete_help_languages'),
                              style: TextStyle(
                                color: AppColors.chaputBlack.withValues(
                                  alpha: 0.58,
                                ),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _openingBooking
                                    ? null
                                    : _openBooking,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.chaputBlack,
                                  foregroundColor: AppColors.chaputWhite,
                                  disabledBackgroundColor: AppColors.chaputBlack
                                      .withValues(alpha: 0.32),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: Text(
                                  context.t('settings.support_intro_book'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                Navigator.of(context).maybePop();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.chaputBlack,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: Text(
                                context.t('settings.support_intro_not_now'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
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
            ),
          ),
        ),
      ),
    );
  }
}
