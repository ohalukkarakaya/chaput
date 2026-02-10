import 'package:flutter/material.dart';
import 'package:chaput/core/constants/app_colors.dart';

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.chaputBlack.withOpacity(0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
