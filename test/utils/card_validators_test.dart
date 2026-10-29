import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/utils/card_validators.dart';

void main() {
  test('Luhn: test numbers pass, a changed digit fails', () {
    expect(passesLuhn('4242424242424242'), isTrue);
    expect(passesLuhn('4000000000000002'), isTrue);
    expect(passesLuhn('5555555555554444'), isTrue);
    expect(passesLuhn('4242424242424241'), isFalse);
    expect(passesLuhn('42424242'), isFalse); // too short
  });

  test('card number: spaces are fine, letters are not', () {
    expect(validateCardNumber('4242 4242 4242 4242'), isNull);
    expect(validateCardNumber(''), 'Enter the card number.');
    expect(
      validateCardNumber('4242 4242 4242 4241'),
      'Enter a valid card number.',
    );
  });

  test('expiry: MM/YY, valid to the end of that month', () {
    final now = DateTime(2026, 10, 29);
    expect(parseExpiry('09/28'), (month: 9, year: 2028));
    expect(parseExpiry('9 / 28'), (month: 9, year: 2028));
    expect(parseExpiry('13/28'), isNull);
    expect(validateExpiry('10/26', now: now), isNull); // until 31 Oct
    expect(validateExpiry('09/26', now: now), 'This card has expired.');
    expect(validateExpiry('0928', now: now), 'Use MM/YY, e.g. 09/28.');
  });

  test('CVV: 3 or 4 digits', () {
    expect(validateCvv('123'), isNull);
    expect(validateCvv('1234'), isNull);
    expect(validateCvv('12'), 'Use the 3 or 4 digits.');
    expect(validateCvv('12a'), 'Use the 3 or 4 digits.');
  });

  test('holder name is required', () {
    expect(validateCardHolder('  '), 'Enter the name on the card.');
    expect(validateCardHolder('Dara Sok'), isNull);
  });
}
