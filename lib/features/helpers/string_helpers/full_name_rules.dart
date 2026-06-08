import 'dart:math' as math;

import 'package:flutter/services.dart';

final RegExp _fullNameLetterRe = RegExp(r'^\p{L}$', unicode: true);
final RegExp _fullNameMarkRe = RegExp(r'^\p{M}$', unicode: true);
final RegExp _whitespaceRe = RegExp(r'\s', unicode: true);

String sanitizeFullNameInput(String input) {
  final out = StringBuffer();
  var lastWasSpace = true;
  var currentWordHasLetter = false;

  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    if (_whitespaceRe.hasMatch(ch)) {
      if (out.isNotEmpty && !lastWasSpace) {
        out.write(' ');
        lastWasSpace = true;
        currentWordHasLetter = false;
      }
      continue;
    }

    if (_fullNameLetterRe.hasMatch(ch)) {
      out.write(ch);
      lastWasSpace = false;
      currentWordHasLetter = true;
      continue;
    }

    if (_fullNameMarkRe.hasMatch(ch) && currentWordHasLetter) {
      out.write(ch);
      lastWasSpace = false;
    }
  }

  return out.toString();
}

String cleanFullNameForSubmit(String input) =>
    sanitizeFullNameInput(input).trim();

bool hasOnlyFullNameCharacters(String input) {
  final normalizedInput = input.trim().replaceAll(_whitespaceRe, ' ');
  return cleanFullNameForSubmit(input) == normalizedInput;
}

bool hasAtLeastTwoFullNameWords(String input) {
  final parts = cleanFullNameForSubmit(
    input,
  ).split(' ').where((part) => part.isNotEmpty);
  return parts.length >= 2;
}

class FullNameInputFormatter extends TextInputFormatter {
  const FullNameInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }

    final sanitized = sanitizeFullNameInput(newValue.text);
    if (sanitized == newValue.text) return newValue;

    final selectionEnd = newValue.selection.end;
    final safeEnd = selectionEnd < 0
        ? newValue.text.length
        : math.min(selectionEnd, newValue.text.length);
    final offset = sanitizeFullNameInput(
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
