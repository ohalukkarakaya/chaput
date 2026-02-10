import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;
  final Map<String, dynamic> _map;

  AppLocalizations._(this.locale, this._map);

  static const supported = <Locale>[
    Locale('en'),
    Locale('tr'),
    Locale('de'),
    Locale('fr'),
    Locale('sv'),
    Locale('nb'),
    Locale('da'),
    Locale('fi'),
    Locale('es'),
  ];

  static const _fallbackLocale = Locale('en');

  static Locale resolve(Locale? deviceLocale) {
    final code = (deviceLocale?.languageCode ?? '').toLowerCase();
    if (code == 'tr') return const Locale('tr');
    if (code == 'de') return const Locale('de');
    if (code == 'fr') return const Locale('fr');
    if (code == 'sv') return const Locale('sv');
    if (code == 'da') return const Locale('da');
    if (code == 'fi') return const Locale('fi');
    if (code == 'es') return const Locale('es');
    if (code == 'no' || code == 'nb') return const Locale('nb');
    return _fallbackLocale; // everything else -> en
  }

  static Future<AppLocalizations> load(Locale locale) async {
    final resolved = resolve(locale);
    final fallbackRaw = await rootBundle.loadString('assets/i18n/en.json');
    final fallbackMap = jsonDecode(fallbackRaw) as Map<String, dynamic>;

    if (resolved.languageCode == 'en') {
      return AppLocalizations._(resolved, fallbackMap);
    }

    final path = 'assets/i18n/${resolved.languageCode}.json';
    final raw = await rootBundle.loadString(path);
    final map = jsonDecode(raw) as Map<String, dynamic>;

    return AppLocalizations._(resolved, {...fallbackMap, ...map});
  }

  String t(String key, {Map<String, String>? params}) {
    var value = _map[key]?.toString() ?? key;

    if (params != null && params.isNotEmpty) {
      params.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }

    return value;
  }

  static AppLocalizations of(BuildContext context) {
    final loc = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(loc != null, 'AppLocalizations not found in context');
    return loc!;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    // Biz sadece tr/de/fr explicit, diğerleri fallback en.
    final code = locale.languageCode.toLowerCase();
    return code == 'en' ||
        code == 'tr' ||
        code == 'de' ||
        code == 'fr' ||
        code == 'sv' ||
        code == 'nb' ||
        code == 'da' ||
        code == 'fi' ||
        code == 'es' ||
        code == 'no';
  }

  @override
  Future<AppLocalizations> load(Locale locale) => AppLocalizations.load(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String t(String key, {Map<String, String>? params}) => l10n.t(key, params: params);
}
