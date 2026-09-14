import 'dart:io';

import 'package:chaput/core/i18n/app_localizations.dart';
import 'package:chaput/core/router/route_observer.dart';
import 'package:chaput/core/theme/app_theme.dart';
import 'package:chaput/features/settings/application/photo_upload_preparer.dart';
import 'package:chaput/features/settings/presentation/screens/photo_crop_screen.dart';
import 'package:chaput/features/feedback/application/app_feedback_service.dart';
import 'package:chaput/features/feedback/data/app_feedback_api.dart';
import 'package:chaput/features/feedback/presentation/widgets/global_feedback_trigger.dart';
import 'package:dio/dio.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late String path;

  setUpAll(() async {
    // Keep cached localization futures outside individual tests' fake clocks.
    await AppLocalizations.load(const Locale('tr'));
    await GlobalMaterialLocalizations.delegate.load(const Locale('tr'));
    await GlobalCupertinoLocalizations.delegate.load(const Locale('tr'));
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('photo-crop-test-');
    path = '${directory.path}/photo.png';
    final source = img.Image(width: 200, height: 100);
    for (final pixel in source) {
      pixel.setRgb(
        pixel.x < 100 ? 255 : 0,
        pixel.y * 2,
        pixel.x < 100 ? 0 : 255,
      );
    }
    await File(path).writeAsBytes(img.encodePng(source));
  });

  tearDown(() => directory.delete(recursive: true));

  Future<void> openCrop(
    WidgetTester tester, {
    required void Function(PreparedPhotoUpload?) onResult,
    String? sourcePath,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [GoRoute(path: '/settings', builder: (_, _) => const SizedBox())],
    );
    addTearDown(router.dispose);
    final routeObserver = ChaputRouteObserver();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appFeedbackServiceProvider.overrideWithValue(
            AppFeedbackService(AppFeedbackApi(Dio())),
          ),
        ],
        child: BetterFeedback(
          child: MaterialApp(
            navigatorObservers: [routeObserver],
            theme: AppTheme.light(),
            locale: const Locale('tr'),
            supportedLocales: AppLocalizations.supported,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: GlobalFeedbackTrigger(router: router, child: child!),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async => onResult(
                    await showPhotoCropScreen(
                      context,
                      path: sourcePath ?? path,
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await waitFor(tester, () => find.text('Open').evaluate().isNotEmpty);
    await tester.pumpAndSettle();
    final backgroundElement = tester.element(find.text('Open'));
    final backgroundRoute = ModalRoute.of(backgroundElement)!;
    await tester.tap(find.text('Open'));
    await tester.pump();
    await waitFor(
      tester,
      () =>
          find.byKey(const Key('photo-crop-viewport')).evaluate().isNotEmpty ||
          find.byIcon(Icons.broken_image_outlined).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    expect(
      routeObserver.isCoveredByPageRoute(backgroundRoute),
      isFalse,
      reason: 'The crop overlay must not trigger profile tree suspension.',
    );
    expect(
      tester.element(find.text('Open')),
      same(backgroundElement),
      reason: 'The underlying page must remain mounted and onstage.',
    );
  }

  testWidgets('drag, zoom, reset and confirm return the selected square', (
    tester,
  ) async {
    PreparedPhotoUpload? result;
    await openCrop(tester, onResult: (value) => result = value);
    final slider = find.byType(Slider);
    await tester.tapAt(tester.getCenter(slider));
    await tester.pump();
    expect(tester.widget<Slider>(slider).value, greaterThan(1));
    await tester.tap(find.text('Sıfırla'));
    await tester.pump();
    expect(tester.widget<Slider>(slider).value, 1);
    final viewport = find.byKey(const Key('photo-crop-viewport'));
    await tester.drag(viewport, Offset(-tester.getSize(viewport).width, 0));
    await tester.pump();
    await tester.tap(find.text('Fotoğrafı kullan'));
    await waitFor(tester, () => result != null);
    await tester.pumpAndSettle();
    final output = img.decodeJpg(result!.bytes)!;
    expect(output.width, output.height);
    expect(output.getPixel(5, 50).b, greaterThan(240));
    expect(output.getPixel(95, 50).b, greaterThan(240));
    expect(find.byType(PhotoCropScreen), findsNothing);
  });

  testWidgets(
    'two fingers zoom in and out, then vertical dragging moves the photo',
    (tester) async {
      PreparedPhotoUpload? result;
      await openCrop(tester, onResult: (value) => result = value);
      final viewport = find.byKey(const Key('photo-crop-viewport'));
      final center = tester.getCenter(viewport);
      final first = await tester.startGesture(
        center - const Offset(90, 0),
        pointer: 1,
      );
      final second = await tester.startGesture(
        center + const Offset(90, 0),
        pointer: 2,
      );
      await first.moveTo(center - const Offset(110, 0));
      await second.moveTo(center + const Offset(110, 0));
      await tester.pump();
      await first.moveTo(center - const Offset(140, 0));
      await second.moveTo(center + const Offset(140, 0));
      await tester.pump();
      final zoomedIn = tester.widget<Slider>(find.byType(Slider)).value;
      expect(zoomedIn, greaterThan(1));
      await first.moveTo(center - const Offset(50, 0));
      await second.moveTo(center + const Offset(50, 0));
      await tester.pump();
      expect(
        tester.widget<Slider>(find.byType(Slider)).value,
        lessThan(zoomedIn),
      );
      expect(BetterFeedback.of(tester.element(viewport)).isVisible, isFalse);
      expect(tester.takeException(), isNull);
      await first.moveTo(center - const Offset(150, 0));
      await second.moveTo(center + const Offset(150, 0));
      await first.up();
      await second.up();
      await tester.pump();
      await tester.drag(viewport, const Offset(0, -300));
      await tester.pump();
      await tester.tap(find.text('Fotoğrafı kullan'));
      await waitFor(tester, () => result != null);
      await tester.pumpAndSettle();
      final output = img.decodeJpg(result!.bytes)!;
      expect(
        output.getPixel(output.width ~/ 2, output.height ~/ 2).g,
        greaterThan(120),
      );
    },
  );

  testWidgets(
    'closing the crop overlay reveals the same page and restores the feedback gesture',
    (tester) async {
      var returned = false;
      PreparedPhotoUpload? result;
      await openCrop(
        tester,
        onResult: (value) {
          returned = true;
          result = value;
        },
      );
      final backgroundElement = tester.element(find.text('Open'));
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(result, isNull);
      expect(tester.element(find.text('Open')), same(backgroundElement));
      final feedback = BetterFeedback.of(tester.element(find.text('Open')));
      expect(feedback.isVisible, isFalse);
      final first = await tester.startGesture(
        const Offset(95, 300),
        pointer: 1,
      );
      final second = await tester.startGesture(
        const Offset(295, 300),
        pointer: 2,
      );
      await first.moveTo(const Offset(155, 300));
      await second.moveTo(const Offset(235, 300));
      await first.up();
      await second.up();
      expect(feedback.isVisible, isTrue);
      feedback.hide();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('invalid photos show an error and cannot be confirmed', (
    tester,
  ) async {
    await openCrop(
      tester,
      sourcePath: '${directory.path}/missing.png',
      onResult: (_) {},
    );
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
    await tester.tap(find.text('Fotoğrafı kullan'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoCropScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'short landscape screens and large text keep confirmation accessible',
    (tester) async {
      await openCrop(
        tester,
        size: const Size(844, 390),
        textScale: 2,
        onResult: (_) {},
      );
      expect(find.text('Fotoğrafı kullan').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(ready(), isTrue, reason: 'The image operation did not complete');
}
