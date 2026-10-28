import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/core/utils/validators.dart';

void main() {
  group('validateEmailOrPhone', () {
    test('accepts an email', () {
      expect(validateEmailOrPhone('dara@example.com'), isNull);
    });

    test('accepts Cambodian phone numbers in common formats', () {
      expect(validateEmailOrPhone('012345678'), isNull);
      expect(validateEmailOrPhone('012-345-678'), isNull);
      expect(validateEmailOrPhone('+855 12 345 678'), isNull);
    });

    test('rejects empty input', () {
      expect(validateEmailOrPhone('  '), 'Enter your email or phone number.');
    });

    test('rejects text that is neither', () {
      expect(validateEmailOrPhone('dara@'), isNotNull);
      expect(validateEmailOrPhone('12345'), isNotNull);
    });
  });

  test('normalizePhone turns +855 into a leading 0', () {
    expect(normalizePhone('+855 12 345 678'), '012345678');
  });

  test('validateRequiredPassword', () {
    expect(validateRequiredPassword(''), 'Enter your password.');
    expect(validateRequiredPassword('x'), isNull);
  });
}
