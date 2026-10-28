import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/data/mock/mock_auth_repository.dart';
import 'package:mos_app/features/auth/auth_controller.dart';
import 'package:mos_app/features/auth/login_screen.dart';

import '../../helpers.dart';

void main() {
  Finder emailField() => find.byType(TextFormField).at(0);
  Finder passwordField() => find.byType(TextFormField).at(1);

  testWidgets('the app opens on the login page', (tester) async {
    await pumpMosApp(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('empty form shows field errors and does not sign in', (
    tester,
  ) async {
    final auth = await pumpMosApp(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your email or phone number.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(auth.hasSession, isFalse);
  });

  testWidgets('TC-04: wrong password shows an error and stays on login', (
    tester,
  ) async {
    await pumpMosApp(tester);
    await tester.enterText(emailField(), 'dara@example.com');
    await tester.enterText(passwordField(), 'wrong-password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email/phone or password.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('the error disappears when the user edits a field', (
    tester,
  ) async {
    await pumpMosApp(tester);
    await tester.enterText(emailField(), 'dara@example.com');
    await tester.enterText(passwordField(), 'wrong-password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.enterText(passwordField(), 'something-else');
    await tester.pump();
    expect(find.text('Incorrect email/phone or password.'), findsNothing);
  });

  testWidgets('correct details sign in and land on Home', (tester) async {
    final auth = await pumpMosApp(tester);
    await tester.enterText(emailField(), 'dara@example.com');
    await tester.enterText(passwordField(), MockAuthRepository.demoPassword);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(auth.status, SessionStatus.customer);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('TC-01: continue as guest goes to Home without logging in', (
    tester,
  ) async {
    final auth = await pumpMosApp(tester);
    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();

    expect(auth.isGuest, isTrue);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('signing out from Profile returns to the login page', (
    tester,
  ) async {
    await pumpMosApp(tester);
    await tester.enterText(emailField(), 'dara@example.com');
    await tester.enterText(passwordField(), MockAuthRepository.demoPassword);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Signed in as Dara Sok'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
