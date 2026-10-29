/// Checks for the "add a card" form (SA §4.2.3.3).
///
/// Written here instead of using a package: `credit_card_validator` was
/// last released in 2023 for Dart 2, and `flutter_credit_card` brings its
/// own card UI and native plugin, which the Figma design does not use.
/// The payment gateway checks the card again when it is saved.
library;

/// "4242 4242-4242 4242" -> "4242424242424242".
String digitsOnly(String value) => value.replaceAll(RegExp(r'\D'), '');

/// The checksum every card number carries (Luhn / mod 10).
bool passesLuhn(String digits) {
  if (digits.length < 12 || digits.length > 19) return false;
  if (digits.contains(RegExp(r'\D'))) return false;
  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    var d = int.parse(digits[digits.length - 1 - i]);
    if (i.isOdd) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return sum % 10 == 0;
}

String? validateCardNumber(String? value) {
  final digits = digitsOnly(value ?? '');
  if (digits.isEmpty) return 'Enter the card number.';
  if (!passesLuhn(digits)) return 'Enter a valid card number.';
  return null;
}

String? validateCardHolder(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter the name on the card.';
  if (text.length > 50) return 'Use 50 characters or fewer.';
  return null;
}

/// "09/28" or "09 / 28" -> (month: 9, year: 2028). Null when it is not a
/// month and a two-digit year.
({int month, int year})? parseExpiry(String value) {
  final match = RegExp(r'^\s*(\d{1,2})\s*/\s*(\d{2})\s*$').firstMatch(value);
  if (match == null) return null;
  final month = int.parse(match.group(1)!);
  if (month < 1 || month > 12) return null;
  return (month: month, year: 2000 + int.parse(match.group(2)!));
}

/// The card works until the end of its expiry month.
String? validateExpiry(String? value, {required DateTime now}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter the expiry date.';
  final expiry = parseExpiry(text);
  if (expiry == null) return 'Use MM/YY, e.g. 09/28.';
  if (!now.isBefore(DateTime(expiry.year, expiry.month + 1))) {
    return 'This card has expired.';
  }
  return null;
}

String? validateCvv(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter the CVV.';
  if (!RegExp(r'^\d{3,4}$').hasMatch(text)) return 'Use the 3 or 4 digits.';
  return null;
}
