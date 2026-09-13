import 'dart:convert';
import 'dart:io';

import 'package:chaput/features/settings/presentation/screens/account_deletion_help_screen.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('all supported locales include account deletion help strings', () {
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
    };

    final dir = Directory('assets/i18n');
    final files = dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList(growable: false);

    expect(files, isNotEmpty);

    for (final file in files) {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final key in requiredKeys) {
        expect(
          json[key]?.toString().trim(),
          isNotEmpty,
          reason: '${file.path} is missing $key',
        );
      }
    }
  });
}
