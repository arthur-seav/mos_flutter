import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/auth_repository.dart';
import 'auth_controller.dart';

/// Where the "verify account" step of a password reset is
/// (SA §4.2.1.3, Figma 1.3_Verify / 1.3_verify Account failed).
@immutable
class AccountVerification {
  const AccountVerification._({
    this.isVerifying = false,
    this.errorMessage,
    this.ticket,
  });

  /// Waiting for the user to enter a phone number.
  const AccountVerification.idle() : this._();

  /// Show the "Verifying account..." page.
  final bool isVerifying;

  /// Show this under the phone field ("Account not found.").
  final String? errorMessage;

  /// Set once the account is verified: go to the new-password page.
  final PasswordResetTicket? ticket;
}

/// One verification attempt at a time; the screen only shows its state.
///
/// Auto-disposed: leaving the forgot-password page forgets everything.
final accountVerificationProvider =
    NotifierProvider.autoDispose<
      AccountVerificationController,
      AccountVerification
    >(AccountVerificationController.new);

class AccountVerificationController extends Notifier<AccountVerification> {
  /// Increases on every attempt and on [cancel], so the answer to a
  /// cancelled attempt is ignored when it arrives later.
  int _attempt = 0;

  @override
  AccountVerification build() => const AccountVerification.idle();

  Future<void> verify(String phone) async {
    final attempt = ++_attempt;
    state = const AccountVerification._(isVerifying: true);
    try {
      final ticket = await ref
          .read(authControllerProvider.notifier)
          .verifyAccountForReset(phone: phone);
      if (!ref.mounted || attempt != _attempt) return;
      state = AccountVerification._(ticket: ticket);
    } on AuthException catch (e) {
      if (!ref.mounted || attempt != _attempt) return;
      state = AccountVerification._(errorMessage: e.message);
    }
  }

  /// "Cancel" on the verifying page.
  void cancel() {
    _attempt++;
    state = const AccountVerification.idle();
  }

  /// The user edited the number, or the screen has used the ticket.
  void reset() {
    if (!state.isVerifying) state = const AccountVerification.idle();
  }
}
