import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/account/notification_settings_controller.dart';
import 'package:mos_app/controllers/auth/auth_controller.dart';
import 'package:mos_app/screens/account/change_password_screen.dart';
import 'package:mos_app/screens/account/edit_profile_screen.dart';
import 'package:mos_app/screens/auth/login_screen.dart';
import 'package:mos_app/screens/orders/orders_screen.dart';
import 'package:mos_app/widgets/account/settings_row.dart';

import '../../helpers.dart';

/// SA 2.0 §4.2.5.2 Profile (FR-03): what a guest and a customer each see
/// on the fourth tab, and where every row goes.
void main() {
  Future<void> openProfileTab(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(NavigationDestination, 'Profile'));
    await tester.pumpAndSettle();
  }

  /// Signs in as the demo customer Dara and opens the profile tab.
  Future<ProviderContainer> openProfileAsDara(WidgetTester tester) async {
    final container = await pumpMosApp(tester);
    await signInAsDara(tester);
    await openProfileTab(tester);
    return container;
  }

  Future<ProviderContainer> openProfileAsGuest(WidgetTester tester) async {
    final container = await pumpMosApp(tester);
    await continueAsGuest(tester);
    await openProfileTab(tester);
    return container;
  }

  testWidgets('FR-01: a guest sees only the two rows a guest can use', (
    tester,
  ) async {
    await openProfileAsGuest(tester);

    expect(find.text('Profile'), findsNWidgets(2)); // page title + tab label
    expect(find.text('Guest'), findsOneWidget);
    expect(find.text('Log in to place orders.'), findsOneWidget);
    // Notifications and Help & support, nothing that needs an account.
    expect(find.byType(SettingsRow), findsNWidgets(2));
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Help & support'), findsOneWidget);
    expect(find.text('Change Password'), findsNothing);
    expect(find.text('Order history'), findsNothing);
    expect(find.text('Sign out'), findsNothing);
    expect(find.text('MOS Coffee · v1.0.0'), findsOneWidget);
  });

  testWidgets('BR-06: tapping the guest card opens the login page', (
    tester,
  ) async {
    await openProfileAsGuest(tester);
    await tester.tap(find.text('Guest'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('FR-03: a customer sees their name, email, phone and initials', (
    tester,
  ) async {
    await openProfileAsDara(tester);

    expect(find.text('Dara Sok'), findsOneWidget);
    expect(find.text('dara@example.com'), findsOneWidget);
    expect(find.text('012345678'), findsOneWidget);
    expect(find.text('DS'), findsOneWidget);
    // Change Password, Order history, Notifications, Help & support,
    // and Sign out on its own card.
    expect(find.byType(SettingsRow), findsNWidgets(5));
  });

  testWidgets('FR-16: the notifications switch turns the setting off', (
    tester,
  ) async {
    final container = await openProfileAsDara(tester);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(container.read(notificationsEnabledProvider).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('"Help & support" opens the support sheet', (tester) async {
    await openProfileAsDara(tester);
    await tester.tap(find.text('Help & support'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Help & Support'), findsOneWidget);
    // Over the whole screen, tabs included: the sheet reaches the bottom
    // edge (917) instead of stopping above the navigation bar, so the
    // tabs cannot be tapped while it is open.
    expect(tester.getRect(find.byType(BottomSheet)).bottom, 917);
  });

  testWidgets('"Order history" switches to the orders tab', (tester) async {
    await openProfileAsDara(tester);
    // The orders tab has never been opened, so its page is not built yet.
    expect(find.byType(OrdersScreen), findsNothing);

    await tester.tap(find.text('Order history'));
    await tester.pumpAndSettle();

    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2, // Home, Menu, Orders, Profile
    );
  });

  testWidgets('FR-30: "Change Password" opens the change password page', (
    tester,
  ) async {
    await openProfileAsDara(tester);
    expect(find.byType(ChangePasswordScreen), findsNothing);

    await tester.tap(find.text('Change Password'));
    await tester.pumpAndSettle();

    expect(find.byType(ChangePasswordScreen), findsOneWidget);
    expect(find.text('Dara Sok'), findsNothing); // the profile is covered
  });

  testWidgets('the pencil opens "Edit Personal Info"', (tester) async {
    await openProfileAsDara(tester);
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.text('Edit Personal Info'), findsOneWidget);
  });

  testWidgets('FR-03: signing out ends the session and shows login', (
    tester,
  ) async {
    final container = await openProfileAsDara(tester);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(container.read(authControllerProvider).hasSession, isFalse);
    expect(container.read(authControllerProvider).user, isNull);
  });
}
