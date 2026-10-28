import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/data/mock/mock_auth_repository.dart';
import 'package:mos_app/data/models/sign_up_request.dart';
import 'package:mos_app/data/repositories/auth_repository.dart';

void main() {
  late MockAuthRepository repo;
  const pw = MockAuthRepository.demoPassword;

  setUp(() => repo = MockAuthRepository(latency: Duration.zero));

  Matcher authError(Object message) => throwsA(
    isA<AuthException>().having((e) => e.message, 'message', message),
  );

  group('sign in', () {
    test('by email, ignoring case', () async {
      final user = await repo.signIn(
        identifier: 'Dara@Example.com',
        password: pw,
      );
      expect(user.fullName, 'Dara Sok');
    });

    test('by phone in another format', () async {
      final user = await repo.signIn(
        identifier: '+855 12 345 678',
        password: pw,
      );
      expect(user.email, 'dara@example.com');
    });

    test('wrong password and unknown account give the same error', () async {
      const message = 'Incorrect email/phone or password.';
      await expectLater(
        repo.signIn(identifier: 'dara@example.com', password: 'nope'),
        authError(message),
      );
      await expectLater(
        repo.signIn(identifier: 'nobody@example.com', password: pw),
        authError(message),
      );
    });
  });

  group('sign up (FR-02)', () {
    test('TC-02: creates a customer who can then sign in', () async {
      final user = await repo.signUp(
        const SignUpRequest(
          fullName: '  Sophat  Samnang ',
          email: 'New@Example.com',
          phone: '+855 17 222 333',
          password: 'longenough',
        ),
      );
      expect(user.firstName, 'Sophat');
      expect(user.lastName, 'Samnang');
      expect(user.email, 'new@example.com');
      expect(user.phone, '017222333');
      expect(user.isCustomer, isTrue);

      final again = await repo.signIn(
        identifier: '017 222 333',
        password: 'longenough',
      );
      expect(again.id, user.id);
    });

    test('works with only a phone number', () async {
      final user = await repo.signUp(
        const SignUpRequest(
          fullName: 'Phakdey',
          phone: '017222444',
          password: 'longenough',
        ),
      );
      expect(user.email, isNull);
      expect(user.lastName, '');
    });

    test('TC-03: a registered email is refused', () async {
      await expectLater(
        repo.signUp(
          const SignUpRequest(
            fullName: 'X',
            email: 'DARA@example.com',
            password: 'longenough',
          ),
        ),
        authError('This email is already registered.'),
      );
    });

    test(
      'TC-03: a registered phone number is refused, in any format',
      () async {
        await expectLater(
          repo.signUp(
            const SignUpRequest(
              fullName: 'X',
              phone: '+855 12-345-678',
              password: 'longenough',
            ),
          ),
          authError('This phone number is already registered.'),
        );
      },
    );
  });

  group('password reset', () {
    test('TC-06: an unknown phone number is not found', () async {
      await expectLater(
        repo.verifyAccountForReset(phone: '011999888'),
        authError('Account not found.'),
      );
    });

    test('TC-05: the new password works and the old one does not', () async {
      final ticket = await repo.verifyAccountForReset(phone: '012 345 678');
      await repo.resetPassword(ticket: ticket, newPassword: 'brand-new-pw');

      final user = await repo.signIn(
        identifier: '012345678',
        password: 'brand-new-pw',
      );
      expect(user.firstName, 'Dara');
      await expectLater(
        repo.signIn(identifier: '012345678', password: pw),
        authError('Incorrect email/phone or password.'),
      );
    });

    test('a ticket only works once', () async {
      final ticket = await repo.verifyAccountForReset(phone: '012345678');
      await repo.resetPassword(ticket: ticket, newPassword: 'first-new-pw');
      await expectLater(
        repo.resetPassword(ticket: ticket, newPassword: 'second-new-pw'),
        authError(contains('expired')),
      );
    });
  });
}
