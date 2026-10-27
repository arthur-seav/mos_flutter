import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/app.dart';

void main() {
  testWidgets('app starts on Home and shows the four tabs', (tester) async {
    await tester.pumpWidget(const MosApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['Home', 'Menu', 'Orders', 'Profile']) {
      expect(find.widgetWithText(NavigationDestination, label), findsOneWidget);
    }
    // Home is selected, so its page title is on screen.
    expect(find.text('Coming in a later step.'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Center), matching: find.text('Home')),
      findsOneWidget,
    );
  });

  testWidgets('tapping a tab switches the page', (tester) async {
    await tester.pumpWidget(const MosApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Orders'));
    await tester.pumpAndSettle();

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, 2);
  });
}
