import 'dart:convert';
import 'dart:io';

import 'package:chaput/core/i18n/app_localizations.dart';
import 'package:chaput/core/router/routes.dart';
import 'package:chaput/features/settings/application/account_deletion_flow_controller.dart';
import 'package:chaput/features/settings/application/calendly_booking.dart';
import 'package:chaput/features/settings/presentation/screens/settings_support_intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _openSupportKey = Key('open-support');
const _closeBookingKey = Key('close-booking');
const _completeBookingKey = Key('complete-booking');

void main() {
  test('buildChaputHelpCalendlyUri pre-fills name and email safely', () {
    final uri = buildChaputHelpCalendlyUri(
      fullName: ' Çağrı Öz ',
      email: ' person+test@example.com ',
    );

    expect(uri.scheme, 'https');
    expect(uri.host, 'calendly.com');
    expect(uri.path, '/hello-goktigin/chaput-1-1-help');
    expect(uri.queryParameters['name'], 'Çağrı Öz');
    expect(uri.queryParameters['email'], 'person+test@example.com');
    expect(uri.toString(), isNot(contains(' ')));
    expect(uri.toString(), isNot(contains('Çağrı Öz')));
  });

  test('Calendly event helpers only treat confirmed bookings as success', () {
    expect(
      isCalendlyScheduledEventMessage(
        jsonEncode({'event': 'calendly.event_scheduled'}),
      ),
      isTrue,
    );
    expect(
      isCalendlyScheduledEventMessage(
        jsonEncode({'event': 'calendly.profile_page_viewed'}),
      ),
      isFalse,
    );
    expect(isCalendlyScheduledEventMessage('not json'), isFalse);

    expect(
      isCalendlyLifecycleEventMessage(
        jsonEncode({'event': 'calendly.profile_page_viewed'}),
      ),
      isTrue,
    );
  });

  test('Calendly completion guard handles duplicate callbacks once', () {
    final guard = CalendlyBookingCompletionGuard();

    expect(guard.completed, isFalse);
    expect(guard.markCompletedOnce(), isTrue);
    expect(guard.completed, isTrue);
    expect(guard.markCompletedOnce(), isFalse);
  });

  test('account deletion flow state can be cleared after support booking', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(
      accountDeletionFlowControllerProvider.notifier,
    );
    notifier.setPending(reason: 'I need direct help first.');

    expect(
      container.read(accountDeletionFlowControllerProvider).hasPendingDeletion,
      isTrue,
    );

    notifier.clear();

    expect(
      container.read(accountDeletionFlowControllerProvider).hasPendingDeletion,
      isFalse,
    );
  });

  test(
    'all supported locales include account deletion and support strings',
    () {
      final requiredKeys = {
        'settings.delete_help_body',
        'settings.delete_help_book',
        'settings.delete_help_booking_title',
        'settings.delete_help_delete_anyway',
        'settings.delete_help_intro',
        'settings.delete_help_languages',
        'settings.delete_help_title',
        'settings.delete_help_webview_error_body',
        'settings.delete_help_webview_error_title',
        'settings.delete_help_webview_loading',
        'settings.delete_reason_helper',
        'settings.delete_reason_hint',
        'settings.delete_reason_label',
        'settings.delete_reason_min',
        'settings.delete_reason_required',
        'settings.row_live_support',
        'settings.row_live_support_sub',
        'settings.support_booked_body',
        'settings.support_booked_title',
        'settings.support_intro_body',
        'settings.support_intro_book',
        'settings.support_intro_not_now',
        'settings.support_intro_question',
        'settings.support_intro_title',
      };

      final dir = Directory('assets/i18n');
      final files = dir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList(growable: false);

      expect(files, isNotEmpty);

      for (final file in files) {
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        for (final key in requiredKeys) {
          expect(
            json[key]?.toString().trim(),
            isNotEmpty,
            reason: '${file.path} is missing $key',
          );
        }
      }
    },
  );

  testWidgets('settings support closes intro before booking exit and success', (
    tester,
  ) async {
    CalendlyBookingRequest? capturedRequest;
    final router = _settingsSupportRouter(
      onBookingRoute: (context, state) {
        capturedRequest = state.extra as CalendlyBookingRequest?;
        return _DummyBookingScreen(
          onClose: () => context.pop(),
          onComplete: () => context.pop(true),
        );
      },
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_LocalizedRouterApp(router: router));
    await tester.pumpAndSettle();
    router.go(Routes.settings);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_openSupportKey));
    await tester.pumpAndSettle();
    expect(find.text('Talk to us'), findsOneWidget);

    await tester.tap(find.text('Book a 10 minute call'));
    await tester.pumpAndSettle();

    expect(capturedRequest?.source, CalendlyBookingSource.settingsSupport);

    await tester.tap(find.byKey(_closeBookingKey));
    await tester.pumpAndSettle();

    expect(find.text('settings-screen'), findsOneWidget);
    expect(find.text('Talk to us'), findsNothing);

    await tester.tap(find.byKey(_openSupportKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book a 10 minute call'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_completeBookingKey));
    await tester.pumpAndSettle();

    expect(find.text('settings-screen'), findsOneWidget);
    expect(find.text('Talk to us'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

GoRouter _settingsSupportRouter({
  required Widget Function(BuildContext, GoRouterState) onBookingRoute,
}) {
  return GoRouter(
    initialLocation: Routes.settings,
    routes: [
      GoRoute(
        path: Routes.settings,
        builder: (context, _) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: _openSupportKey,
              onPressed: () => context.push<bool>(Routes.settingsSupport),
              child: const Text('settings-screen'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: Routes.settingsSupport,
        builder: (_, _) => const SettingsSupportIntroScreen(),
      ),
      GoRoute(path: Routes.calendlyBooking, builder: onBookingRoute),
    ],
  );
}

class _LocalizedRouterApp extends StatelessWidget {
  const _LocalizedRouterApp({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        key: ValueKey(router),
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

class _DummyBookingScreen extends StatelessWidget {
  const _DummyBookingScreen({required this.onClose, required this.onComplete});

  final VoidCallback onClose;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextButton(
            key: _closeBookingKey,
            onPressed: onClose,
            child: const Text('close-booking'),
          ),
          TextButton(
            key: _completeBookingKey,
            onPressed: onComplete,
            child: const Text('complete-booking'),
          ),
        ],
      ),
    );
  }
}
