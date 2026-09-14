import 'package:chaput/core/i18n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:chaput/features/profile/presentation/widgets/chaput_reply_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Translations extends LocalizationsDelegate<AppLocalizations> {
  const _Translations(this.value);
  final AppLocalizations value;
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<AppLocalizations> load(Locale locale) => SynchronousFuture(value);
  @override
  bool shouldReload(_Translations old) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations translations;
  setUpAll(() async {
    translations = await AppLocalizations.load(const Locale('en'));
  });
  testWidgets('removing archived thread clears its draft and stops typing', (
    tester,
  ) async {
    final signals = <bool>[];
    Widget page(String threadId) => MaterialApp(
      localizationsDelegates: [_Translations(translations)],
      home: Scaffold(
        body: ChaputReplyBar(
          key: ValueKey(threadId),
          onSend: (_, _) async {},
          onWhisperPaywall: () async {},
          canWhisper: false,
          whisperMode: false,
          onToggleWhisper: () async {},
          onTypingChanged: signals.add,
        ),
      ),
    );
    await tester.pumpWidget(page('archived'));
    await tester.enterText(find.byType(TextField), 'unfinished draft');
    expect(signals.last, isTrue);
    await tester.pumpWidget(page('next'));
    expect(signals.last, isFalse);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.pumpWidget(page('archived'));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('typing continues beyond receiver expiry and stops after idle', (
    tester,
  ) async {
    final signals = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [_Translations(translations)],
        home: Scaffold(
          body: ChaputReplyBar(
            onSend: (_, _) async {},
            onWhisperPaywall: () async {},
            canWhisper: false,
            whisperMode: false,
            onToggleWhisper: () async {},
            onTypingChanged: signals.add,
          ),
        ),
      ),
    );
    final field = find.byType(TextField);
    for (var i = 1; i <= 7; i++) {
      await tester.enterText(field, 'a' * i);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(signals.where((typing) => typing).length, greaterThan(3));
    expect(signals.last, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(signals.last, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
