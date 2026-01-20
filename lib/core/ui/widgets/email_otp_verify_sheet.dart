import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef VerifyResult = ({bool ok, String? errorText, int? lockSeconds});

Future<bool?> showEmailOtpVerifySheet({
  required BuildContext context,
  required String email,
  required Future<void> Function() onResend,
  required Future<VerifyResult> Function(String code) onVerify,
}) {
  return showModalBottomSheet<bool?>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.transparent,
    builder: (_) {
      return _BlurBarrier(
        onClose: () => Navigator.of(context).pop(false),
        child: _EmailOtpSheet(
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
  final VoidCallback onClose;
  const _BlurBarrier({required this.child, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(color: Colors.black.withOpacity(0.25)),
            ),
          ),
        ),
        Align(alignment: Alignment.bottomCenter, child: child),
      ],
    );
  }
}

class _EmailOtpSheet extends StatefulWidget {
  final String email;
  final Future<void> Function() onResend;
  final Future<VerifyResult> Function(String code) onVerify;

  const _EmailOtpSheet({
    required this.email,
    required this.onResend,
    required this.onVerify,
  });

  @override
  State<_EmailOtpSheet> createState() => _EmailOtpSheetState();
}

class _EmailOtpSheetState extends State<_EmailOtpSheet> with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  String _code = '';
  String? _errorText;

  bool _verifying = false;

  Timer? _resendTimer;
  int _resendSeconds = 60;

  Timer? _lockTimer;
  int _lockSeconds = 0;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
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
        if (_errorText != null) _errorText = null;
      });

      if (_code.length == 6) HapticFeedback.selectionClick();
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

  void _startResendCountdown({int seconds = 60}) {
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
      _startResendCountdown(seconds: 60);
    } catch (_) {
      HapticFeedback.heavyImpact();
      setState(() => _errorText = 'Kod gönderilemedi. Tekrar dene.');
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

      if (res.ok) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      _shakeController.forward(from: 0);
      setState(() => _errorText = res.errorText ?? 'Kod doğrulanamadı.');

      if (res.lockSeconds != null && res.lockSeconds! > 0) {
        _startLockCountdown(res.lockSeconds!);
      }
    } catch (_) {
      HapticFeedback.heavyImpact();
      setState(() => _errorText = 'Bir şey ters gitti. Tekrar dene.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
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
                color: Colors.white.withOpacity(0.88),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                border: Border.all(color: Colors.white.withOpacity(0.6)),
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
                        color: Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Kodu gir',
                    style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'We sent a code to ${widget.email}',
                    style: TextStyle(color: Colors.black.withOpacity(0.65), fontSize: 13, height: 1.3),
                  ),
                  const SizedBox(height: 14),

                  AnimatedBuilder(
                    animation: _shakeAnimation,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: child,
                    ),
                    child: Opacity(
                      opacity: isLocked ? 0.6 : 1.0,
                      child: _StarPinRow(valueLength: _code.length),
                    ),
                  ),

                  SizedBox(
                    height: 1,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: !isLocked,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(border: InputBorder.none),
                      style: const TextStyle(color: Colors.transparent),
                      cursorColor: Colors.transparent,
                      enableInteractiveSelection: false,
                      showCursor: false,
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (_errorText != null) ...[
                    Text(_errorText!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                  ] else
                    const SizedBox(height: 4),

                  if (isLocked) ...[
                    Text(
                      'Tekrar denemek için ${_lockSeconds}s bekle',
                      style: TextStyle(color: Colors.black.withOpacity(0.65), fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                  ],

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (!isLocked && _code.length == 6 && !_verifying) ? _verify : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        disabledBackgroundColor: Colors.black.withOpacity(0.25),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _verifying
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : const Text('Verify', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: canResend ? _resend : null,
                    child: Text(
                      canResend ? 'Resend' : 'Resend in ${_resendSeconds}s',
                      style: TextStyle(
                        color: Colors.black.withOpacity(canResend ? 0.9 : 0.35),
                        fontWeight: FontWeight.w800,
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
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: filled ? Colors.black.withOpacity(0.35) : Colors.black.withOpacity(0.12),
              ),
            ),
            child: Center(
              child: Text(
                '*',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: filled ? Colors.black : Colors.black.withOpacity(0.25),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}