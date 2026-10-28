/// Input checks shared by the sign-in, sign-up and profile forms.
///
/// Each `validate*` function matches the `FormFieldValidator<String>`
/// signature: it returns an error message, or null when the value is fine.
library;

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Cambodian numbers: a leading 0 (or +855) and 8 to 9 more digits.
final _phonePattern = RegExp(r'^0\d{8,9}$');

bool isEmail(String value) => _emailPattern.hasMatch(value.trim());

/// Strips spaces and dashes, and turns +855 into a leading 0,
/// so "+855 12 345 678" and "012-345-678" are the same number.
String normalizePhone(String value) {
  var digits = value.replaceAll(RegExp(r'[\s-]'), '');
  if (digits.startsWith('+855')) digits = '0${digits.substring(4)}';
  return digits;
}

bool isPhone(String value) => _phonePattern.hasMatch(normalizePhone(value));

String? validateEmailOrPhone(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter your email or phone number.';
  if (!isEmail(text) && !isPhone(text)) {
    return 'Enter a valid email or phone number.';
  }
  return null;
}

String? validateRequiredPassword(String? value) {
  if (value == null || value.isEmpty) return 'Enter your password.';
  return null;
}
