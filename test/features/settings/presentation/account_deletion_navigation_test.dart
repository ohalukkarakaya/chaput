import 'dart:async';

import 'package:chaput/core/i18n/app_localizations.dart';
import 'package:chaput/core/router/routes.dart';
import 'package:chaput/core/storage/secure_storage_provider.dart';
import 'package:chaput/features/me/application/me_controller.dart';
import 'package:chaput/features/me/domain/me_models.dart';
import 'package:chaput/features/notifications/application/push_token_registrar.dart';
import 'package:chaput/features/settings/data/account_api.dart';
import 'package:chaput/features/settings/application/account_deletion_flow_controller.dart';
import 'package:chaput/features/settings/application/calendly_booking.dart';
import 'package:chaput/features/settings/presentation/screens/account_deletion_help_screen.dart';
import 'package:chaput/features/settings/presentation/screens/settings_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _closeBookingKey = Key('close-booking');
const _openSettingsKey = Key('open-settings');
const _openDeleteHelpKey = Key('open-delete-help');
late AppLocalizations _localizations;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Asset decoding uses an isolate; complete it outside the widget fake clock.
    _localizations = await AppLocalizations.load(const Locale('en'));
  });

  testWidgets(
    'delayed deletion after meeting offer clears session and opens onboarding',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({
        'access_token': 'test-access',
        'refresh_token': 'test-refresh',
        'user_id': 'test-user',
      });
      final api = _DelayedDeleteApi();
      late _PendingPushCleanup push;
      final container = ProviderContainer(
        overrides: [
          accountApiProvider.overrideWithValue(api),
          meControllerProvider.overrideWith(_TestMeController.new),
          pushTokenRegistrarProvider.overrideWith((ref) {
            return push = _PendingPushCleanup(ref);
          }),
        ],
      );
      addTearDown(container.dispose);
      await container.read(meControllerProvider.future);
      final router = GoRouter(
        initialLocation: Routes.settings,
        routes: [
          GoRoute(
            path: Routes.settings,
            builder: (_, _) => const SettingsScreen(),
          ),
          GoRoute(
            path: Routes.accountDeletionHelp,
            builder: (_, state) => AccountDeletionHelpScreen(
              reason: (state.extra as Map)['reason'] as String,
            ),
          ),
          GoRoute(
            path: Routes.onboarding,
            builder: (_, _) => const Scaffold(body: Text('onboarding-screen')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        _LocalizedRouterApp(router: router, container: container),
      );
      await tester.pumpAndSettle();
      final close = find.text('close it permanently');
      await tester.ensureVisible(close);
      await tester.tap(close);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'test.user');
      await tester.enterText(
        find.byType(TextField).at(1),
        'Removing my test account',
      );
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete my account anyway'));
      await tester.pumpAndSettle();

      expect(api.reason, 'Removing my test account');
      api.response.complete();
      await tester.pumpAndSettle();

      expect(find.text('onboarding-screen'), findsOneWidget);
      expect(find.text('Failed to close account.'), findsNothing);
      expect(router.canPop(), isFalse);
      final storage = container.read(tokenStorageProvider);
      expect(await storage.readAccessToken(), isNull);
      expect(await storage.readRefreshToken(), isNull);
      expect(await storage.readUserId(), isNull);
      expect(push.serverSide, isFalse);
      push.completion.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'account deletion booking exit lands on profile and clears deletion flow',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(accountDeletionFlowControllerProvider.notifier)
          .setPending(reason: 'I need direct help first.');

      CalendlyBookingRequest? capturedRequest;
      final router = GoRouter(
        initialLocation: Routes.profilePath('user-123'),
        routes: [
          GoRoute(
            path: '/profile/:userId',
            builder: (context, state) => Scaffold(
              body: Column(
                children: [
                  Text('profile-${state.pathParameters['userId']}'),
                  TextButton(
                    key: _openSettingsKey,
                    onPressed: () => context.push(Routes.settings),
                    child: const Text('open-settings'),
                  ),
                ],
              ),
            ),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (context, _) => Scaffold(
              body: TextButton(
                key: _openDeleteHelpKey,
                onPressed: () => context.push(
                  Routes.accountDeletionHelp,
                  extra: {'reason': 'I need help before deciding.'},
                ),
                child: const Text('open-delete-help'),
              ),
            ),
          ),
          GoRoute(
            path: Routes.accountDeletionHelp,
            builder: (_, _) => const AccountDeletionHelpScreen(
              reason: 'I need help before deciding.',
            ),
          ),
          GoRoute(
            path: Routes.calendlyBooking,
            builder: (context, state) {
              capturedRequest = state.extra as CalendlyBookingRequest?;
              return Scaffold(
                body: TextButton(
                  key: _closeBookingKey,
                  onPressed: () => context.pop(),
                  child: const Text('close-booking'),
                ),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        _LocalizedRouterApp(router: router, container: container),
      );
      await tester.pumpAndSettle();

      expect(find.text('profile-user-123'), findsOneWidget);

      await tester.tap(find.byKey(_openSettingsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_openDeleteHelpKey));
      await tester.pumpAndSettle();

      expect(find.text('Before you go...'), findsOneWidget);
      expect(
        container
            .read(accountDeletionFlowControllerProvider)
            .hasPendingDeletion,
        isTrue,
      );

      await tester.tap(find.text('Book a free 10 minute call'));
      await tester.pumpAndSettle();

      expect(capturedRequest?.source, CalendlyBookingSource.accountDeletion);
      expect(
        container
            .read(accountDeletionFlowControllerProvider)
            .hasPendingDeletion,
        isFalse,
      );
      expect(find.text('Before you go...'), findsNothing);
      expect(find.byKey(_closeBookingKey), findsOneWidget);

      await tester.tap(find.byKey(_closeBookingKey));
      await tester.pumpAndSettle();

      expect(find.text('profile-user-123'), findsOneWidget);
      expect(find.text('Before you go...'), findsNothing);
      expect(find.text('Delete my account anyway'), findsNothing);
    },
  );
}

class _DelayedDeleteApi extends AccountApi {
  _DelayedDeleteApi() : super(Dio());
  final response = Completer<void>();
  String? reason;

  @override
  Future<void> deleteMeHard({required String reason}) {
    this.reason = reason;
    return response.future;
  }
}

class _TestMeController extends MeController {
  @override
  Future<MeResponse?> build() async => MeResponse.fromJson({
    'ok': true,
    'user': {
      'user_id': 'test-user',
      'username': 'test.user',
      'full_name': 'Test User',
      'default_avatar': 'f/9cd2bd0f55/42520e5cbb',
    },
    'subscription': <String, dynamic>{},
    'balances': <String, dynamic>{},
    'secret_ad': <String, dynamic>{},
  });
}

class _PendingPushCleanup extends PushTokenRegistrar {
  _PendingPushCleanup(super.ref);
  final completion = Completer<void>();
  bool? serverSide;

  @override
  Future<void> unregisterCurrentDevice({bool serverSide = true}) {
    this.serverSide = serverSide;
    return completion.future;
  }
}

class _LocalizedRouterApp extends StatelessWidget {
  const _LocalizedRouterApp({required this.router, required this.container});

  final GoRouter router;
  final ProviderContainer container;

  @override
  Widget build(BuildContext context) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: const [
          _LoadedLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supported,
      ),
    );
  }
}

class _LoadedLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _LoadedLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(_localizations);

  @override
  bool shouldReload(_LoadedLocalizationsDelegate old) => false;
}
