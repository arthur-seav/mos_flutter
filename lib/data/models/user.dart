/// Roles from SA 2.0 §1.5. Only customers may use this app.
enum UserRole { customer, staff, admin }

/// Account status (data dictionary: users.status).
enum AccountStatus { active, inactive }

/// A signed-in user. Mirrors the `users` table, minus the password hash,
/// which never leaves the backend (NFR-05).
class User {
  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.email,
    this.phone,
    this.status = AccountStatus.active,
  });

  final int id;
  final String firstName;
  final String lastName;
  final UserRole role;

  /// A customer signs up with an email or a phone number (FR-02),
  /// so either one may be missing.
  final String? email;
  final String? phone;
  final AccountStatus status;

  String get fullName => '$firstName $lastName';

  bool get isActive => status == AccountStatus.active;

  /// SA §1.5: staff and admins work on the admin side only.
  bool get isCustomer => role == UserRole.customer;
}
