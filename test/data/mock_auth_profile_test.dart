import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/auth/auth_controller.dart';
import 'package:mos_app/data/mock/mock_auth_repository.dart';
import 'package:mos_app/data/models/profile_update.dart';
import 'package:mos_app/data/repositories/auth_repository.dart';

import '../helpers.dart';

/// FR-04 (TC-07) and FR-30: editing the profile and changing the
/// password while signed in.
void main() {
  late MockAuthRepository auth;

  setUp(() => auth = MockAuthRepository(latency: Duration.zero));

  const dara = MockAuthRepository.daraId;
  Matcher fails(String message) => throwsA(
    isA<AuthException>().having((e) => e.message, 'message', message),
  );

  test('TC-07: a new phone number is saved and works for signing in', () async {
    final user = await auth.updateProfile(
      ProfileUpdate(
        userId: dara,
        fullName: 'Dara Sok',
        email: 'dara@example.com',
        phone: '017 222 333',
        dateOfBirth: DateTime(1998, 9, 3),
      ),
    );
    expect(user.phone, '017222333');
    expect(user.dateOfBirth, DateTime(1998, 9, 3));
    expect(user.firstName, 'Dara');
    expect(user.lastName, 'Sok');
    final again = await auth.signIn(
      identifier: '017 222 333',
      password: MockAuthRepository.demoPassword,
    );
    expect(again.id, dara);
  });

  test("another account's email or phone is refused", () async {
    // Sreyneang (account 2) has 098 765 432.
    expect(
      auth.updateProfile(
        const ProfileUpdate(
          userId: dara,
          fullName: 'Dara Sok',
          phone: '098 765 432',
        ),
      ),
      fails('This phone number is already registered.'),
    );
    expect(
      auth.updateProfile(
        const ProfileUpdate(
          userId: dara,
          fullName: 'Dara Sok',
          email: 'staff@mos.coffee',
        ),
      ),
      fails('This email is already registered.'),
    );
  });

  test('an email or a phone number must stay', () {
    expect(
      auth.updateProfile(
        const ProfileUpdate(userId: dara, fullName: 'Dara Sok', email: ' '),
      ),
      fails('Keep an email or a phone number.'),
    );
  });

  test('FR-30: the current password is checked first', () async {
    expect(
      auth.changePassword(
        userId: dara,
        currentPassword: 'wrong-one',
        newPassword: 'brand-new-pass',
      ),
      fails('Your current password is incorrect.'),
    );
    await auth.changePassword(
      userId: dara,
      currentPassword: MockAuthRepository.demoPassword,
      newPassword: 'brand-new-pass',
    );
    expect(
      auth.signIn(
        identifier: 'dara@example.com',
        password: MockAuthRepository.demoPassword,
      ),
      fails('Incorrect email/phone or password.'),
    );
    final user = await auth.signIn(
      identifier: 'dara@example.com',
      password: 'brand-new-pass',
    );
    expect(user.id, dara);
  });

  test('the session shows the saved profile at once', () async {
    final container = ProviderContainer.test(
      overrides: testBackend().overrides,
    );
    final notifier = container.read(authControllerProvider.notifier);
    await notifier.signIn(
      identifier: 'dara@example.com',
      password: MockAuthRepository.demoPassword,
    );
    await notifier.updateProfile(
      fullName: 'Dara Chan',
      email: 'dara@example.com',
      phone: '017 222 333',
    );
    final user = container.read(authControllerProvider).user!;
    expect(user.fullName, 'Dara Chan');
    expect(user.phone, '017222333');
    expect(user.initials, 'DC');
  });
}
