import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repository_providers.dart';

/// Who is using the app right now.
enum SessionStatus {
  /// Nobody yet: the router keeps the user on the login page.
  none,

  /// Browsing without an account (FR-01). Must sign in before ordering (BR-06).
  guest,

  /// Signed in as a customer.
  customer,
}

/// The current session. Immutable: every change creates a new [AuthState],
/// which is how Riverpod knows to rebuild the screens that watch it.
@immutable
class AuthState {
  const AuthState.none() : status = SessionStatus.none, user = null;
  const AuthState.guest() : status = SessionStatus.guest, user = null;
  const AuthState.customer(User this.user) : status = SessionStatus.customer;

  final SessionStatus status;

  /// Only set for [SessionStatus.customer].
  final User? user;

  bool get hasSession => status != SessionStatus.none;
  bool get isGuest => status == SessionStatus.guest;
  bool get isCustomer => status == SessionStatus.customer;
}

/// The session for the whole app. Screens read it with
/// `ref.watch(authControllerProvider)` and change it through
/// `ref.read(authControllerProvider.notifier)`.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Runs sign in / guest / sign out and holds the resulting [AuthState].
///
/// Methods that can fail throw [AuthException] with a message for the user;
/// each form shows it (see `SubmitStateMixin`).
class AuthController extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthState build() => const AuthState.none();

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final user = await _repository.signIn(
      identifier: identifier,
      password: password,
    );
    _ensureCanUseApp(user);
    if (!ref.mounted) return;
    state = AuthState.customer(user);
  }

  void continueAsGuest() => state = const AuthState.guest();

  Future<void> signOut() async {
    if (state.isCustomer) await _repository.signOut();
    if (!ref.mounted) return;
    state = const AuthState.none();
  }

  /// FR-05 / SA §1.5: this app is for active customers only.
  void _ensureCanUseApp(User user) {
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
  }
}
