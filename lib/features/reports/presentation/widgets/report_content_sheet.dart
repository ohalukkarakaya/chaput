import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../profile/presentation/widgets/sheet_handle.dart';

class ReportContentDraft {
  const ReportContentDraft({required this.reasonCode, required this.details});

  final String reasonCode;
  final String details;
}

enum ReportTargetType { chaput, message }

Future<ReportContentDraft?> showReportContentSheet(
  BuildContext context, {
  required ReportTargetType targetType,
}) {
  return showModalBottomSheet<ReportContentDraft?>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ReportContentSheet(targetType: targetType),
  );
}

class _ReportContentSheet extends StatefulWidget {
  const _ReportContentSheet({required this.targetType});

  final ReportTargetType targetType;

  @override
  State<_ReportContentSheet> createState() => _ReportContentSheetState();
}

class _ReportContentSheetState extends State<_ReportContentSheet> {
  static const _reasonCodes = <String>[
    'spam',
    'harassment',
    'hate',
    'violence',
    'impersonation',
    'scam',
    'other',
  ];

  final TextEditingController _detailsController = TextEditingController();
  String? _reasonCode;
  String? _errorText;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final targetKey = widget.targetType == ReportTargetType.message
        ? 'message'
        : 'chaput';
    final detailsLength = _detailsController.text.trim().length;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: EdgeInsets.only(
                bottom: mq.padding.bottom > 0 ? mq.padding.bottom : 14,
              ),
              decoration: BoxDecoration(
                color: AppColors.chaputBlack.withOpacity(0.82),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(
                  color: AppColors.chaputWhite.withOpacity(0.10),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SheetHandle(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t('reports.sheet.${targetKey}_title'),
                                style: const TextStyle(
                                  color: AppColors.chaputWhite,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.t('reports.sheet.${targetKey}_body'),
                                style: TextStyle(
                                  color: AppColors.chaputWhite.withOpacity(0.7),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkResponse(
                          radius: 22,
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.chaputWhite.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: AppColors.chaputWhite,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.t('reports.sheet.reason_title'),
                        style: TextStyle(
                          color: AppColors.chaputWhite.withOpacity(0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final code in _reasonCodes)
                          _ReasonChip(
                            label: context.t('reports.reason.$code'),
                            selected: _reasonCode == code,
                            onTap: () => setState(() {
                              _reasonCode = code;
                              _errorText = null;
                            }),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _detailsController,
                      minLines: 4,
                      maxLines: 6,
                      maxLength: 500,
                      onChanged: (_) {
                        if (_errorText != null) {
                          setState(() => _errorText = null);
                        } else {
                          setState(() {});
                        }
                      },
                      style: const TextStyle(
                        color: AppColors.chaputWhite,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: context.t('reports.sheet.details_label'),
                        hintText: context.t('reports.sheet.details_hint'),
                        labelStyle: TextStyle(
                          color: AppColors.chaputWhite.withOpacity(0.72),
                        ),
                        hintStyle: TextStyle(
                          color: AppColors.chaputWhite.withOpacity(0.42),
                        ),
                        counterStyle: TextStyle(
                          color: AppColors.chaputWhite.withOpacity(0.5),
                        ),
                        filled: true,
                        fillColor: AppColors.chaputWhite.withOpacity(0.06),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: AppColors.chaputWhite.withOpacity(0.10),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: AppColors.chaputWhite.withOpacity(0.24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _errorText!,
                          style: const TextStyle(
                            color: AppColors.chaputRed200,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.chaputWhite,
                                side: BorderSide(
                                  color: AppColors.chaputWhite.withOpacity(
                                    0.20,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                context.t('common.cancel'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.chaputWhite,
                                foregroundColor: AppColors.chaputBlack,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                context.t('reports.sheet.submit'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (detailsLength > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$detailsLength/500',
                          style: TextStyle(
                            color: AppColors.chaputWhite.withOpacity(0.45),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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

  void _submit() {
    final reasonCode = _reasonCode;
    final details = _detailsController.text.trim();
    if (reasonCode == null || reasonCode.isEmpty) {
      setState(() => _errorText = context.t('reports.sheet.select_reason'));
      return;
    }
    if (details.length < 6) {
      setState(() => _errorText = context.t('reports.sheet.min_details'));
      return;
    }
    Navigator.of(
      context,
    ).pop(ReportContentDraft(reasonCode: reasonCode, details: details));
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.chaputWhite
              : AppColors.chaputWhite.withOpacity(0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.chaputWhite
                : AppColors.chaputWhite.withOpacity(0.10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.chaputBlack : AppColors.chaputWhite,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
