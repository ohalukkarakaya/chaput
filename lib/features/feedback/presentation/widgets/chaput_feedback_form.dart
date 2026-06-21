import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.scrollController != null)
              const Center(child: FeedbackSheetDragHandle()),

            const SizedBox(height: 14),

            Text(
              context.t('feedback.sheet_title'),
              style: textTheme.headlineSmall?.copyWith(
                color: AppColors.chaputBlack,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              context.t('feedback.sheet_subtitle'),
              style: TextStyle(
                color: AppColors.chaputBlack.withOpacity(0.52),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 14),

            TextField(
              controller: _controller,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: 2,
              maxLines: 5,
              maxLength: 500,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              cursorColor: AppColors.chaputBlack,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                color: AppColors.chaputBlack87,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                height: 1.35,
              ),
              decoration: InputDecoration(
                hintText: context.t('feedback.sheet_input_placeholder'),
                hintStyle: TextStyle(
                  color: AppColors.chaputBlack.withOpacity(0.38),
                  fontWeight: FontWeight.w600,
                ),
                counterStyle: TextStyle(
                  color: AppColors.chaputBlack.withOpacity(0.45),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                filled: true,
                fillColor: const Color(0xFFF7F7F5),
                contentPadding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: AppColors.chaputBlack.withOpacity(0.16),
                    width: 1.2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(
                    color: AppColors.chaputBlack.withOpacity(0.16),
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: AppColors.chaputBlack,
                    width: 1.4,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 50,
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
                    borderRadius: BorderRadius.circular(19),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color: AppColors.chaputWhite,
                  ),
                )
                    : Text(
                  context.t('feedback.sheet_submit'),
                  style: const TextStyle(
                    fontSize: 17,
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