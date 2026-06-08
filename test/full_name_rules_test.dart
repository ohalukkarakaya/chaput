import 'package:chaput/features/helpers/string_helpers/full_name_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts letters and spaces across scripts', () {
    expect(hasOnlyFullNameCharacters('Cem Kılıç'), isTrue);
    expect(hasOnlyFullNameCharacters('张 伟'), isTrue);
    expect(hasOnlyFullNameCharacters('山田 太郎'), isTrue);
    expect(hasOnlyFullNameCharacters('محمد علي'), isTrue);
    expect(hasOnlyFullNameCharacters('Jose\u0301 Silva'), isTrue);
    expect(hasAtLeastTwoFullNameWords('张 伟'), isTrue);
  });

  test('rejects punctuation symbols digits and dashes', () {
    expect(hasOnlyFullNameCharacters('m @. {}#[]%^*+=_\\|~<>€\$£'), isFalse);
    expect(hasOnlyFullNameCharacters('Jean-Luc Picard'), isFalse);
    expect(hasOnlyFullNameCharacters('Cem2 Kılıç'), isFalse);
    expect(hasOnlyFullNameCharacters('Ali (Veli)'), isFalse);
  });

  test('sanitizes pasted invalid characters', () {
    expect(sanitizeFullNameInput('m @. {}#[]%^*+=_\\|~<>€\$£'), 'm ');
    expect(cleanFullNameForSubmit('  Cem--- Kılıç  '), 'Cem Kılıç');
  });
}
