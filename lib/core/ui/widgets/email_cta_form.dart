import 'dart:ui';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../i18n/app_localizations.dart';
import 'app_text_context_menu.dart';
import 'glass_cta_button.dart';

class EmailCtaForm extends StatefulWidget {
  final TextEditingController controller;
  final String? hint;
  final String? buttonText;
  final bool isLoading;
  final Future<void> Function() onSubmit;
  final bool enabled;
  final String? errorText;
  final int shakeSignal;

  const EmailCtaForm({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.hint,
    this.buttonText,
    this.isLoading = false,
    this.enabled = true,
    this.errorText,
    this.shakeSignal = 0,
  });

  @override
  State<EmailCtaForm> createState() => _EmailCtaFormState();
}

class _EmailCtaFormState extends State<EmailCtaForm>
    with SingleTickerProviderStateMixin {
  static const double _radius = 18;
  static const double _fieldHeight = 52;
  static const double _buttonHeight = 52;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _shakeAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 0, end: -9), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -9, end: 9), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 9, end: -7), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -7, end: 7), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 7, end: 0), weight: 1),
      ],
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant EmailCtaForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shakeSignal != oldWidget.shakeSignal) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = widget.enabled && !widget.isLoading;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                height: _fieldHeight,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.chaputWhite.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(_radius),
                  border: Border.all(
                    color: widget.errorText == null
                        ? AppColors.chaputWhite.withOpacity(0.55)
                        : AppColors.chaputMaterialRed.withOpacity(0.45),
                    width: widget.errorText == null ? 1 : 1.4,
                  ),
                ),
                child: TextField(
                  controller: widget.controller,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  contextMenuBuilder: appTextContextMenuBuilder,
                  onSubmitted: (_) async {
                    if (!canSubmit) return;
                    await widget.onSubmit();
                  },
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: widget.hint ?? context.t('common.email'),
                    hintStyle: TextStyle(
                      color: AppColors.chaputBlack.withOpacity(0.45),
                    ),
                    prefixIcon: Icon(
                      Icons.mail_outline,
                      color: widget.errorText == null
                          ? AppColors.chaputBlack.withOpacity(0.55)
                          : AppColors.chaputMaterialRed,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  style: const TextStyle(
                    color: AppColors.chaputBlack,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeOut,
            child: widget.errorText == null
                ? const SizedBox(height: 10)
                : Padding(
                    key: ValueKey(widget.errorText),
                    padding: const EdgeInsets.only(top: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.chaputMaterialRed.withOpacity(
                              0.10,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.chaputMaterialRed.withOpacity(
                                0.24,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.error_outline_rounded,
                                  size: 18,
                                  color: AppColors.chaputMaterialRed,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.errorText!,
                                  style: const TextStyle(
                                    color: AppColors.chaputMaterialRed,
                                    fontSize: 13,
                                    height: 1.35,
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
          ),
          GlassCtaButton(
            text: widget.buttonText ?? context.t('common.continue'),
            isLoading: widget.isLoading,
            enabled: canSubmit,
            height: _buttonHeight,
            radius: _radius,
            onTap: widget.onSubmit,
          ),
        ],
      ),
    );
  }
}
