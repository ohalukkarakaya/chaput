import 'package:chaput/core/ui/responsive/chaput_responsive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ChaputResponsive> _pumpResponsive(
  WidgetTester tester, {
  required TargetPlatform platform,
  Size size = const Size(390, 844),
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewPadding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) async {
  debugDefaultTargetPlatformOverride = platform;

  ChaputResponsive? responsive;
  try {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: padding,
          viewPadding: viewPadding,
          viewInsets: viewInsets,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              responsive = context.responsive;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
  return responsive!;
}

void main() {
  testWidgets('caps iOS home indicator for bottom-fixed controls', (
    tester,
  ) async {
    final responsive = await _pumpResponsive(
      tester,
      platform: TargetPlatform.iOS,
      padding: const EdgeInsets.only(bottom: 34),
      viewPadding: const EdgeInsets.only(bottom: 34),
    );

    expect(responsive.keyboardOpen, isFalse);
    expect(responsive.bottomSafeInsetForControls(), 16);
    expect(responsive.bottomFixedOffset(base: 10), 26);
    expect(responsive.bottomSheetInnerPadding(), 24);
  });

  testWidgets('keeps Android navigation bar inset for bottom-fixed controls', (
    tester,
  ) async {
    final responsive = await _pumpResponsive(
      tester,
      platform: TargetPlatform.android,
      padding: const EdgeInsets.only(bottom: 48),
      viewPadding: const EdgeInsets.only(bottom: 48),
    );

    expect(responsive.bottomSafeInsetForControls(), 48);
    expect(responsive.bottomFixedOffset(base: 10), 58);
    expect(responsive.bottomSheetInnerPadding(), 48);
  });

  testWidgets('uses keyboard inset when the keyboard is open', (tester) async {
    final responsive = await _pumpResponsive(
      tester,
      platform: TargetPlatform.iOS,
      padding: const EdgeInsets.only(bottom: 34),
      viewPadding: const EdgeInsets.only(bottom: 34),
      viewInsets: const EdgeInsets.only(bottom: 320),
    );

    expect(responsive.keyboardOpen, isTrue);
    expect(responsive.bottomSafeInsetForControls(), 0);
    expect(responsive.bottomFixedOffset(base: 10), 330);
    expect(responsive.bottomSheetKeyboardInset(), 320);
    expect(responsive.bottomSheetInnerPadding(), 12);
  });

  testWidgets(
    'adds a small Android gesture fallback when no bottom inset exists',
    (tester) async {
      final responsive = await _pumpResponsive(
        tester,
        platform: TargetPlatform.android,
      );

      expect(responsive.bottomSafeInsetForControls(), 10);
      expect(responsive.bottomFixedOffset(base: 16), 26);
      expect(responsive.bottomSheetInnerPadding(), 12);
    },
  );

  test('classifies phone, foldable and tablet widths', () {
    expect(ChaputResponsive.classifyWidth(320), ChaputWindowClass.small);
    expect(ChaputResponsive.classifyWidth(390), ChaputWindowClass.normal);
    expect(ChaputResponsive.classifyWidth(700), ChaputWindowClass.large);
    expect(ChaputResponsive.classifyWidth(900), ChaputWindowClass.foldable);
    expect(ChaputResponsive.classifyWidth(1200), ChaputWindowClass.tablet);
  });
}
