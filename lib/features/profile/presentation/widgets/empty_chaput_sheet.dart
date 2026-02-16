import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import 'sheet_handle.dart';

class EmptyChaputSheet extends StatelessWidget {
  final String message;
  final double height;

  const EmptyChaputSheet({
    super.key,
    required this.message,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
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
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.chaputWhite.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
