import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';

Widget chaputFeedbackBuilder(
  BuildContext context,
  OnSubmit onSubmit,
  ScrollController? scrollController,
) {
  return _ChaputFeedbackForm(
    onSubmit: onSubmit,
    scrollController: scrollController,
  );
}

class _ChaputFeedbackForm extends StatefulWidget {
  const _ChaputFeedbackForm({
    required this.onSubmit,
    required this.scrollController,
  });

  final OnSubmit onSubmit;
  final ScrollController? scrollController;

  @override
  State<_ChaputFeedbackForm> createState() => _ChaputFeedbackFormState();
}

class _ChaputFeedbackFormState extends State<_ChaputFeedbackForm> {
  late final TextEditingController _controller;
  bool _isSubmitting = false;

  bool get _canSubmit => !_isSubmitting && _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_handleChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleChanged)
      ..dispose();
    super.dispose();
  }

  void _handleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 120));

    if (!mounted) return;

    setState(() => _isSubmitting = true);

    try {
      await widget.onSubmit(_controller.text.trim());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        controller: widget.scrollController,
        physics: const ClampingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.scrollController != null)
              const Center(child: FeedbackSheetDragHandle()),

            const SizedBox(height: 10),

            Text(
              context.t('feedback.sheet_title'),
              style: textTheme.headlineMedium?.copyWith(
                color: AppColors.chaputBlack,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),

            const SizedBox(height: 18),

            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _controller.text.trim().isEmpty
                      ? AppColors.chaputBlack.withOpacity(0.18)
                      : AppColors.chaputBlack,
                  width: _controller.text.trim().isEmpty ? 1.2 : 1.6,
                ),
              ),
              child: TextField(
                controller: _controller,
                autofocus: false,
                minLines: 1,
                maxLines: 7,
                maxLength: 1200,
                cursorColor: AppColors.chaputBlack,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(
                  color: AppColors.chaputBlack87,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  height: 1.35,
                ),
                decoration: InputDecoration(
                  hintText: context.t('feedback.sheet_input_placeholder'),
                  hintStyle: TextStyle(
                    color: AppColors.chaputBlack.withOpacity(0.42),
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                  counterText: '',
                  contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.chaputBlack,
                  disabledBackgroundColor:
                  AppColors.chaputBlack.withOpacity(0.18),
                  foregroundColor: AppColors.chaputWhite,
                  disabledForegroundColor: AppColors.chaputWhite,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.chaputWhite,
                  ),
                )
                    : Text(
                  context.t('feedback.sheet_submit'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
