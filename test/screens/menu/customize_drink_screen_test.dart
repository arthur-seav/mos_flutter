import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/cart/cart_controller.dart';
import 'package:mos_app/screens/menu/customize_drink_screen.dart';
import 'package:mos_app/widgets/common/selectable_pill.dart';

import '../../helpers.dart';

void main() {
  Future<dynamic> openDrink(WidgetTester tester, String name) async {
    final container = await pumpMosApp(tester);
    await continueAsGuest(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Menu'));
    await tester.pumpAndSettle();
    final add = find.byTooltip('Add $name');
    final list = find.descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(add, 200, scrollable: list.first);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(find.byType(CustomizeDrinkScreen), findsOneWidget);
    return container;
  }

  Finder pill(String label) => find.widgetWithText(SelectablePill, label);

  Future<void> tapPill(WidgetTester tester, String label) async {
    await tester.ensureVisible(pill(label));
    await tester.tap(pill(label));
    await tester.pumpAndSettle();
  }

  bool isSelected(WidgetTester tester, String label) =>
      tester.widget<SelectablePill>(pill(label)).selected;

  Finder addToCartButton() => find.byWidgetPredicate(
    (w) =>
        w is FilledButton &&
        w.child is Text &&
        (w.child! as Text).data!.startsWith('Add to cart'),
  );

  String buttonText(WidgetTester tester) =>
      ((tester.widget<FilledButton>(addToCartButton())).child! as Text).data!;

  testWidgets('TC-11: Caramel Latte opens with its default options', (
    tester,
  ) async {
    await openDrink(tester, 'Caramel Latte');
    for (final label in [r'Medium +$0.50', 'Iced', 'Less', '50%']) {
      expect(isSelected(tester, label), isTrue, reason: label);
    }
    expect(find.text(r'from $3.50'), findsOneWidget);
    // Pills are as wide as their text and sit side by side, not one per row.
    expect(tester.getSize(pill('Small')).width, lessThan(120));
    expect(
      tester.getTopLeft(pill('Small')).dy,
      tester.getTopLeft(pill(r'Medium +$0.50')).dy,
    );
    expect(buttonText(tester), r'Add to cart · $4.00');
  });

  testWidgets('TC-10: Espresso has no ice level, temperature is Hot only', (
    tester,
  ) async {
    await openDrink(tester, 'Espresso');
    expect(find.text('Ice level'), findsNothing);
    expect(pill('Iced'), findsNothing);
    expect(isSelected(tester, 'Hot'), isTrue);
  });

  testWidgets('BR-01: choosing Hot hides the ice level', (tester) async {
    await openDrink(tester, 'Caramel Latte');
    expect(find.text('Ice level'), findsOneWidget);
    await tapPill(tester, 'Hot');
    expect(find.text('Ice level'), findsNothing);
  });

  testWidgets('TC-14: the price updates on every tap; total \$9.20', (
    tester,
  ) async {
    await openDrink(tester, 'Latte');
    expect(buttonText(tester), r'Add to cart · $3.50');
    await tapPill(tester, r'Large +$1.00');
    expect(buttonText(tester), r'Add to cart · $4.00');
    await tapPill(tester, r'Oat milk +$0.60');
    expect(buttonText(tester), r'Add to cart · $4.60');
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pumpAndSettle();
    expect(buttonText(tester), r'Add to cart · $9.20');
  });

  testWidgets('TC-15: Americano shows its own Large price', (tester) async {
    await openDrink(tester, 'Americano');
    expect(pill(r'Large +$0.50'), findsOneWidget);
    await tapPill(tester, r'Large +$0.50');
    expect(buttonText(tester), r'Add to cart · $3.00');
  });

  testWidgets('TC-13: a 4th add-on is refused with a message', (tester) async {
    await openDrink(tester, 'Caramel Latte');
    for (final label in [
      r'Oat milk +$0.60',
      r'Extra shot +$0.50',
      r'Vanilla syrup +$0.40',
      r'Whipped cream +$0.40',
    ]) {
      await tapPill(tester, label);
    }
    expect(isSelected(tester, r'Whipped cream +$0.40'), isFalse);
    expect(find.text('You can choose up to 3 add-ons.'), findsOneWidget);
  });

  testWidgets('TC-12: without a size, the drink is not added', (tester) async {
    final container = await openDrink(tester, 'Americano');
    await tester.tap(addToCartButton());
    await tester.pumpAndSettle();

    expect(find.text('Please choose a size.'), findsOneWidget);
    expect(find.byType(CustomizeDrinkScreen), findsOneWidget);
    expect(container.read(cartControllerProvider), isEmpty);
  });

  testWidgets('"Add to cart" adds the drink and goes back', (tester) async {
    final container = await openDrink(tester, 'Caramel Latte');
    await tester.tap(addToCartButton());
    await tester.pumpAndSettle();

    expect(find.byType(CustomizeDrinkScreen), findsNothing);
    final cart = container.read(cartControllerProvider);
    expect(cart.single.product.name, 'Caramel Latte');
    expect(cart.single.optionSummary, 'Medium · Iced · Less · 50%');
    expect(
      find.text('Added to cart · Caramel Latte · Medium · Iced · Less · 50%'),
      findsOneWidget,
    );
  });

  testWidgets('a sold-out drink cannot be opened from the menu', (
    tester,
  ) async {
    await pumpMosApp(tester);
    await continueAsGuest(tester);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Menu'));
    await tester.pumpAndSettle();
    final list = find.descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('Mocha'),
      200,
      scrollable: list.first,
    );
    await tester.tap(find.text('Mocha'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomizeDrinkScreen), findsNothing);
  });
}
