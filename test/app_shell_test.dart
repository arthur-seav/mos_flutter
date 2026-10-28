import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('after continuing as guest, the four tabs are shown', (
    tester,
  ) async {
    await pumpMosApp(tester);
    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['Home', 'Menu', 'Orders', 'Profile']) {
      expect(find.widgetWithText(NavigationDestination, label), findsOneWidget);
    }
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 0);
  });

  testWidgets('tapping a tab switches the page', (tester) async {
    await pumpMosApp(tester);
    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Orders'));
    await tester.pumpAndSettle();

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 2);
  });
}
