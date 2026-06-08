import 'package:chaput/features/helpers/string_helpers/safe_text_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removes control and invisible spoof characters from text', () {
    expect(
      sanitizeUserTextInput('hello\u202E<script>\x00', maxLength: 2000),
      'hello<script>',
    );
    expect(
      cleanUserTextForSubmit('  hi\tthere\r\nok  ', maxLength: 2000),
      'hi there\nok',
    );
  });

  test('normalizes single-line text', () {
    expect(
      cleanUserTextForSubmit(
        'hello\nthere',
        maxLength: 2000,
        allowNewlines: false,
      ),
      'hello there',
    );
  });

  test('limits text length by runes', () {
    expect(sanitizeUserTextInput('abcdef', maxLength: 3), 'abc');
  });

  test('keeps username input aligned with backend rules', () {
    expect(sanitizeUsernameInput(' A_B.c! '), 'a_b.c');
    expect(isValidUsernameInput('a_b.c'), isTrue);
    expect(isValidUsernameInput('.abc'), isFalse);
    expect(isValidUsernameInput('ab..cd'), isFalse);
    expect(isValidUsernameInput('ab'), isFalse);
  });
}
