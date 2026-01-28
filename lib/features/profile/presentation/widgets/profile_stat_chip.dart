import 'package:flutter/material.dart';

class ProfileStatChip extends StatelessWidget {
  const ProfileStatChip({
    super.key,
    required this.value,
    required this.label,
    this.onTap,
  });

  final int value;
  final String label;
  final VoidCallback? onTap;

  String _compact(int n) {
    if (n >= 1000000000) return '${(n / 1000000000).toStringAsFixed(1).replaceAll('.0', '')}B';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final v = _compact(value);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          constraints: const BoxConstraints(minHeight: 28),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                v,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
