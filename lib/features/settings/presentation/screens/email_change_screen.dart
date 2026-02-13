import 'package:chaput/core/ui/widgets/code_verify_sheet.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/widgets/email_otp_verify_sheet.dart';
import 'package:chaput/core/ui/widgets/shimmer_skeleton.dart';
import '../../../me/application/me_controller.dart';
import '../../application/email_change_controller.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

class EmailChangeScreen extends ConsumerStatefulWidget {
  const EmailChangeScreen({super.key});

  @override
  ConsumerState<EmailChangeScreen> createState() => _EmailChangeScreenState();
}

class _EmailChangeScreenState extends ConsumerState<EmailChangeScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String s) {
    final v = s.trim();
    return v.contains('@') && v.contains('.') && v.length >= 6;
  }

  Future<void> _submit() async {
    final email = _controller.text.trim().toLowerCase();
    if (!_looksLikeEmail(email)) {
      HapticFeedback.heavyImpact();
      return;
    }

    final ok = await ref.read(emailChangeControllerProvider.notifier).requestCode(email);
    if (!mounted || !ok) return;

    HapticFeedback.selectionClick();

    // ✅ mevcut sheet’i reuse ediyoruz
    final verified = await showCodeVerifySheet(
      context: context,
      email: email,
      onResend: () => ref.read(emailChangeControllerProvider.notifier).requestCode(email),
      onVerify: (code) async {
        final res = await ref.read(emailChangeControllerProvider.notifier).verifyCode(code);

        if (res.ok) {
          // sheet LoginVerifyResponse istiyor; burada minimal “dummy” döndürmek yerine
          // sheet’i generic yapmadığımız için şu an hack yapmayacağız.
          // Bu yüzden: sheet’i bu ekranda KULLANMAYALIM, kendi email otp sheet’ini yazalım.
          throw UnsupportedError('use email otp sheet');
        }

        // sheet kendi içinde DioException bekliyor. Burada da uyumsuzluk var.
        // O yüzden: Email için ayrı sheet yazacağız (aşağıda).
        throw UnsupportedError('use email otp sheet');
      },
    );

    // Buraya gelmiyoruz (yukarıda UnsupportedError).
    if (verified == null) return;
  }

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(meControllerProvider);
    final st = ref.watch(emailChangeControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.chaputLightGrey,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.t('common.back'), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 8),

                  _WhiteCard(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: meAsync.when(
                        loading: () => const _EmailChangeShimmer(),
                        error: (_, __) => Text(context.t('common.load_failed')),
                        data: (me) {
                          final current = me?.user.email ?? context.t('common.na');

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(context.t('common.email'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              Text(
                                context.t('settings.email_current', params: {'email': current}),
                                style: TextStyle(color: AppColors.chaputBlack.withOpacity(0.60), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 14),

                              TextField(
                                controller: _controller,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                onChanged: (_) => ref.read(emailChangeControllerProvider.notifier).clearError(),
                                decoration: InputDecoration(
                                  hintText: context.t('settings.email_new_placeholder'),
                                  filled: true,
                                  fillColor: AppColors.chaputBlack.withOpacity(0.04),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                ),
                              ),
                              const SizedBox(height: 10),

                              if (st.errorMessage != null) ...[
                                Text(context.t(st.errorMessage!), style: const TextStyle(color: AppColors.chaputMaterialRed, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 10),
                              ],

                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: st.isLoading ? null : () async {
                                    // ✅ Email için özel OTP sheet (bir sonraki dosya)
                                    final email = _controller.text.trim().toLowerCase();
                                    if (!_looksLikeEmail(email)) {
                                      HapticFeedback.heavyImpact();
                                      return;
                                    }

                                    final ok = await ref.read(emailChangeControllerProvider.notifier).requestCode(email);
                                    if (!mounted || !ok) return;

                                    final didVerify = await showEmailOtpVerifySheet(
                                      context: context,
                                      email: email,
                                      onResend: () => ref.read(emailChangeControllerProvider.notifier).requestCode(email),
                                      onVerify: (code) => ref.read(emailChangeControllerProvider.notifier).verifyCode(code),
                                    );

                                    if (!mounted) return;
                                    if (didVerify == true) {
                                      Navigator.of(context).pop(); // settings’e dön
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.chaputBlack,
                                    foregroundColor: AppColors.chaputWhite,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: st.isLoading
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.chaputWhite))
                                      : Text(context.t('common.send_code'), style: const TextStyle(fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ],
                          );
                        },
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

class _EmailChangeShimmer extends StatelessWidget {
  const _EmailChangeShimmer();

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ShimmerLine(width: 140, height: 14),
          const SizedBox(height: 10),
          const ShimmerLine(width: 220, height: 10),
          const SizedBox(height: 16),
          ShimmerBlock(
            height: 46,
            radius: 14,
            color: AppColors.chaputBlack.withOpacity(0.06),
          ),
          const SizedBox(height: 14),
          ShimmerBlock(
            height: 52,
            radius: 14,
            color: AppColors.chaputBlack.withOpacity(0.10),
          ),
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final Widget child;
  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.chaputWhite.withOpacity(0.92),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            blurRadius: 26,
            offset: const Offset(0, 14),
            color: AppColors.chaputBlack.withOpacity(0.08),
          ),
        ],
      ),
      child: child,
    );
  }
}
