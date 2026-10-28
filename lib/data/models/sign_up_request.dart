/// What a guest fills in to create a customer account (FR-02).
class SignUpRequest {
  const SignUpRequest({
    required this.fullName,
    required this.password,
    this.email,
    this.phone,
  }) : assert(email != null || phone != null, 'Email or phone is required');

  /// As typed in the single "Full name" field of the Figma design.
  final String fullName;
  final String password;

  /// FR-02: an email or a phone number; at least one of the two.
  final String? email;
  final String? phone;

  /// The data dictionary stores `first_name` and `last_name` separately.
  /// The first word becomes the first name, the rest the last name
  /// ("Dara Sok" -> "Dara" + "Sok"). A one-word name has no last name.
  ({String first, String last}) get splitName {
    final words = fullName.trim().split(RegExp(r'\s+'));
    return (first: words.first, last: words.skip(1).join(' '));
  }
}
