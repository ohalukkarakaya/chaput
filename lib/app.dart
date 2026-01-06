import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/i18n/app_localizations.dart';

class ChaputApp extends ConsumerWidget {
  const ChaputApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supported,

      // Cihaz dili: tr/de/fr ise onu seç, diğer her şey en
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        return AppLocalizations.resolve(deviceLocale);
      },
    );
  }
}