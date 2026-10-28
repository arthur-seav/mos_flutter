import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/features/auth/controllers/auth_controller.dart';
import 'package:mos_app/features/auth/screens/login_screen.dart';
import 'package:mos_app/features/auth/screens/sign_up_screen.dart';
import 'package:mos_app/features/auth/widgets/auth_status_view.dart';

import '../../../helpers.dart';

void main() {
  Finder field(int index) => find.byType(TextFormField).at(index);

  Future<void> openSignUp(WidgetTester tester) async {
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);
  }

  Future<void> fill(
    WidgetTester tester, {
    String name = 'Sophat Samnang',
    String email = '',
    String phone = '',
    String password = 'longenough',
  }) async {
    await tester.enterText(field(0), name);
    await tester.enterText(field(1), email);
    await tester.enterText(field(2), phone);
    await tester.enterText(field(3), password);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
  }

  testWidgets('"Create an account" on login opens the sign-up page', (
    tester,
  ) async {
    await pumpMosApp(tester);
    await openSignUp(tester);
    expect(
      find.text('Save your favourites and track every order.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'TC-02: valid details create the account, show success, then Home',
    (tester) async {
      final container = await pumpMosApp(tester);
      await openSignUp(tester);
      await fill(tester, email: 'new@example.com', phone: '017 222 333');
      await submit(tester);
      // Let the (zero-latency) mock answer, then draw the next frame.
      // A bare pump() does not move the fake clock, so timers never fire.
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();

      expect(find.text('Account created successfully.'), findsOneWidget);
      expect(container.read(authControllerProvider).hasSession, isFalse);

      await tester.pump(authStatusDisplayTime);
      await tester.pumpAndSettle();

      final session = container.read(authControllerProvider);
      expect(session.isCustomer, isTrue);
      expect(session.user?.fullName, 'Sophat Samnang');
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('TC-03: a registered email shows an error and creates nothing', (
    tester,
  ) async {
    final container = await pumpMosApp(tester);
    await openSignUp(tester);
    await fill(tester, email: 'dara@example.com');
    await submit(tester);
    await tester.pumpAndSettle();

    expect(find.text('This email is already registered.'), findsOneWidget);
    expect(find.byType(AuthStatusView), findsNothing);
    expect(container.read(authControllerProvider).hasSession, isFalse);
  });

  testWidgets('TC-03: a registered phone number shows an error', (
    tester,
  ) async {
    await pumpMosApp(tester);
    await openSignUp(tester);
    await fill(tester, phone: '012 345 678');
    await submit(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('This phone number is already registered.'),
      findsOneWidget,
    );
  });

  testWidgets('needs an email or a phone number', (tester) async {
    await pumpMosApp(tester);
    await openSignUp(tester);
    await fill(tester);
    await submit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Enter an email or a phone number.'), findsOneWidget);
  });

  testWidgets('password must be at least 8 characters', (tester) async {
    await pumpMosApp(tester);
    await openSignUp(tester);
    await fill(tester, email: 'new@example.com', password: 'short');
    await submit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Use at least 8 characters.'), findsOneWidget);
  });

  testWidgets('invalid email and phone are reported', (tester) async {
    await pumpMosApp(tester);
    await openSignUp(tester);
    await fill(tester, email: 'dara@', phone: '12345');
    await submit(tester);
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email.'), findsOneWidget);
    expect(find.text('Enter a valid mobile number.'), findsOneWidget);
  });

  testWidgets('"Sign in" and the back button return to login', (tester) async {
    await pumpMosApp(tester);
    await openSignUp(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await openSignUp(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
