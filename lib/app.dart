import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/i18n/app_localizations.dart';
import 'package:chaput/core/constants/app_colors.dart';

class ChaputApp extends ConsumerWidget {
  const ChaputApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
        theme: ThemeData(
        brightness: Brightness.light, // ✅ her zaman light
        fontFamily: 'Qanelas',
        useMaterial3: true,

        scaffoldBackgroundColor: AppColors.chaputWhite,

        colorScheme: const ColorScheme.light(
          primary: AppColors.chaputBlack,
          secondary: AppColors.chaputBlack,
          surface: AppColors.chaputWhite,
          background: AppColors.chaputWhite,
          onBackground: AppColors.chaputBlack,
          onSurface: AppColors.chaputBlack,
          onPrimary: AppColors.chaputWhite,
        )
      ),
      darkTheme: AppTheme.light(),
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