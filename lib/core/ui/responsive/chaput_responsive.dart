import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum ChaputWindowClass { small, normal, large, foldable, tablet }

@immutable
class ChaputResponsive {
  const ChaputResponsive({required this.mediaQuery, required this.platform});

  factory ChaputResponsive.of(BuildContext context) {
    return ChaputResponsive(
      mediaQuery: MediaQuery.of(context),
      platform: defaultTargetPlatform,
    );
  }

  final MediaQueryData mediaQuery;
  final TargetPlatform platform;

  Size get size => mediaQuery.size;
  EdgeInsets get padding => mediaQuery.padding;
  EdgeInsets get viewPadding => mediaQuery.viewPadding;
  EdgeInsets get viewInsets => mediaQuery.viewInsets;

  double get keyboardInset => viewInsets.bottom;
  bool get keyboardOpen => keyboardInset > 0.0;
  bool get isIOS => platform == TargetPlatform.iOS;
  bool get isAndroid => platform == TargetPlatform.android;

  ChaputWindowClass get windowClass => classifyWidth(size.width);
  bool get isTabletLike =>
      windowClass == ChaputWindowClass.foldable ||
      windowClass == ChaputWindowClass.tablet;

  static ChaputWindowClass classifyWidth(double width) {
    if (width < 360) return ChaputWindowClass.small;
    if (width < 600) return ChaputWindowClass.normal;
    if (width < 840) return ChaputWindowClass.large;
    if (width < 1024) return ChaputWindowClass.foldable;
    return ChaputWindowClass.tablet;
  }

  double get maxContentWidth {
    switch (windowClass) {
      case ChaputWindowClass.small:
      case ChaputWindowClass.normal:
        return 520;
      case ChaputWindowClass.large:
        return 640;
      case ChaputWindowClass.foldable:
      case ChaputWindowClass.tablet:
        return 720;
    }
  }

  double get horizontalGutter {
    switch (windowClass) {
      case ChaputWindowClass.small:
        return 12;
      case ChaputWindowClass.normal:
        return 16;
      case ChaputWindowClass.large:
        return 20;
      case ChaputWindowClass.foldable:
      case ChaputWindowClass.tablet:
        return 24;
    }
  }

  BoxConstraints contentWidthConstraints({double? maxWidth}) {
    return BoxConstraints(maxWidth: maxWidth ?? maxContentWidth);
  }

  double _rawBottomInset() {
    return math.max(padding.bottom, viewPadding.bottom);
  }

  double _preferredBottomInset() {
    final raw = _rawBottomInset();
    if (raw <= 0.0) return 0.0;
    if (isIOS) {
      final preferred = padding.bottom > 0.0
          ? padding.bottom
          : viewPadding.bottom;
      return preferred.clamp(0.0, 16.0).toDouble();
    }
    return raw;
  }

  double bottomSafeInsetForControls({double androidFallback = 10}) {
    if (keyboardOpen) return 0.0;
    final preferred = _preferredBottomInset();
    if (preferred > 0.0) return preferred;
    if (isAndroid) return androidFallback;
    return 0.0;
  }

  double bottomFixedOffset({double base = 0, double androidFallback = 10}) {
    if (keyboardOpen) return keyboardInset + base;
    return bottomSafeInsetForControls(androidFallback: androidFallback) + base;
  }

  EdgeInsets bottomFixedPadding({
    double base = 0,
    double androidFallback = 10,
  }) {
    return EdgeInsets.only(
      bottom: bottomFixedOffset(base: base, androidFallback: androidFallback),
    );
  }

  double bottomSheetKeyboardInset() => keyboardInset;

  double bottomSheetInnerPadding({double min = 12, double maxIOS = 24}) {
    if (keyboardOpen) return min;
    final raw = _rawBottomInset();
    if (isIOS) return math.max(min, math.min(raw, maxIOS));
    return math.max(min, raw);
  }

  double bottomSheetMaxHeight({double fraction = 0.92}) {
    final available = size.height - padding.top;
    return available * fraction.clamp(0.0, 1.0);
  }
}

extension ChaputResponsiveContext on BuildContext {
  ChaputResponsive get responsive => ChaputResponsive.of(this);
}
