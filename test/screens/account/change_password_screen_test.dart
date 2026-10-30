import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/auth/auth_controller.dart';
import 'package:mos_app/data/mock/mock_auth_repository.dart';
import 'package:mos_app/data/mock/mock_backend.dart';
import 'package:mos_app/data/repositories/auth_repository.dart';
import 'package:mos_app/router.dart';
import 'package:mos_app/screens/account/change_password_screen.dart';
import 'package:mos_app/screens/account/profile_screen.dart';
import 'package:mos_app/screens/auth/login_screen.dart';

import '../../helpers.dart';

void main() {
  /// Signs in as Dara and opens Change Password from the Profile tab,
  /// so there is a page to come back to.
  Future<ProviderContainer> openChangePassword(
    WidgetTester tester, {
    MockBackend? backend,
  }) async {
    final container = await pumpMosApp(tester, backend: backend);
    await signInAsDara(tester);
    container.read(routerProvider).go(AppRoutes.profile);
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);

    container.read(routerProvider).push(AppRoutes.changePassword);
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    return container;
  }

  Future<void> fillIn(
    WidgetTester tester, {
    required String current,
    required String newPassword,
    required String confirmation,
  }) async {
    await tester.enterText(fieldLabelled('Current Password'), current);
    await tester.enterText(fieldLabelled('New Password'), newPassword);
    await tester.enterText(fieldLabelled('Confirm New Password'), confirmation);
    await tester.pump();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('the page shows its title and the three password fields', (
    tester,
  ) async {
    await openChangePassword(tester);

    expect(find.text('Change Password'), findsOneWidget);
    expect(fieldLabelled('Current Password'), findsOneWidget);
    expect(fieldLabelled('New Password'), findsOneWidget);
    expect(fieldLabelled('Confirm New Password'), findsOneWidget);
    expect(find.byTooltip('Cancel'), findsOneWidget);
    expect(find.byTooltip('Save'), findsOneWidget);
  });

  testWidgets('FR-30: a wrong current password is refused and the page stays', (
    tester,
  ) async {
    final container = await openChangePassword(tester);
    await fillIn(
      tester,
      current: 'not-my-password',
      newPassword: 'brand-new-pass',
      confirmation: 'brand-new-pass',
    );
    await tapSave(tester);

    expect(find.text('Your current password is incorrect.'), findsOneWidget);
    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    // The old password still works, so nothing was changed.
    expect(container.read(authControllerProvider).isCustomer, isTrue);
  });

  testWidgets('the confirmation must repeat the new password', (tester) async {
    await openChangePassword(tester);
    await fillIn(
      tester,
      current: MockAuthRepository.demoPassword,
      newPassword: 'brand-new-pass',
      confirmation: 'brand-new-pasz',
    );
    await tapSave(tester);

    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(find.byType(ChangePasswordScreen), findsOneWidget);
  });

  testWidgets('the new password must differ from the current one', (
    tester,
  ) async {
    await openChangePassword(tester);
    await fillIn(
      tester,
      current: MockAuthRepository.demoPassword,
      newPassword: MockAuthRepository.demoPassword,
      confirmation: MockAuthRepository.demoPassword,
    );
    await tapSave(tester);

    expect(
      find.text('Choose a password different from your current one.'),
      findsOneWidget,
    );
    expect(find.byType(ChangePasswordScreen), findsOneWidget);
  });

  testWidgets('a short new password is refused', (tester) async {
    await openChangePassword(tester);
    await fillIn(
      tester,
      current: MockAuthRepository.demoPassword,
      newPassword: 'short12',
      confirmation: 'short12',
    );
    await tapSave(tester);

    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(find.byType(ChangePasswordScreen), findsOneWidget);
  });

  testWidgets('Cancel closes the page without changing anything', (
    tester,
  ) async {
    await openChangePassword(tester);
    await fillIn(
      tester,
      current: MockAuthRepository.demoPassword,
      newPassword: 'brand-new-pass',
      confirmation: 'brand-new-pass',
    );
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Password changed.'), findsNothing);
  });

  testWidgets(
    'FR-30: a successful change closes the page, and the new password '
    'signs in while the old one does not',
    (tester) async {
      final backend = testBackend();
      final container = await openChangePassword(tester, backend: backend);
      await fillIn(
        tester,
        current: MockAuthRepository.demoPassword,
        newPassword: 'brand-new-pass',
        confirmation: 'brand-new-pass',
      );
      await tapSave(tester);

      // Back on the Profile page, with the confirmation.
      expect(find.byType(ChangePasswordScreen), findsNothing);
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Password changed.'), findsOneWidget);
      // Changing the password does not sign the customer out.
      expect(container.read(authControllerProvider).isCustomer, isTrue);

      await tester.runAsync(() async {
        await expectLater(
          backend.auth.signIn(
            identifier: 'dara@example.com',
            password: 'brand-new-pass',
          ),
          completes,
        );
        await expectLater(
          backend.auth.signIn(
            identifier: 'dara@example.com',
            password: MockAuthRepository.demoPassword,
          ),
          throwsA(isA<AuthException>()),
        );
      });

      // Sign out and back in through the UI with the new password.
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.enterText(fieldLabelled('Email'), 'dara@example.com');
      await tester.enterText(fieldLabelled('Password'), 'brand-new-pass');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsNothing);
      expect(container.read(authControllerProvider).isCustomer, isTrue);

      // Let the confirmation snack bar close before the test ends.
      await tester.pumpAndSettle(const Duration(seconds: 5));
    },
  );
}
