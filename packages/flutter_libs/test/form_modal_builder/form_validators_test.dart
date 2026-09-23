import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';

void main() {
  group('FormValidators', () {
    group('validateRequired', () {
      test('returns error for null', () {
        expect(FormValidators.validateRequired(null), isNotNull);
      });
      test('returns error for empty string', () {
        expect(FormValidators.validateRequired(''), isNotNull);
      });
      test('returns null for valid value', () {
        expect(FormValidators.validateRequired('test'), isNull);
      });
    });

    group('validateEmail', () {
      test('accepts valid email', () {
        expect(FormValidators.validateEmail('user@example.com'), isNull);
      });
      test('rejects invalid email', () {
        expect(FormValidators.validateEmail('not-an-email'), isNotNull);
      });
      test('allows null (not required)', () {
        expect(FormValidators.validateEmail(null), isNull);
      });
    });

    group('validateUrl', () {
      test('accepts valid URL', () {
        expect(FormValidators.validateUrl('https://example.com'), isNull);
      });
      test('rejects invalid URL', () {
        expect(FormValidators.validateUrl('not a url'), isNotNull);
      });
    });

    group('validatePhone', () {
      test('accepts valid phone', () {
        expect(FormValidators.validatePhone('+1234567890'), isNull);
      });
      test('rejects invalid phone', () {
        expect(FormValidators.validatePhone('abc'), isNotNull);
      });
    });

    group('validateNumber', () {
      test('validates min', () {
        expect(FormValidators.validateNumber('3', min: 5), isNotNull);
        expect(FormValidators.validateNumber('5', min: 5), isNull);
        expect(FormValidators.validateNumber('10', min: 5), isNull);
      });
      test('validates max', () {
        expect(FormValidators.validateNumber('15', max: 10), isNotNull);
        expect(FormValidators.validateNumber('10', max: 10), isNull);
      });
    });

    group('validatePassword', () {
      test('rejects short password', () {
        expect(FormValidators.validatePassword('ab'), isNotNull);
      });
      test('accepts valid password', () {
        expect(FormValidators.validatePassword('password123'), isNull);
      });
    });

    group('buildValidator', () {
      test('builds composite required email validator', () {
        final v = FormValidators.buildValidator(type: 'email', required: true);
        expect(v(null), isNotNull);
        expect(v(''), isNotNull);
        expect(v('bad'), isNotNull);
        expect(v('good@test.com'), isNull);
      });

      test('validates the url type', () {
        final v = FormValidators.buildValidator(type: 'url');
        expect(v('not a url'), 'Please enter a valid URL');
        expect(v('https://example.com'), isNull);
      });

      test('validates the tel type', () {
        final v = FormValidators.buildValidator(type: 'tel');
        expect(v('abc'), 'Please enter a valid phone number');
        expect(v('+1 234-567-8900'), isNull);
      });

      test('validates the number type, including min/max bounds', () {
        final v = FormValidators.buildValidator(
          type: 'number',
          min: 5,
          max: 10,
          label: 'Amount',
        );
        expect(v('not-a-number'), 'Please enter a valid number');
        expect(v('3'), 'Amount must be at least 5');
        expect(v('15'), 'Amount must be at most 10');
        expect(v('7'), isNull);
      });

      test('validates the date type', () {
        final v = FormValidators.buildValidator(type: 'date');
        expect(v('not-a-date'), 'Please enter a valid date (YYYY-MM-DD)');
        expect(v('2024-01-01'), isNull);
      });

      test('validates the time type', () {
        final v = FormValidators.buildValidator(type: 'time');
        expect(v('not-a-time'), 'Please enter a valid time (HH:MM)');
        expect(v('09:30'), isNull);
      });

      test('validates the datetimeLocal type', () {
        final v = FormValidators.buildValidator(type: 'datetimeLocal');
        expect(v('not-a-datetime'), 'Please enter a valid date and time');
        expect(v('2024-01-01T09:30'), isNull);
      });

      test('validates the passwordGenerate type requires 8+ characters', () {
        final v = FormValidators.buildValidator(type: 'passwordGenerate');
        expect(v('short'), 'Password must be at least 8 characters');
        expect(v('longenough1'), isNull);
      });

      test(
        'validates the checkboxMulti type requires at least one selection',
        () {
          final v = FormValidators.buildValidator(
            type: 'checkboxMulti',
            required: true,
          );
          expect(v(<dynamic>[]), 'Please select at least one option');
          expect(v(['a']), isNull);
        },
      );

      test(
        'applies a custom pattern after type-specific validation passes',
        () {
          final v = FormValidators.buildValidator(
            type: 'text',
            pattern: r'^[a-z]+$',
            label: 'Code',
          );
          expect(v('ABC123'), 'Code format is invalid');
          expect(v('abc'), isNull);
        },
      );
    });
  });
}
