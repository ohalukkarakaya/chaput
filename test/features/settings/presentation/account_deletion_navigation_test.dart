import 'package:chaput/core/i18n/app_localizations.dart';
import 'package:chaput/core/router/routes.dart';
import 'package:chaput/features/settings/application/account_deletion_flow_controller.dart';
import 'package:chaput/features/settings/application/calendly_booking.dart';
import 'package:chaput/features/settings/presentation/screens/account_deletion_help_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _closeBookingKey = Key('close-booking');
const _openSettingsKey = Key('open-settings');
const _openDeleteHelpKey = Key('open-delete-help');

void main() {
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
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supported,
      ),
    );
  }
}
