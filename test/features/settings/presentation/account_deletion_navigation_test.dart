import 'package:chaput/core/i18n/app_localizations.dart';
import 'package:chaput/core/router/routes.dart';
import 'package:chaput/features/settings/application/calendly_booking.dart';
import 'package:chaput/features/settings/presentation/screens/account_deletion_help_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _closeBookingKey = Key('close-booking');

void main() {
  testWidgets(
    'account deletion booking exit returns to Before you go without success',
    (tester) async {
      CalendlyBookingRequest? capturedRequest;
      final router = GoRouter(
        initialLocation: Routes.accountDeletionHelp,
        routes: [
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

      await tester.pumpWidget(_LocalizedRouterApp(router: router));
      await tester.pumpAndSettle();

      expect(find.text('Before you go...'), findsOneWidget);

      await tester.tap(find.text('Book a free 10 minute call'));
      await tester.pumpAndSettle();

      expect(capturedRequest?.source, CalendlyBookingSource.accountDeletion);
      expect(find.byKey(_closeBookingKey), findsOneWidget);

      await tester.tap(find.byKey(_closeBookingKey));
      await tester.pumpAndSettle();

      expect(find.text('Before you go...'), findsOneWidget);
      expect(find.text('Delete my account anyway'), findsOneWidget);
    },
  );
}

class _LocalizedRouterApp extends StatelessWidget {
  const _LocalizedRouterApp({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
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
