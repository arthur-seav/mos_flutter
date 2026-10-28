import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/features/menu/widgets/add_button.dart';
import 'package:mos_app/features/menu/widgets/product_tile.dart';

import '../../../helpers.dart';

void main() {
  Future<void> openMenu(WidgetTester tester) async {
    await pumpMosApp(tester);
    await continueAsGuest(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Menu'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.tap(find.byTooltip('Search drinks'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
  }

  testWidgets('FR-06/07: drinks by category with description and price', (
    tester,
  ) async {
    await openMenu(tester);

    expect(find.text('Menu'), findsWidgets);
    expect(find.text('6 items'), findsOneWidget);
    final espresso = find.widgetWithText(ProductTile, 'Espresso');
    expect(espresso, findsOneWidget);
    expect(
      find.descendant(
        of: espresso,
        matching: find.text('Double shot, rich and bold'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: espresso, matching: find.text(r'$2.00')),
      findsOneWidget,
    );
  });

  testWidgets('a chip shows only that category', (tester) async {
    await openMenu(tester);
    await tester.tap(find.text('Frappé'));
    await tester.pumpAndSettle();

    expect(find.text('Matcha Frappé'), findsOneWidget);
    expect(find.text('Espresso'), findsNothing);
  });

  testWidgets('TC-08: "latte" shows only matching drinks', (tester) async {
    await openMenu(tester);
    await search(tester, 'latte');

    final names = tester
        .widgetList<ProductTile>(find.byType(ProductTile))
        .map((t) => t.product.name);
    expect(names, ['Caramel Latte', 'Matcha Latte']);
  });

  testWidgets('TC-08: "pizza" shows a no-result message', (tester) async {
    await openMenu(tester);
    await search(tester, 'pizza');

    expect(find.text('No drinks match "pizza"'), findsOneWidget);
    expect(find.byType(ProductTile), findsNothing);
  });

  testWidgets('closing search shows the whole menu again', (tester) async {
    await openMenu(tester);
    await search(tester, 'pizza');
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();

    expect(find.byType(ProductTile), findsWidgets);
    expect(find.text('Menu'), findsWidgets);
  });

  testWidgets('TC-09: a sold-out drink is shown but cannot be added', (
    tester,
  ) async {
    await openMenu(tester);
    final mocha = find.widgetWithText(ProductTile, 'Mocha');
    // The drink list, not the sideways category chips.
    final list = find.descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(mocha, 200, scrollable: list.first);

    expect(
      find.descendant(of: mocha, matching: find.byType(SoldOutTag)),
      findsOneWidget,
    );
    expect(find.byTooltip('Add Mocha'), findsNothing);
  });
}
