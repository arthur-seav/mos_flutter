import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/auth/account_verification_controller.dart';

import '../../helpers.dart';

void main() {
  late ProviderContainer container;
  AccountVerificationController controller() =>
      container.read(accountVerificationProvider.notifier);
  AccountVerification state() => container.read(accountVerificationProvider);

  setUp(() {
    container = ProviderContainer.test(overrides: mockOverrides());
    // Keep the auto-dispose provider alive for the whole test.
    container.listen(accountVerificationProvider, (_, _) {});
  });

  test('a registered phone gives a ticket', () async {
    await controller().verify('012 345 678');
    expect(state().ticket, isNotNull);
    expect(state().isVerifying, isFalse);
  });

  test('TC-06: an unknown phone gives "Account not found."', () async {
    await controller().verify('011 999 888');
    expect(state().ticket, isNull);
    expect(state().errorMessage, 'Account not found.');
  });

  test('verifying is shown while waiting', () async {
    final future = controller().verify('012 345 678');
    expect(state().isVerifying, isTrue);
    await future;
  });

  test('cancel ignores the answer that arrives later', () async {
    final future = controller().verify('012 345 678');
    controller().cancel();
    await future;
    expect(state().isVerifying, isFalse);
    expect(state().ticket, isNull);
  });

  test('reset clears the error', () async {
    await controller().verify('011 999 888');
    controller().reset();
    expect(state().errorMessage, isNull);
  });
}
