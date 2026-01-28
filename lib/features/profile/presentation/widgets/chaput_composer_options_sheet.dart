import 'dart:ui';

import 'package:flutter/material.dart';

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
            color: Colors.black.withOpacity(0.70),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
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
                  title: 'Kimliğini gizle',
                  subtitle: 'Bu chaput anonim görünür.',
                  value: anonEnabled,
                  onChanged: onToggleAnon,
                  onBlocked: onPaywallAnon,
                ),
                const SizedBox(height: 6),
                _ComposerOptionTile(
                  title: 'Öne çıkar',
                  subtitle: 'Daha görünür olur (plan/kredi gerekebilir).',
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
      color: Colors.transparent,
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
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
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
