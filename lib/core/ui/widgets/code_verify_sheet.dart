import 'dart:async';
import 'dart:ui';

import 'package:chaput/core/i18n/app_localizations.dart';
import '../../constants/app_colors.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../features/auth/data/dto/login_verify_response.dart';
import '../responsive/chaput_responsive.dart';
import 'app_text_context_menu.dart';

const Color _keyboardCornerFillColor = Color(0xFFAAADB0);

Future<LoginVerifyResponse?> showCodeVerifySheet({
  required BuildContext context,
  required String email,
  required Future<void> Function() onResend,
  required Future<LoginVerifyResponse> Function(String code) onVerify,
  Future<void> Function(String email)? onRequestCodeForEmail,
  Future<LoginVerifyResponse> Function(String email, String code)?
  onVerifyForEmail,
  ValueChanged<String>? onEmailChanged,
  bool allowEmailEdit = false,
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
          onRequestCodeForEmail: onRequestCodeForEmail,
          onVerifyForEmail: onVerifyForEmail,
          onEmailChanged: onEmailChanged,
          allowEmailEdit: allowEmailEdit,
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
              child: Container(
                color: AppColors.chaputBlack.withValues(alpha: 0.25),
              ),
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
  final Future<void> Function(String email)? onRequestCodeForEmail;
  final Future<LoginVerifyResponse> Function(String email, String code)?
  onVerifyForEmail;
  final ValueChanged<String>? onEmailChanged;
  final bool allowEmailEdit;

  const _CodeSheet({
    required this.email,
    required this.onResend,
    required this.onVerify,
    required this.onRequestCodeForEmail,
    required this.onVerifyForEmail,
    required this.onEmailChanged,
    required this.allowEmailEdit,
  });

  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _emailController = TextEditingController();
  final _focusNode = FocusNode();
  final _emailFocusNode = FocusNode();

  late String _email;
  String? _errorText;
  int _lastCodeLength = 0;

  bool _verifying = false;
  bool _editingEmail = false;
  bool _requestingEditedEmail = false;

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
    _email = widget.email.trim().toLowerCase();
    _emailController.text = _email;

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _shakeAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 10, end: -8), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 8, end: 0), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });

    _startResendCountdown();

    _controller.addListener(() {
      final raw = _controller.text;
      final onlyDigits = raw.replaceAll(RegExp(r'[^0-9]'), '');
      final clipped = onlyDigits.length > 6
          ? onlyDigits.substring(0, 6)
          : onlyDigits;

      if (clipped != raw) {
        _controller.value = TextEditingValue(
          text: clipped,
          selection: TextSelection.collapsed(offset: clipped.length),
        );
      }

      if (_errorText != null) {
        setState(() => _errorText = null);
      }

      if (clipped.length == 6 && _lastCodeLength != 6) {
        HapticFeedback.selectionClick();
      }
      _lastCodeLength = clipped.length;
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _lockTimer?.cancel();
    _controller.dispose();
    _emailController.dispose();
    _focusNode.dispose();
    _emailFocusNode.dispose();
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
    if (_verifying || _requestingEditedEmail) return;

    setState(() => _errorText = null);
    try {
      if (_isTestEmail(_email)) {
        HapticFeedback.selectionClick();
        return;
      }

      final requestForEmail = widget.onRequestCodeForEmail;
      if (requestForEmail != null) {
        await requestForEmail(_email);
      } else {
        await widget.onResend();
      }
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
    if (_requestingEditedEmail || _editingEmail) return;
    if (_lockSeconds > 0) return;
    if (_controller.text.length != 6) return;

    setState(() {
      _verifying = true;
      _errorText = null;
    });

    try {
      final verifyForEmail = widget.onVerifyForEmail;
      final res = verifyForEmail != null
          ? await verifyForEmail(_email, _controller.text)
          : await widget.onVerify(_controller.text);

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

  bool _looksLikeEmail(String value) {
    final email = value.trim();
    return email.contains('@') && email.contains('.') && email.length >= 6;
  }

  bool _isTestEmail(String value) {
    return value.trim().toLowerCase().endsWith('@test.com');
  }

  void _beginEmailEdit() {
    if (!widget.allowEmailEdit || _verifying || _requestingEditedEmail) return;
    setState(() {
      _editingEmail = true;
      _emailController.text = _email;
      _emailController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _emailController.text.length,
      );
      _errorText = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emailFocusNode.requestFocus();
    });
  }

  void _cancelEmailEdit() {
    setState(() {
      _editingEmail = false;
      _emailController.text = _email;
      _errorText = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  Future<void> _submitEditedEmail() async {
    if (_requestingEditedEmail || _verifying) return;
    final nextEmail = _emailController.text.trim().toLowerCase();
    if (!_looksLikeEmail(nextEmail)) {
      setState(() => _errorText = context.t('errors.invalid_email'));
      HapticFeedback.heavyImpact();
      return;
    }

    if (nextEmail == _email) {
      _cancelEmailEdit();
      return;
    }

    final shouldRequestCode = !_isTestEmail(nextEmail);
    setState(() {
      _requestingEditedEmail = true;
      _errorText = null;
    });

    try {
      final requestForEmail = widget.onRequestCodeForEmail;
      if (shouldRequestCode) {
        if (requestForEmail != null) {
          await requestForEmail(nextEmail);
        } else {
          await widget.onResend();
        }
      }

      if (!mounted) return;
      _resendTimer?.cancel();
      _lockTimer?.cancel();
      setState(() {
        _email = nextEmail;
        _editingEmail = false;
        _requestingEditedEmail = false;
        _errorText = null;
        _lockSeconds = 0;
        _resendSeconds = shouldRequestCode ? 30 : 0;
        _controller.clear();
        _lastCodeLength = 0;
      });
      if (shouldRequestCode) {
        _startResendCountdown(seconds: 30);
      }
      widget.onEmailChanged?.call(nextEmail);
      HapticFeedback.selectionClick();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } on DioException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _requestingEditedEmail = false;
        _errorText = _dioErrorToMessage(e);
      });
    } catch (_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _requestingEditedEmail = false;
        _errorText = context.t('errors.generic');
      });
    }
  }

  Widget _buildEmailSection() {
    final subtitleStyle = TextStyle(
      color: AppColors.chaputBlack.withValues(alpha: 0.65),
      fontSize: 13,
      height: 1.3,
    );

    if (!widget.allowEmailEdit) {
      return Text(
        context.t('code.subtitle', params: {'email': _email}),
        style: subtitleStyle,
      );
    }

    if (_editingEmail) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            enabled: !_requestingEditedEmail,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            contextMenuBuilder: appTextContextMenuBuilder,
            onSubmitted: (_) => _submitEditedEmail(),
            decoration: InputDecoration(
              hintText: context.t('common.email'),
              filled: true,
              fillColor: AppColors.chaputWhite.withValues(alpha: 0.96),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.chaputBlack.withValues(alpha: 0.14),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.chaputBlack.withValues(alpha: 0.14),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.chaputBlack.withValues(alpha: 0.42),
                  width: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: _requestingEditedEmail ? null : _cancelEmailEdit,
                child: Text(context.t('common.cancel')),
              ),
              const Spacer(),
              TextButton(
                onPressed: _requestingEditedEmail ? null : _submitEditedEmail,
                child: _requestingEditedEmail
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.t('common.send_code')),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            context.t('code.subtitle', params: {'email': _email}),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: subtitleStyle,
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: (_verifying || _requestingEditedEmail)
              ? null
              : _beginEmailEdit,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(context.t('common.edit')),
        ),
      ],
    );
  }

  String _dioErrorToMessage(DioException e) {
    final data = e.response?.data;

    // backend string döndürebilir: "invalid_code" gibi
    final s = data is String ? data : data?.toString() ?? '';

    if (s.contains('invalid_code')) return context.t('errors.code_invalid');
    if (s.contains('code_expired')) return context.t('errors.code_expired');
    if (s.contains('code_required')) return context.t('errors.code_required');
    if (s.contains('too_many_attempts')) {
      return context.t('errors.too_many_attempts');
    }
    if (s.contains('db_error')) return context.t('errors.db_error');

    final status = e.response?.statusCode;
    return context.t(
      'errors.http_status',
      params: {'status': status?.toString() ?? '-'},
    );
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
    final responsive = context.responsive;
    final keyboard = responsive.bottomSheetKeyboardInset();

    final canResend = _resendSeconds == 0 && !_verifying;
    final isLocked = _lockSeconds > 0;

    return PopScope(
      canPop: false,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (keyboard > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: keyboard + 4,
              child: const IgnorePointer(
                child: ColoredBox(color: _keyboardCornerFillColor),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    16,
                    18,
                    18 + responsive.bottomSheetInnerPadding(min: 0),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.chaputWhite.withValues(alpha: 0.88),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                    border: Border.all(
                      color: AppColors.chaputWhite.withValues(alpha: 0.6),
                    ),
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
                            color: AppColors.chaputBlack.withValues(
                              alpha: 0.12,
                            ),
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
                      _buildEmailSection(),
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
                          child: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _controller,
                            builder: (context, value, _) {
                              return _StarPinRow(
                                valueLength: value.text.length,
                              );
                            },
                          ),
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
                          contextMenuBuilder: appTextContextMenuBuilder,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(
                            color: AppColors.chaputTransparent,
                          ),
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
                          context.t(
                            'code.resend_in',
                            params: {'seconds': _lockSeconds.toString()},
                          ),
                          style: TextStyle(
                            color: AppColors.chaputBlack.withValues(
                              alpha: 0.65,
                            ),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      SizedBox(
                        height: 52,
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, value, _) {
                            return ElevatedButton(
                              onPressed:
                                  (!isLocked &&
                                      value.text.length == 6 &&
                                      !_verifying)
                                  ? _verify
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.chaputBlack,
                                disabledBackgroundColor: AppColors.chaputBlack
                                    .withValues(alpha: 0.25),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _verifying
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.chaputWhite,
                                      ),
                                    )
                                  : Text(
                                      context.t('code.verify'),
                                      style: TextStyle(
                                        color: AppColors.chaputWhite,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: canResend ? _resend : null,
                        child: Text(
                          canResend
                              ? context.t('code.resend')
                              : context.t(
                                  'code.resend_in',
                                  params: {
                                    'seconds': _resendSeconds.toString(),
                                  },
                                ),
                          style: TextStyle(
                            color: AppColors.chaputBlack.withValues(
                              alpha: canResend ? 0.9 : 0.35,
                            ),
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
        ],
      ),
    );
  }
}

class _StarPinRow extends StatelessWidget {
  final int valueLength;
  const _StarPinRow({required this.valueLength});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 36;
        final gap = available < 340 ? 8.0 : 10.0;
        final side = ((available - gap * 5) / 6).clamp(42.0, 62.0).toDouble();

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(11, (index) {
            if (index.isOdd) return SizedBox(width: gap);
            final i = index ~/ 2;
            final filled = i < valueLength;
            return SizedBox(
              width: side,
              height: side,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.chaputWhite.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: filled
                        ? AppColors.chaputBlack.withValues(alpha: 0.35)
                        : AppColors.chaputBlack.withValues(alpha: 0.12),
                  ),
                ),
                child: Center(
                  child: Text(
                    '*',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: filled
                          ? AppColors.chaputBlack
                          : AppColors.chaputBlack.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
