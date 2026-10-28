import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/data/models/cart_item.dart';
import 'package:mos_app/data/models/money.dart';
import 'package:mos_app/data/models/product.dart';
import 'package:mos_app/controllers/cart/cart_controller.dart';
import 'package:mos_app/screens/cart/cart_screen.dart';
import 'package:mos_app/widgets/cart/cart_bar.dart';
import 'package:mos_app/widgets/menu/add_button.dart';
import 'package:mos_app/widgets/menu/product_tile.dart';

import '../../helpers.dart';

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
    expect(find.text('7 items'), findsOneWidget);
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
    expect(names, ['Caramel Latte', 'Latte', 'Matcha Latte']);
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

  testWidgets('FR-10: no cart bar while the cart is empty', (tester) async {
    await openMenu(tester);

    expect(find.byType(CartBar), findsNothing);
    expect(find.text('View cart'), findsNothing);
  });

  testWidgets('FR-10: the cart bar shows the count and total, and opens '
      'the cart', (tester) async {
    final container = await pumpMosApp(tester);
    await continueAsGuest(tester);
    container
        .read(cartControllerProvider.notifier)
        .add(
          CartItem(
            product: Product(
              id: 18,
              categoryId: 1,
              name: 'Latte',
              basePrice: Money.dollars(3),
            ),
            options: const [],
            quantity: 2,
          ),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Menu'));
    await tester.pumpAndSettle();

    expect(find.byType(CartBar), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text(r'$6.00'), findsOneWidget);

    await tester.tap(find.byType(CartBar));
    await tester.pumpAndSettle();

    expect(find.byType(CartScreen), findsOneWidget);
    expect(find.text('Your cart'), findsOneWidget);
  });

  testWidgets('FR-10: the last drink can scroll clear of the cart bar', (
    tester,
  ) async {
    final container = await pumpMosApp(tester);
    await continueAsGuest(tester);
    container
        .read(cartControllerProvider.notifier)
        .add(
          CartItem(
            product: Product(
              id: 18,
              categoryId: 1,
              name: 'Latte',
              basePrice: Money.dollars(3),
            ),
            options: const [],
            quantity: 1,
          ),
        );
    await tester.tap(find.widgetWithText(NavigationDestination, 'Menu'));
    await tester.pumpAndSettle();

    final list = find.descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    );
    // All the way down. ListView only measures the items it has built,
    // so the end moves while scrolling; repeat until it stops moving.
    final position = tester.state<ScrollableState>(list.first).position;
    for (var i = 0; i < 10 && position.pixels < position.maxScrollExtent; i++) {
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
    expect(position.pixels, position.maxScrollExtent);

    // The last drink on the menu ends above the bar, not under it.
    final last = find.widgetWithText(ProductTile, 'Lemon Soda');
    expect(last, findsOneWidget);
    expect(
      tester.getBottomLeft(last).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(CartBar)).dy),
    );
  });
}
