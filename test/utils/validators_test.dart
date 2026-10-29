import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/utils/validators.dart';

void main() {
  group('validateEmailOrPhone', () {
    test('accepts an email', () {
      expect(validateEmailOrPhone('dara@example.com'), isNull);
    });

    test('accepts Cambodian mobile numbers in common formats', () {
      expect(validateEmailOrPhone('012345678'), isNull);
      expect(validateEmailOrPhone('012-345-678'), isNull);
      expect(validateEmailOrPhone('+855 12 345 678'), isNull);
    });

    test('accepts a foreign mobile number with its country code', () {
      expect(validateEmailOrPhone('+66 81 234 5678'), isNull);
    });

    test('rejects empty input', () {
      expect(validateEmailOrPhone('  '), 'Enter your email or phone number.');
    });

    test('rejects text that is neither', () {
      expect(validateEmailOrPhone('dara@'), isNotNull);
      expect(validateEmailOrPhone('12345'), isNotNull);
      expect(validateEmailOrPhone('abc'), isNotNull);
    });

    test('rejects a landline, since accounts need a mobile number', () {
      expect(validateEmailOrPhone('023 212 345'), isNotNull);
    });
  });

  group('normalizePhone', () {
    test('Cambodian numbers become 0 + local number', () {
      expect(normalizePhone('+855 12 345 678'), '012345678');
      expect(normalizePhone('012-345-678'), '012345678');
    });

    test('foreign numbers keep their country code', () {
      expect(normalizePhone('+66 81 234 5678'), '+66812345678');
    });

    test('non-numbers are only trimmed', () {
      expect(normalizePhone('  hello '), 'hello');
    });
  });

  group('validateSignUpEmail (FR-02: email or phone)', () {
    test('both empty is refused', () {
      expect(
        validateSignUpEmail('', phone: ' '),
        'Enter an email or a phone number.',
      );
    });

    test('phone only is fine', () {
      expect(validateSignUpEmail('', phone: '012345678'), isNull);
    });

    test('an email, if typed, must be valid', () {
      expect(validateSignUpEmail('dara@', phone: '012345678'), isNotNull);
    });
  });

  group('validatePasswordConfirmation', () {
    test('must not be empty', () {
      expect(
        validatePasswordConfirmation('', password: 'abc'),
        'Type the new password again.',
      );
    });

    test('must match', () {
      expect(
        validatePasswordConfirmation('abd', password: 'abc'),
        'Passwords do not match.',
      );
      expect(validatePasswordConfirmation('abc', password: 'abc'), isNull);
    });
  });

  test('validateRequiredPassword', () {
    expect(validateRequiredPassword(''), 'Enter your password.');
    expect(validateRequiredPassword('x'), isNull);
  });

  group('validateDifferentPassword (FR-30)', () {
    test('the current password cannot be reused', () {
      expect(
        validateDifferentPassword('password123', current: 'password123'),
        'Choose a password different from your current one.',
      );
    });

    test('another password is fine', () {
      expect(
        validateDifferentPassword('password124', current: 'password123'),
        isNull,
      );
    });

    test('the comparison is exact, so case and spaces count', () {
      expect(
        validateDifferentPassword('Password123', current: 'password123'),
        isNull,
      );
      expect(
        validateDifferentPassword('password123 ', current: 'password123'),
        isNull,
      );
    });

    test('empty input is left to the length check', () {
      expect(validateDifferentPassword('', current: 'password123'), isNull);
      expect(validateDifferentPassword(null, current: ''), isNull);
    });
  });
}
