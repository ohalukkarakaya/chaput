import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/i18n/app_localizations.dart';
import 'package:chaput/core/i18n/app_localizations.dart';
class ComposerOptionsSheet extends StatelessWidget {
  const ComposerOptionsSheet({
    super.key,
    required this.anonEnabled,
    required this.highlightEnabled,
    required this.onToggleAnon,
    required this.onToggleHighlight,
    this.onPaywallAnon,
    this.onPaywallBoost,
  });

  final bool anonEnabled;
  final bool highlightEnabled;

  final ValueChanged<bool> onToggleAnon;
  final ValueChanged<bool> onToggleHighlight;

  final VoidCallback? onPaywallAnon;
  final VoidCallback? onPaywallBoost;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.chaputBlack.withOpacity(0.70),
            border: Border.all(color: AppColors.chaputWhite.withOpacity(0.10)),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 10,
              bottom: (bottomInset > 0 ? bottomInset : 12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ComposerOptionTile(
                  title: context.t('chat.option_anon_title'),
                  subtitle: context.t('chat.option_anon_sub'),
                  value: anonEnabled,
                  onChanged: onToggleAnon,
                  onBlocked: onPaywallAnon,
                ),
                const SizedBox(height: 6),
                _ComposerOptionTile(
                  title: context.t('chat.option_highlight_title'),
                  subtitle: context.t('chat.option_highlight_sub'),
                  value: highlightEnabled,
                  onChanged: onToggleHighlight,
                  onBlocked: onPaywallBoost,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerOptionTile extends StatelessWidget {
  const _ComposerOptionTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.onBlocked,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onBlocked;

  void _handleToggle() {
    if (onBlocked != null) {
      onBlocked!();
      return;
    }
    onChanged(!value);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chaputTransparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _handleToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.chaputWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.chaputWhite70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              Transform.scale(
                scale: 0.95,
                child: Switch(
                  value: value,
                  onChanged: (next) {
                    if (onBlocked != null) {
                      onBlocked!();
                      return;
                    }
                    onChanged(next);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
