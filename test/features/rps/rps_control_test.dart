import 'package:chaput/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:chaput/features/notifications/application/notifications_controller.dart';
import 'package:chaput/features/notifications/domain/notification_item.dart';
import 'package:chaput/features/user/domain/lite_user.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:chaput/core/i18n/app_localizations.dart';
import 'package:chaput/core/network/dio_provider.dart';
import 'package:chaput/features/rps/rps_control.dart';
import 'package:chaput/features/rps/rps_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const idle = RpsGame(available: true, round: 0, status: 'idle');
const won = RpsGame(
  available: true,
  round: 1,
  status: 'complete',
  ownMove: 0,
  otherMove: 2,
  outcome: 'won',
);

class _LoadedLocale extends LocalizationsDelegate<AppLocalizations> {
  const _LoadedLocale(this.value);
  final AppLocalizations value;
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(value);
  @override
  bool shouldReload(_LoadedLocale old) => false;
}

class _InvitationNotifications extends NotificationsController {
  @override
  NotificationsState build() => NotificationsState(
    hasMore: false,
    usersById: {
      'peer': LiteUser.fromJson({
        'id': 'peer',
        'full_name': 'testt user',
        'username': 'testt.2.user',
        'default_avatar': 'f/9cd2bd0f55/2c17719516',
      }),
    },
    items: [
      AppNotification.fromJson({
        'id': 'old-result',
        'actor_id': 'peer',
        'type': 'rps_result',
        'payload': {
          'round': 6,
          'game_id': 'EXISTING',
          'own_move': 0,
          'other_move': 2,
          'outcome': 'won',
        },
      }),
      AppNotification.fromJson({
        'id': 'invite',
        'actor_id': 'peer',
        'type': 'rps_invite',
        'payload': {'round': 7},
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations locale;
  setUpAll(() async {
    locale = await AppLocalizations.load(const Locale('tr'));
    final fonts = FontLoader('Qanelas')
      ..addFont(rootBundle.load('assets/fonts/QanelasBold.otf'));
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    if (Platform.environment['RPS_VISUAL_REVIEW'] == '1' && Platform.isMacOS) {
      final emoji = FontLoader('Apple Color Emoji')
        ..addFont(
          File(
            '/System/Library/Fonts/Apple Color Emoji.ttc',
          ).readAsBytes().then((b) => b.buffer.asByteData()),
        );
      await emoji.load();
    }
  });
  late RpsGame game;
  late List<Map<String, dynamic>> moves;
  late Dio dio;
  setUp(() {
    game = idle;
    moves = [];
    dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            if (request.method == 'POST') {
              moves.add(Map<String, dynamic>.from(request.data as Map));
              game = RpsGame(
                available: true,
                gameId: game.gameId,
                round: game.status == 'invited' ? game.round : game.round + 1,
                status: game.status == 'invited' ? 'complete' : 'waiting',
                outcome: game.status == 'invited' ? 'won' : null,
                ownMove: request.data['move'],
              );
            }
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {'ok': true},
              ),
            );
          },
        ),
      );
  });
  Widget app({
    String? keyName,
    int? notificationRound,
    double width = 156,
    Widget? child,
  }) => ProviderScope(
    overrides: [
      rpsGameProvider('peer').overrideWith((ref) async => game),
      notificationsControllerProvider.overrideWith(
        _InvitationNotifications.new,
      ),
      dioProvider.overrideWithValue(dio),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      theme: ThemeData(
        fontFamily: 'Qanelas',
        textTheme: Typography.material2021().black.apply(
          fontFamily: 'Qanelas',
          fontFamilyFallback: const ['Apple Color Emoji'],
        ),
      ),
      supportedLocales: AppLocalizations.supported,
      localizationsDelegates: [
        _LoadedLocale(locale),
        ...GlobalMaterialLocalizations.delegates,
      ],
      home:
          child ??
          Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: RpsControl(
                  key: ValueKey(keyName),
                  opponentId: 'peer',
                  notificationRound: notificationRound,
                ),
              ),
            ),
          ),
    ),
  );

  testWidgets(
    'initial chooser fits beside follow on a narrow phone and sends once',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('✊ ✋ ✌️'), findsOneWidget);
      await tester.tap(find.text('✊ ✋ ✌️'));
      await tester.pumpAndSettle();
      expect(find.text('✊'), findsOneWidget);
      expect(find.text('✋'), findsOneWidget);
      expect(find.text('✌️'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('✋'));
      await tester.tap(find.text('✋'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(moves, [
        {'move': 1, 'round': 0},
      ]);
      expect(find.text('Karşı taraf bekleniyor'), findsOneWidget);
      await tester.tap(find.text('Karşı taraf bekleniyor'));
      await tester.pumpAndSettle();
      expect(moves.length, 1);
    },
  );

  testWidgets('opening rematch does not persist until a move is chosen', (
    tester,
  ) async {
    game = won;
    await tester.pumpWidget(app(keyName: 'visit1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kazandın'));
    await tester.pumpAndSettle();
    expect(find.text('✊'), findsOneWidget);
    expect(moves, isEmpty);
    await tester.pumpWidget(app(keyName: 'visit2'));
    await tester.pumpAndSettle();
    expect(find.text('Kazandın'), findsOneWidget);
    expect(find.text('✊'), findsNothing);
  });

  testWidgets('resolved rounds cannot be played from an invitation control', (
    tester,
  ) async {
    game = won;
    await tester.pumpWidget(app(notificationRound: 1, width: 210));
    await tester.pumpAndSettle();
    expect(find.text('Rövanş'), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    expect(moves, isEmpty);
  });

  testWidgets(
    'incoming invitation shows choices without exposing opponent move',
    (tester) async {
      game = const RpsGame(available: true, round: 1, status: 'invited');
      await tester.pumpWidget(app(notificationRound: 1, width: 210));
      await tester.pumpAndSettle();
      expect(find.text('seni taş kağıt makasa davet etti'), findsOneWidget);
      expect(find.text('✊'), findsOneWidget);
      expect(find.text('✋'), findsOneWidget);
      expect(find.text('✌️'), findsOneWidget);
    },
  );

  testWidgets(
    'profile choice answers the existing invitation and reveals its result',
    (tester) async {
      game = const RpsGame(
        available: true,
        round: 7,
        gameId: 'EXISTING',
        status: 'invited',
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('✊ ✋ ✌️'), findsNothing);
      await tester.tap(find.text('✊'));
      await tester.pumpAndSettle();
      expect(moves, [
        {'move': 0, 'round': 7, 'game_id': 'EXISTING'},
      ]);
      expect(game.round, 7);
      expect(find.text('Kazandın'), findsOneWidget);
    },
  );

  testWidgets(
    'invitation card keeps all three actions beside the sender on small screens',
    (tester) async {
      game = const RpsGame(
        available: true,
        round: 7,
        gameId: 'EXISTING',
        status: 'invited',
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      for (final width in [320.0, 390.0]) {
        tester.view.physicalSize = Size(width, 600);
        await tester.pumpWidget(
          app(
            child: RepaintBoundary(
              key: boundary,
              child: const NotificationsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Taş kağıt makasta kazandın'), findsOneWidget);
        expect(find.text('Rövanş'), findsNothing);
        final rock = tester.getCenter(find.text('✊'));
        final paper = tester.getCenter(find.text('✋'));
        final scissors = tester.getCenter(find.text('✌️'));
        expect(rock.dy, paper.dy);
        expect(paper.dy, scissors.dy);
        expect(
          rock.dx,
          greaterThan(tester.getTopLeft(find.text('testt user').first).dx),
        );
      }
      if (Platform.environment['RPS_VISUAL_REVIEW'] == '1') {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/chaput-rps-notification.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );

  testWidgets('unavailable and stale notification controls are hidden', (
    tester,
  ) async {
    game = const RpsGame(available: false, round: 0, status: 'idle');
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
    await tester.pumpWidget(const SizedBox());
    game = won;
    await tester.pumpWidget(app(notificationRound: 0));
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('visual review of all profile states', (tester) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final states = [
      idle,
      const RpsGame(available: true, round: 1, status: 'invited'),
      const RpsGame(available: true, round: 1, status: 'waiting', ownMove: 1),
      won,
      const RpsGame(
        available: true,
        round: 1,
        status: 'complete',
        ownMove: 2,
        otherMove: 0,
        outcome: 'lost',
      ),
      const RpsGame(
        available: true,
        round: 1,
        status: 'complete',
        ownMove: 2,
        otherMove: 2,
        outcome: 'draw',
      ),
    ];
    final boundary = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          for (var i = 0; i < states.length; i++)
            rpsGameProvider('peer$i').overrideWith((ref) async => states[i]),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          theme: ThemeData(
            fontFamily: 'Qanelas',
            textTheme: Typography.material2021().black.apply(
              fontFamily: 'Qanelas',
              fontFamilyFallback: const ['Apple Color Emoji'],
            ),
          ),
          supportedLocales: AppLocalizations.supported,
          localizationsDelegates: [
            _LoadedLocale(locale),
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: Container(
                color: const Color(0xFFEADBC7),
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < states.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            Expanded(child: RpsControl(opponentId: 'peer$i')),
                            const SizedBox(width: 8),
                            Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x99737373),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Follow',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    if (Platform.environment['RPS_VISUAL_REVIEW'] == '1') {
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/tmp/chaput-rps-ui.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  test('waiting response parser does not invent hidden moves', () {
    final parsed = RpsGame.fromJson(
      jsonDecode('{"available":true,"round":1,"status":"invited"}'),
    );
    expect(parsed.ownMove, isNull);
    expect(parsed.otherMove, isNull);
  });
}
