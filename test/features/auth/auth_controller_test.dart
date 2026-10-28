import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/data/mock/mock_auth_repository.dart';
import 'package:mos_app/features/auth/auth_controller.dart';

void main() {
  late AuthController auth;
  const pw = MockAuthRepository.demoPassword;

  setUp(() {
    auth = AuthController(MockAuthRepository(latency: Duration.zero));
  });

  test('starts with no session', () {
    expect(auth.status, SessionStatus.none);
    expect(auth.hasSession, isFalse);
  });

  test('a customer signs in', () async {
    final ok = await auth.signIn(identifier: 'dara@example.com', password: pw);
    expect(ok, isTrue);
    expect(auth.status, SessionStatus.customer);
    expect(auth.user?.firstName, 'Dara');
    expect(auth.errorMessage, isNull);
  });

  test(
    'TC-04: a wrong password keeps the user signed out with an error',
    () async {
      final ok = await auth.signIn(
        identifier: 'dara@example.com',
        password: 'wrong',
      );
      expect(ok, isFalse);
      expect(auth.status, SessionStatus.none);
      expect(auth.errorMessage, 'Incorrect email/phone or password.');
    },
  );

  test('FR-05: staff accounts cannot use the customer app', () async {
    final ok = await auth.signIn(identifier: 'staff@mos.coffee', password: pw);
    expect(ok, isFalse);
    expect(auth.hasSession, isFalse);
    expect(auth.errorMessage, contains('admin dashboard'));
  });

  test('deactivated customers cannot sign in (FR-31)', () async {
    final ok = await auth.signIn(
      identifier: 'inactive@example.com',
      password: pw,
    );
    expect(ok, isFalse);
    expect(auth.errorMessage, contains('deactivated'));
  });

  test('FR-01: continue as guest', () {
    auth.continueAsGuest();
    expect(auth.isGuest, isTrue);
    expect(auth.hasSession, isTrue);
    expect(auth.user, isNull);
  });

  test('sign out clears the session', () async {
    await auth.signIn(identifier: 'dara@example.com', password: pw);
    await auth.signOut();
    expect(auth.status, SessionStatus.none);
    expect(auth.user, isNull);
  });

  test('clearError removes the old message', () async {
    await auth.signIn(identifier: 'dara@example.com', password: 'wrong');
    auth.clearError();
    expect(auth.errorMessage, isNull);
  });
}
