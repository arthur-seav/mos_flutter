import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/auth/auth_controller.dart';
import 'package:mos_app/screens/account/edit_profile_screen.dart';
import 'package:mos_app/screens/account/profile_screen.dart';
import 'package:mos_app/widgets/common/labeled_text_field.dart';

import '../../helpers.dart';

/// SA 2.0 §4.2.5.2 Edit Personal Info (FR-04, TC-07): a customer changes
/// their details and the profile page shows them straight away.
void main() {
  /// The input of the field with this label, so the tests never depend on
  /// the order of the fields on the page.
  Finder fieldLabelled(String label) => find.descendant(
    of: find.ancestor(
      of: find.text(label),
      matching: find.byType(LabeledTextField),
    ),
    matching: find.byType(TextFormField),
  );

  /// Signs in as Dara, opens the profile tab and the edit page.
  Future<ProviderContainer> openEditProfile(WidgetTester tester) async {
    final container = await pumpMosApp(tester);
    await signInAsDara(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    return container;
  }

  /// Lets the "Profile saved." notice time out, so no timer is left.
  Future<void> waitForToastToClose(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  testWidgets('the form opens with the saved details filled in', (
    tester,
  ) async {
    await openEditProfile(tester);

    expect(find.text('Edit Personal Info'), findsOneWidget);
    expect(find.text('Dara Sok'), findsOneWidget);
    expect(find.text('dara@example.com'), findsOneWidget);
    expect(find.text('012345678'), findsOneWidget);
    // Dara has no date of birth yet.
    expect(find.text('Not set'), findsOneWidget);
  });

  testWidgets('TC-07: a new phone number is saved and shown on the profile', (
    tester,
  ) async {
    final container = await openEditProfile(tester);
    await tester.enterText(fieldLabelled('Phone Number'), '017 222 333');
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text('Profile saved.'), findsOneWidget);
    // Stored in one spelling, as the backend keeps it.
    expect(find.text('017222333'), findsOneWidget);
    expect(find.text('012345678'), findsNothing);
    expect(container.read(authControllerProvider).user!.phone, '017222333');
    await waitForToastToClose(tester);
  });

  testWidgets('a new name is saved and the initials follow it', (tester) async {
    await openEditProfile(tester);
    await tester.enterText(fieldLabelled('Full name'), 'Dara Chan');
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Dara Chan'), findsOneWidget);
    expect(find.text('DC'), findsOneWidget);
    await waitForToastToClose(tester);
  });

  testWidgets('TC-07: a phone number of another account is refused', (
    tester,
  ) async {
    // 098 765 432 belongs to Sreyneang Chan.
    final container = await openEditProfile(tester);
    await tester.enterText(fieldLabelled('Phone Number'), '098 765 432');
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('This phone number is already registered.'),
      findsOneWidget,
    );
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(container.read(authControllerProvider).user!.phone, '012345678');
  });

  testWidgets('FR-02: an email or a phone number must be kept', (tester) async {
    final container = await openEditProfile(tester);
    await tester.enterText(fieldLabelled('Email'), '');
    await tester.enterText(fieldLabelled('Phone Number'), '');
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an email or a phone number.'), findsOneWidget);
    expect(find.byType(EditProfileScreen), findsOneWidget);
    final user = container.read(authControllerProvider).user!;
    expect(user.email, 'dara@example.com');
    expect(user.phone, '012345678');
  });

  testWidgets('a badly typed email is refused before saving', (tester) async {
    final container = await openEditProfile(tester);
    await tester.enterText(fieldLabelled('Email'), 'dara@@example');
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email.'), findsOneWidget);
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(
      container.read(authControllerProvider).user!.email,
      'dara@example.com',
    );
  });

  testWidgets('a badly typed phone number is refused before saving', (
    tester,
  ) async {
    final container = await openEditProfile(tester);
    await tester.enterText(fieldLabelled('Phone Number'), '12');
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid mobile number.'), findsOneWidget);
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(container.read(authControllerProvider).user!.phone, '012345678');
  });

  testWidgets('Cancel closes the page and keeps the old details', (
    tester,
  ) async {
    final container = await openEditProfile(tester);
    await tester.enterText(fieldLabelled('Full name'), 'Someone Else');
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text('Dara Sok'), findsOneWidget);
    expect(container.read(authControllerProvider).user!.fullName, 'Dara Sok');
  });

  testWidgets('the date of birth is picked from a calendar and saved', (
    tester,
  ) async {
    final container = await openEditProfile(tester);
    await tester.tap(find.text('Not set'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    // The picker opens on today, Thursday 29 October 2026 (helpers.testNow).
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Thu, 29 Oct 2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(
      container.read(authControllerProvider).user!.dateOfBirth,
      DateTime(2026, 10, 29),
    );
    await waitForToastToClose(tester);
  });
}
