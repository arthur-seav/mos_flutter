import 'package:flutter/foundation.dart';

import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';

/// Who is using the app right now.
enum SessionStatus {
  /// Nobody yet: the router keeps the user on the login page.
  none,

  /// Browsing without an account (FR-01). Must sign in before ordering (BR-06).
  guest,

  /// Signed in as a customer.
  customer,
}

/// Holds the session and runs sign in / guest / sign out.
///
/// Screens read its state and call its methods; they never call the
/// repository directly.
class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  SessionStatus _status = SessionStatus.none;
  User? _user;
  bool _isBusy = false;
  String? _errorMessage;

  SessionStatus get status => _status;
  User? get user => _user;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  bool get hasSession => _status != SessionStatus.none;
  bool get isGuest => _status == SessionStatus.guest;

  /// Returns true when the user is signed in.
  /// On failure, [errorMessage] says why.
  Future<bool> signIn({
    required String identifier,
    required String password,
  }) async {
    if (_isBusy) return false;
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _repository.signIn(
        identifier: identifier,
        password: password,
      );
      // FR-05 / SA §1.5: this app is for customers only.
      if (!user.isCustomer) {
        throw const AuthException(
          'Staff and admin accounts use the admin dashboard, not this app.',
        );
      }
      if (!user.isActive) {
        throw const AuthException(
          'This account has been deactivated. Please contact the store.',
        );
      }
      _user = user;
      _status = SessionStatus.customer;
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void continueAsGuest() {
    _user = null;
    _errorMessage = null;
    _status = SessionStatus.guest;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (_status == SessionStatus.customer) await _repository.signOut();
    _user = null;
    _errorMessage = null;
    _status = SessionStatus.none;
    notifyListeners();
  }

  /// Called when the user edits the form, so an old error does not linger.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}
