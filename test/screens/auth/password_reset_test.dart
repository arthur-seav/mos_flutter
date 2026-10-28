import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/data/mock/mock_auth_repository.dart';
import 'package:mos_app/controllers/auth/auth_controller.dart';
import 'package:mos_app/screens/auth/forgot_password_screen.dart';
import 'package:mos_app/screens/auth/login_screen.dart';
import 'package:mos_app/screens/auth/reset_password_screen.dart';
import 'package:mos_app/widgets/auth/auth_status_view.dart';

import '../../helpers.dart';

void main() {
  Future<void> openForgotPassword(WidgetTester tester) async {
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
  }

  Future<void> verifyPhone(WidgetTester tester, String phone) async {
    await tester.enterText(find.byType(TextFormField), phone);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
  }

  testWidgets('TC-06: an unknown phone shows "Account not found."', (
    tester,
  ) async {
    await pumpMosApp(tester);
    await openForgotPassword(tester);
    await verifyPhone(tester, '011 999 888');

    expect(find.text('Account not found.'), findsOneWidget);
    expect(find.byType(ResetPasswordScreen), findsNothing);
  });

  testWidgets('the not-found error clears when the number is edited', (
    tester,
  ) async {
    await pumpMosApp(tester);
    await openForgotPassword(tester);
    await verifyPhone(tester, '011 999 888');

    await tester.enterText(find.byType(TextFormField), '011 999 88');
    await tester.pump();
    expect(find.text('Account not found.'), findsNothing);
  });

  testWidgets('an invalid number is caught before verifying', (tester) async {
    await pumpMosApp(tester);
    await openForgotPassword(tester);
    await verifyPhone(tester, '12345');
    expect(find.text('Enter a valid mobile number.'), findsOneWidget);
  });

  testWidgets('"Verifying account..." can be cancelled', (tester) async {
    await pumpMosApp(tester, latency: const Duration(seconds: 1));
    await openForgotPassword(tester);
    await tester.enterText(find.byType(TextFormField), '012 345 678');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pump();

    expect(find.text('Verifying account...'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pump();
    expect(find.text('Verifying account...'), findsNothing);

    // The answer arrives later and is ignored: no jump to the next step.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(ResetPasswordScreen), findsNothing);
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
  });

  testWidgets('new password and confirmation must match', (tester) async {
    await pumpMosApp(tester);
    await openForgotPassword(tester);
    await verifyPhone(tester, '012 345 678');
    expect(find.byType(ResetPasswordScreen), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'brand-new-pw');
    await tester.enterText(find.byType(TextFormField).at(1), 'different-pw');
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets(
    'TC-05: reset, then the new password works and the old does not',
    (tester) async {
      final container = await pumpMosApp(tester);
      await openForgotPassword(tester);
      await verifyPhone(tester, '012 345 678');

      await tester.enterText(find.byType(TextFormField).at(0), 'brand-new-pw');
      await tester.enterText(find.byType(TextFormField).at(1), 'brand-new-pw');
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      // Let the (zero-latency) mock answer, then draw the next frame.
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();
      expect(find.text('Password reset successful.'), findsOneWidget);

      await tester.pump(authStatusDisplayTime);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AuthStatusView), findsNothing);

      // Old password refused.
      await tester.enterText(find.byType(TextFormField).at(0), '012345678');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        MockAuthRepository.demoPassword,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Incorrect email/phone or password.'), findsOneWidget);

      // New password accepted.
      await tester.enterText(find.byType(TextFormField).at(1), 'brand-new-pw');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(container.read(authControllerProvider).isCustomer, isTrue);
    },
  );
}
