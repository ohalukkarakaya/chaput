import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../constants/app_colors.dart';
import '../../i18n/app_localizations.dart';
import 'package:chaput/core/i18n/app_localizations.dart';

class ShareBar extends StatefulWidget {
  const ShareBar({
    super.key,
    required this.link,
    this.title,
    this.subtitle,
    this.showShareButton = true,
  });

  final String link;
  final String? title;
  final String? subtitle;
  final bool showShareButton;

  @override
  State<ShareBar> createState() => _ShareBarState();
}

class _ShareBarState extends State<ShareBar> with SingleTickerProviderStateMixin {
  bool _copied = false;
  bool _busy = false;

  late final AnimationController _shakeCtrl;

  static const _confirmGreen = AppColors.chaputGreen; // güzel “success green” tonu

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _playConfirmHaptics() async {
    // 2x onay hissi
    HapticFeedback.selectionClick();
    await Future.delayed(const Duration(milliseconds: 70));
    HapticFeedback.selectionClick();
  }

  Future<void> _onCopy() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _copied = true;
    });

    await Clipboard.setData(ClipboardData(text: widget.link));

    // haptic + shake
    _shakeCtrl.forward(from: 0);
    await _playConfirmHaptics();

    // ✅ buraya sonra ses ekleyeceğiz
    // await _playConfirmSound();

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    setState(() {
      _copied = false;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const bg = AppColors.chaputCloudBlue;

    return AnimatedBuilder(
      animation: _shakeCtrl,
      builder: (context, child) {
        final t = _shakeCtrl.value; // 0..1
        final damp = (1 - t);
        final x = math.sin(t * math.pi * 10) * 6.0 * damp;
        return Transform.translate(offset: Offset(x, 0), child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color.lerp(bg, AppColors.chaputWhite, 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            // ✅ kopyalanınca hafif yeşil border
            color: _copied
                ? _confirmGreen.withOpacity(0.35)
                : AppColors.chaputBlack.withOpacity(0.06),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 8),
              color: AppColors.chaputBlack.withOpacity(0.06),
            ),

            // ✅ kopyalanınca glow
            if (_copied)
              BoxShadow(
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 10),
                color: _confirmGreen.withOpacity(0.20),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.title != null || widget.subtitle != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.title != null)
                    Text(
                      widget.title!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (widget.title != null && widget.subtitle != null) const SizedBox(width: 8),
                  if (widget.subtitle != null)
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        color: AppColors.chaputBlack.withOpacity(0.55),
                      ),
                    ),
                ],
              ),
            if (widget.title != null || widget.subtitle != null) const SizedBox(height: 8),

            Row(
              children: [
                // ✅ Copy -> Check (1sn), check yeşil + mini arka plan
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: _copied ? _confirmGreen.withOpacity(0.10) : AppColors.chaputTransparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    tooltip: _copied ? context.t('common.copied') : context.t('common.copy'),
                    onPressed: _busy ? null : _onCopy,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                      child: _copied
                          ? Icon(
                        Icons.check_rounded,
                        key: const ValueKey('check'),
                        color: _confirmGreen, // ✅ yeşil tik
                      )
                          : Icon(
                        Icons.copy_rounded,
                        key: const ValueKey('copy'),
                        color: AppColors.chaputBlack.withOpacity(0.85),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: SelectableText(
                    widget.link,
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.chaputBlack.withOpacity(0.68),
                    ),
                  ),
                ),

                if (widget.showShareButton) ...[
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Share.share(
                        widget.link,
                        subject: context.t('share.subject'),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.chaputBlack,
                      foregroundColor: AppColors.chaputWhite,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: Text(
                      context.t('common.share'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
