import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/data/mock/mock_auth_repository.dart';
import 'package:mos_app/data/repositories/auth_repository.dart';
import 'package:mos_app/features/auth/auth_controller.dart';

import '../../helpers.dart';

void main() {
  late ProviderContainer container;
  AuthController controller() =>
      container.read(authControllerProvider.notifier);
  AuthState session() => container.read(authControllerProvider);
  const pw = MockAuthRepository.demoPassword;

  Matcher authError(Object message) => throwsA(
    isA<AuthException>().having((e) => e.message, 'message', message),
  );

  setUp(() {
    container = ProviderContainer.test(overrides: mockOverrides());
  });

  test('starts with no session', () {
    expect(session().status, SessionStatus.none);
    expect(session().hasSession, isFalse);
  });

  test('a customer signs in', () async {
    await controller().signIn(identifier: 'dara@example.com', password: pw);
    expect(session().status, SessionStatus.customer);
    expect(session().user?.firstName, 'Dara');
  });

  test('TC-04: a wrong password keeps the user signed out', () async {
    await expectLater(
      controller().signIn(identifier: 'dara@example.com', password: 'wrong'),
      authError('Incorrect email/phone or password.'),
    );
    expect(session().status, SessionStatus.none);
  });

  test('FR-05: staff accounts cannot use the customer app', () async {
    await expectLater(
      controller().signIn(identifier: 'staff@mos.coffee', password: pw),
      authError(contains('admin dashboard')),
    );
    expect(session().hasSession, isFalse);
  });

  test('deactivated customers cannot sign in (FR-31)', () async {
    await expectLater(
      controller().signIn(identifier: 'inactive@example.com', password: pw),
      authError(contains('deactivated')),
    );
  });

  test('FR-01: continue as guest', () {
    controller().continueAsGuest();
    expect(session().isGuest, isTrue);
    expect(session().hasSession, isTrue);
    expect(session().user, isNull);
  });

  test('sign out clears the session', () async {
    await controller().signIn(identifier: 'dara@example.com', password: pw);
    await controller().signOut();
    expect(session().status, SessionStatus.none);
    expect(session().user, isNull);
  });
}
