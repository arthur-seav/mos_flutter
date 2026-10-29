import 'package:flutter/foundation.dart' show immutable;

/// "Edit Personal Info" (SA §4.2.5.2, FR-04, TC-07). Empty email or phone
/// means "none"; at least one must stay, as at sign-up (FR-02).
@immutable
class ProfileUpdate {
  const ProfileUpdate({
    required this.userId,
    required this.fullName,
    this.email,
    this.phone,
    this.dateOfBirth,
  });

  final int userId;
  final String fullName;
  final String? email;
  final String? phone;
  final DateTime? dateOfBirth;

  /// "Dara Sok" -> first "Dara", last "Sok" (users.first_name / last_name).
  ({String first, String last}) get splitName {
    final words = fullName.trim().split(RegExp(r'\s+'));
    return (first: words.first, last: words.skip(1).join(' '));
  }
}
