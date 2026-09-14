import 'dart:ui';

import 'package:flutter/material.dart';

/// Keeps the shared backdrop identity stable across typing and sheet rebuilds.
/// Children must occupy separate, non-overlapping areas (the thread PageView).
class ChaputSheetGroup extends StatefulWidget {
  const ChaputSheetGroup({super.key, required this.child});

  final Widget child;

  @override
  State<ChaputSheetGroup> createState() => _ChaputSheetGroupState();
}

class _ChaputSheetGroupState extends State<ChaputSheetGroup> {
  final _backdropKey = BackdropKey();

  @override
  Widget build(BuildContext context) {
    return BackdropGroup(backdropKey: _backdropKey, child: widget.child);
  }
}

/// A clipped, black frosted surface for Chaput panels and their menus.
class ChaputSheetSurface extends StatelessWidget {
  const ChaputSheetSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(22)),
    this.grouped = false,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Only opt in for non-overlapping pages inside the same BackdropGroup.
  /// Modal menus use their own backdrop because they overlap the thread sheet.
  final bool grouped;

  static final ImageFilter _blur = ImageFilter.blur(sigmaX: 8, sigmaY: 8);
  static const _tint = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xB8000000), Color(0xD6000000)],
  );

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final decoration = DecoratedBox(
      decoration: BoxDecoration(
        color: highContrast ? Colors.black : null,
        gradient: highContrast ? null : _tint,
        borderRadius: borderRadius,
        border: Border.all(color: const Color(0x24FFFFFF)),
      ),
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Keep filtering bounded to the panel. Foreground scrolling and
          // typing can repaint independently of the background decoration.
          Positioned.fill(
            child: grouped
                ? BackdropFilter.grouped(
                    filter: _blur,
                    enabled: !highContrast,
                    child: decoration,
                  )
                : BackdropFilter(
                    filter: _blur,
                    enabled: !highContrast,
                    child: decoration,
                  ),
          ),
          RepaintBoundary(child: child),
        ],
      ),
    );
  }
}
