/// Input checks shared by the sign-in, sign-up and reset-password forms.
///
/// Each `validate*` function matches the `FormFieldValidator<String>`
/// signature: it returns an error message, or null when the value is fine.
///
/// Email format: `email_validator`. Phone numbers: `phone_numbers_parser`,
/// a Dart port of Google's libphonenumber, so the rules for every country's
/// numbers are maintained upstream instead of in a home-made regex.
library;

import 'package:email_validator/email_validator.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

/// Numbers typed without a country code are read as Cambodian.
const _defaultCountry = IsoCode.KH;

bool isEmail(String value) => EmailValidator.validate(value.trim());

PhoneNumber? _parsePhone(String value) {
  final text = value.trim();
  if (text.isEmpty) return null;
  try {
    return PhoneNumber.parse(text, callerCountry: _defaultCountry);
  } on PhoneNumberException {
    return null;
  }
}

/// True for a valid mobile number. Accounts need a mobile number, because
/// password reset (and the planned OTP step) goes to the phone.
bool isPhone(String value) =>
    _parsePhone(value)?.isValid(type: PhoneNumberType.mobile) ?? false;

/// One spelling per number, so "+855 12 345 678", "012-345-678" and
/// "012345678" are the same account.
///
/// Cambodian numbers become the local form with a leading 0 ("012345678");
/// other countries keep their international form ("+66812345678").
/// Returns the trimmed input unchanged when it is not a phone number.
String normalizePhone(String value) {
  final phone = _parsePhone(value);
  if (phone == null || !phone.isValid()) return value.trim();
  if (phone.isoCode == _defaultCountry) return '0${phone.nsn}';
  return phone.international;
}

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

/// Minimum password length for new accounts and resets (TC-02: 8+).
const minPasswordLength = 8;

String? validateNewPassword(String? value) {
  if (value == null || value.isEmpty) return 'Enter a password.';
  if (value.length < minPasswordLength) {
    return 'Use at least $minPasswordLength characters.';
  }
  return null;
}

String? validateFullName(String? value) {
  if (value == null || value.trim().isEmpty) return 'Enter your name.';
  return null;
}

/// For forms where the email is optional: empty is fine, but if something
/// is typed it must be a valid email.
String? validateOptionalEmail(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty || isEmail(text)) return null;
  return 'Enter a valid email.';
}

/// Same as [validateOptionalEmail], for a mobile number.
String? validateOptionalPhone(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty || isPhone(text)) return null;
  return 'Enter a valid mobile number.';
}

/// Sign up (FR-02): an email **or** a phone number. Each is optional on its
/// own, but not both. Shown on the email field.
String? validateSignUpEmail(String? email, {required String phone}) {
  final bothEmpty = (email?.trim().isEmpty ?? true) && phone.trim().isEmpty;
  if (bothEmpty) return 'Enter an email or a phone number.';
  return validateOptionalEmail(email);
}

/// The second password field must repeat the first.
String? validatePasswordConfirmation(
  String? confirmation, {
  required String password,
}) {
  if (confirmation == null || confirmation.isEmpty) {
    return 'Type the new password again.';
  }
  if (confirmation != password) return 'Passwords do not match.';
  return null;
}

String? validatePhone(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter your phone number.';
  return validateOptionalPhone(text);
}
