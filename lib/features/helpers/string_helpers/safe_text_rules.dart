import 'dart:math' as math;

import 'package:flutter/services.dart';

const int kInitialChaputMessageMaxLength = 500;

final RegExp _blockedTextCharsRe = RegExp(
  r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F\u061C\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]',
  unicode: true,
);

String sanitizeUserTextInput(
  String input, {
  required int maxLength,
  bool allowNewlines = true,
}) {
  var out = input
      .replaceAll(_blockedTextCharsRe, '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\t', ' ');

  if (!allowNewlines) {
    out = out.replaceAll(RegExp(r'\s+', unicode: true), ' ');
  }

  if (out.runes.length <= maxLength) return out;
  return String.fromCharCodes(out.runes.take(maxLength));
}

String cleanUserTextForSubmit(
  String input, {
  required int maxLength,
  bool allowNewlines = true,
}) {
  return sanitizeUserTextInput(
    input,
    maxLength: maxLength,
    allowNewlines: allowNewlines,
  ).trim();
}

class SafeTextInputFormatter extends TextInputFormatter {
  const SafeTextInputFormatter({
    required this.maxLength,
    this.allowNewlines = true,
  });

  final int maxLength;
  final bool allowNewlines;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }

    final sanitized = sanitizeUserTextInput(
      newValue.text,
      maxLength: maxLength,
      allowNewlines: allowNewlines,
    );
    if (sanitized == newValue.text) return newValue;

    final selectionEnd = newValue.selection.end;
    final safeEnd = selectionEnd < 0
        ? newValue.text.length
        : math.min(selectionEnd, newValue.text.length);
    final offset = sanitizeUserTextInput(
      newValue.text.substring(0, safeEnd),
      maxLength: maxLength,
      allowNewlines: allowNewlines,
    ).length;

    return TextEditingValue(
      text: sanitized,
      selection: TextSelection.collapsed(
        offset: math.min(offset, sanitized.length),
      ),
    );
  }
}

final RegExp _usernameAllowedCharRe = RegExp(r'[a-z0-9._]');

String sanitizeUsernameInput(String input) {
  final out = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    if (_usernameAllowedCharRe.hasMatch(ch)) out.write(ch);
    if (out.length >= 32) break;
  }
  return out.toString();
}

bool isValidUsernameInput(String input) {
  final s = sanitizeUsernameInput(input.trim());
  if (s.length < 3 || s.length > 32) return false;
  if (s.startsWith('.') || s.endsWith('.')) return false;
  if (s.contains('..')) return false;
  return s == input.trim().toLowerCase();
}

class UsernameInputFormatter extends TextInputFormatter {
  const UsernameInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }

    final sanitized = sanitizeUsernameInput(newValue.text);
    if (sanitized == newValue.text) return newValue;

    final selectionEnd = newValue.selection.end;
    final safeEnd = selectionEnd < 0
        ? newValue.text.length
        : math.min(selectionEnd, newValue.text.length);
    final offset = sanitizeUsernameInput(
      newValue.text.substring(0, safeEnd),
    ).length;

    return TextEditingValue(
      text: sanitized,
      selection: TextSelection.collapsed(
        offset: math.min(offset, sanitized.length),
      ),
    );
  }
}
