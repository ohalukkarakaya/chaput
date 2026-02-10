import 'dart:async';
import 'dart:ui';

import 'package:chaput/core/i18n/app_localizations.dart';
import '../../constants/app_colors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../features/auth/data/dto/login_verify_response.dart';

Future<LoginVerifyResponse?> showCodeVerifySheet({
  required BuildContext context,
  required String email,
  required Future<void> Function() onResend,
  required Future<LoginVerifyResponse> Function(String code) onVerify,
}) {
  return showModalBottomSheet<LoginVerifyResponse?>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: AppColors.chaputTransparent,
    barrierColor: AppColors.chaputTransparent,
    builder: (_) {
      return _BlurBarrier(
        child: _CodeSheet(
          email: email,
          onResend: onResend,
          onVerify: onVerify,
        ),
      );
    },
  );
}

class _BlurBarrier extends StatelessWidget {
  final Widget child;
  const _BlurBarrier({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Blur barrier (touch yok)
        Positioned.fill(
          child: AbsorbPointer(
            absorbing: true,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(color: AppColors.chaputBlack.withOpacity(0.25)),
            ),
          ),
        ),
        Align(alignment: Alignment.bottomCenter, child: child),
      ],
    );
  }
}

class _CodeSheet extends StatefulWidget {
  final String email;
  final Future<void> Function() onResend;
  final Future<LoginVerifyResponse> Function(String code) onVerify;

  const _CodeSheet({
    required this.email,
    required this.onResend,
    required this.onVerify,
  });

  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  String _code = '';
  String? _errorText;

  bool _verifying = false;

  // resend timer (örn: 30s)
  Timer? _resendTimer;
  int _resendSeconds = 30;

  // too many attempts cooldown
  Timer? _lockTimer;
  int _lockSeconds = 0; // 0 => serbest

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });

    _startResendCountdown();

    _controller.addListener(() {
      final raw = _controller.text;
      final onlyDigits = raw.replaceAll(RegExp(r'[^0-9]'), '');
      final clipped = onlyDigits.length > 6 ? onlyDigits.substring(0, 6) : onlyDigits;

      if (clipped != raw) {
        _controller.value = TextEditingValue(
          text: clipped,
          selection: TextSelection.collapsed(offset: clipped.length),
        );
      }

      setState(() {
        _code = clipped;
        if (_errorText != null) _errorText = null; // typing => error temizle
      });

      if (_code.length == 6) {
        HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _lockTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _startResendCountdown({int seconds = 30}) {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = seconds);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  void _startLockCountdown(int seconds) {
    _lockTimer?.cancel();
    setState(() => _lockSeconds = seconds);

    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_lockSeconds <= 1) {
        t.cancel();
        setState(() => _lockSeconds = 0);
        _focusNode.requestFocus();
      } else {
        setState(() => _lockSeconds -= 1);
      }
    });
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    if (_verifying) return;

    setState(() => _errorText = null);
    try {
      await widget.onResend();
      HapticFeedback.selectionClick();
      _startResendCountdown(seconds: 30);
    } on DioException catch (e) {
      HapticFeedback.heavyImpact();
      setState(() => _errorText = _dioErrorToMessage(e));
    } catch (_) {
      HapticFeedback.heavyImpact();
      setState(() => _errorText = context.t('errors.generic'));
    }
  }

  Future<void> _verify() async {
    if (_verifying) return;
    if (_lockSeconds > 0) return;
    if (_code.length != 6) return;

    setState(() {
      _verifying = true;
      _errorText = null;
    });

    try {
      final res = await widget.onVerify(_code);

      if (res.accessToken.isEmpty || res.refreshToken.isEmpty) {
        throw StateError('empty tokens');
      }

      if (!mounted) return;
      Navigator.of(context).pop(res); // ✅ success -> sheet kapanır
    } on DioException catch (e) {
      HapticFeedback.heavyImpact();

      final status = e.response?.statusCode;
      final msg = _dioErrorToMessage(e);

      // 400 invalid_code / code_expired -> shake + error text
      if (status == 400) {
        _shakeController.forward(from: 0);
        setState(() => _errorText = msg);
      }
      // 409 too_many_attempts -> lockout + countdown
      else if (status == 409) {
        _shakeController.forward(from: 0);
        setState(() => _errorText = msg);

        final retryAfter = _extractRetryAfterSeconds(e.response?.data);
        _startLockCountdown(retryAfter ?? 60);
      } else {
        setState(() => _errorText = msg);
      }
    } catch (_) {
      HapticFeedback.heavyImpact();
      setState(() => _errorText = context.t('errors.generic'));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  String _dioErrorToMessage(DioException e) {
    final data = e.response?.data;

    // backend string döndürebilir: "invalid_code" gibi
    final s = data is String ? data : data?.toString() ?? '';

    if (s.contains('invalid_code')) return context.t('errors.code_invalid');
    if (s.contains('code_expired')) return context.t('errors.code_expired');
    if (s.contains('code_required')) return context.t('errors.code_required');
    if (s.contains('too_many_attempts')) return context.t('errors.too_many_attempts');
    if (s.contains('db_error')) return context.t('errors.db_error');

    final status = e.response?.statusCode;
    return context.t('errors.http_status', params: {'status': status?.toString() ?? '-'});
  }

  int? _extractRetryAfterSeconds(dynamic data) {
    // Eğer backend ileride şunu dönerse:
    // { "retry_after": 45 } veya { "retryAfter": 45 }
    if (data is Map) {
      final v = data['retry_after'] ?? data['retryAfter'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;

    final canResend = _resendSeconds == 0 && !_verifying;
    final isLocked = _lockSeconds > 0;

    return WillPopScope(
      onWillPop: () async => false,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              decoration: BoxDecoration(
                color: AppColors.chaputWhite.withOpacity(0.88),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border.all(color: AppColors.chaputWhite.withOpacity(0.6)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.chaputBlack.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    context.t('code.title'),
                    style: TextStyle(
                      color: AppColors.chaputBlack,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.t('code.subtitle', params: {'email': widget.email}),
                    style: TextStyle(
                      color: AppColors.chaputBlack.withOpacity(0.65),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 14),

                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_shakeAnimation.value, 0),
                        child: child,
                      );
                    },
                    child: Opacity(
                      opacity: isLocked ? 0.6 : 1.0,
                      child: _StarPinRow(valueLength: _code.length),
                    ),
                  ),

                  // gizli input
                  SizedBox(
                    height: 1,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: !isLocked,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(border: InputBorder.none),
                      style: const TextStyle(color: AppColors.chaputTransparent),
                      cursorColor: AppColors.chaputTransparent,
                      enableInteractiveSelection: false,
                      showCursor: false,
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (_errorText != null) ...[
                    Text(
                      _errorText!,
                      style: const TextStyle(
                        color: AppColors.chaputMaterialRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else
                    const SizedBox(height: 4),

                  if (isLocked) ...[
                    Text(
                      context.t('code.resend_in', params: {'seconds': _lockSeconds.toString()}),
                      style: TextStyle(
                        color: AppColors.chaputBlack.withOpacity(0.65),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (!isLocked && _code.length == 6 && !_verifying) ? _verify : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.chaputBlack,
                        disabledBackgroundColor: AppColors.chaputBlack.withOpacity(0.25),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _verifying
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.chaputWhite),
                      )
                          : Text(
                            context.t('code.verify'),
                            style: TextStyle(
                              color: AppColors.chaputWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: canResend ? _resend : null,
                    child: Text(
                      canResend ? context.t('code.resend') : context.t('code.resend_in', params: {'seconds': _resendSeconds.toString()}),
                      style: TextStyle(
                        color: AppColors.chaputBlack.withOpacity(canResend ? 0.9 : 0.35),
                        fontWeight: FontWeight.w700,
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

class _StarPinRow extends StatelessWidget {
  final int valueLength;
  const _StarPinRow({required this.valueLength});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        final filled = i < valueLength;
        return Expanded(
          child: Container(
            height: 56,
            margin: EdgeInsets.only(left: i == 0 ? 0 : 10),
            decoration: BoxDecoration(
              color: AppColors.chaputWhite.withOpacity(0.95),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: filled ? AppColors.chaputBlack.withOpacity(0.35) : AppColors.chaputBlack.withOpacity(0.12),
              ),
            ),
            child: Center(
              child: Text(
                '*',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: filled ? AppColors.chaputBlack : AppColors.chaputBlack.withOpacity(0.25),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
