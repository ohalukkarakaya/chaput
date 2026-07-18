import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import 'sheet_handle.dart';

class EmptyChaputSheet extends StatelessWidget {
  final String message;
  final InlineSpan? messageSpan;
  final double height;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onActionTap;
  final Color? actionColor;
  final Color? actionForegroundColor;
  final bool actionEnabled;
  final bool actionLoading;

  const EmptyChaputSheet({
    super.key,
    required this.message,
    this.messageSpan,
    required this.height,
    this.actionLabel,
    this.actionIcon,
    this.onActionTap,
    this.actionColor,
    this.actionForegroundColor,
    this.actionEnabled = true,
    this.actionLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasAction = actionLabel != null && actionLabel!.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.chaputBlack.withOpacity(0.80),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: AppColors.chaputWhite.withOpacity(0.10)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                const SizedBox(height: 2),
                const SheetHandle(),
                const SizedBox(height: 10),
                Expanded(
                  child: Center(
                    child: Text.rich(
                      messageSpan ?? TextSpan(text: message),
                      textAlign: TextAlign.center,
                      maxLines: hasAction || messageSpan != null ? 3 : 2,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        color: AppColors.chaputWhite.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (hasAction) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (actionEnabled && !actionLoading)
                          ? onActionTap
                          : null,
                      icon: actionLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.chaputWhite,
                                ),
                              ),
                            )
                          : Icon(actionIcon ?? Icons.arrow_forward_rounded),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: AppColors.chaputWhite.withOpacity(
                          0.10,
                        ),
                        foregroundColor:
                            actionForegroundColor ?? AppColors.chaputWhite,
                        disabledBackgroundColor: AppColors.chaputWhite
                            .withOpacity(0.06),
                        disabledForegroundColor: AppColors.chaputWhite
                            .withOpacity(0.55),
                        side: BorderSide(
                          color: AppColors.chaputWhite.withOpacity(0.22),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      label: Text(
                        actionLabel!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
