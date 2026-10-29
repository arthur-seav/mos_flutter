import '../models/profile_update.dart';
import '../models/sign_up_request.dart';
import '../models/user.dart';

/// Thrown when an account action fails for a reason the user should see.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Proof that an account passed the "verify account" step of a password
/// reset (SA §4.2.1.3). The backend will return a short-lived token here,
/// and later only after an OTP check.
class PasswordResetTicket {
  const PasswordResetTicket(this.token);

  final String token;
}

/// Where accounts come from.
///
/// The UI only talks to this interface (NFR-09). Today it is backed by
/// `MockAuthRepository`; later an `ApiAuthRepository` will call the backend,
/// and only `main.dart` changes.
///
/// Every method throws [AuthException] for failures the user can fix.
abstract interface class AuthRepository {
  /// Signs in with an email or a phone number.
  Future<User> signIn({required String identifier, required String password});

  Future<void> signOut();

  /// Creates a customer account (FR-02). Fails when the email or phone
  /// number is already registered (TC-03).
  Future<User> signUp(SignUpRequest request);

  /// Step 1 of a forgotten-password reset: checks that an account uses
  /// this phone number (TC-06: fails with "Account not found.").
  Future<PasswordResetTicket> verifyAccountForReset({required String phone});

  /// Step 2: sets a new password for the verified account (TC-05).
  Future<void> resetPassword({
    required PasswordResetTicket ticket,
    required String newPassword,
  });

  /// "Edit Personal Info" (FR-04, TC-07). Fails when the email or phone
  /// number belongs to another account, or when both are left empty.
  Future<User> updateProfile(ProfileUpdate update);

  /// "Change Password" while signed in (FR-30, SA §4.2.5.3). Fails when
  /// [currentPassword] is wrong.
  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  });
}
