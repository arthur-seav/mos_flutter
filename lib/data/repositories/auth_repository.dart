import '../models/user.dart';

/// Thrown when signing in fails for a reason the user should see.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Where accounts come from.
///
/// The UI only talks to this interface (NFR-09). Today it is backed by
/// `MockAuthRepository`; later an `ApiAuthRepository` will call the backend,
/// and only `main.dart` changes.
abstract interface class AuthRepository {
  /// Signs in with an email or a phone number.
  ///
  /// Throws [AuthException] when the identifier or password is wrong.
  Future<User> signIn({required String identifier, required String password});

  Future<void> signOut();
}
