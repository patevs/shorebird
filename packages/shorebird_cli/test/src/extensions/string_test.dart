import 'package:shorebird_cli/src/extensions/string.dart';
import 'package:test/test.dart';

void main() {
  group('NullOrEmpty', () {
    group('when string is null', () {
      test('returns true', () {
        expect(null.isNullOrEmpty, true);
      });
    });

    group('when string is empty', () {
      test('returns true', () {
        expect(''.isNullOrEmpty, true);
      });
    });

    group('when string is not empty', () {
      test('returns false', () {
        expect('test'.isNullOrEmpty, false);
      });
    });
  });

  group('IsUpperCase', () {
    test('returns true if a string contains only uppercase characters', () {
      expect('TEST'.isUpperCase(), isTrue);
      expect('test'.isUpperCase(), isFalse);
      expect('Test'.isUpperCase(), isFalse);
    });
  });
}
