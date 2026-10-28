import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/cart/cart_controller.dart';
import 'package:mos_app/data/mock/mock_menu_repository.dart';
import 'package:mos_app/data/models/drink_selection.dart';
import 'package:mos_app/data/models/product_customization.dart';
import 'package:mos_app/data/repository_providers.dart';
import 'package:mos_app/router.dart';
import 'package:mos_app/screens/cart/cart_screen.dart';
import 'package:mos_app/screens/menu/customize_drink_screen.dart';
import 'package:mos_app/screens/menu/menu_screen.dart';
import 'package:mos_app/widgets/cart/add_more_button.dart';
import 'package:mos_app/widgets/cart/cart_line_card.dart';
import 'package:mos_app/widgets/common/selectable_pill.dart';

import '../../helpers.dart';

// Prices with each drink's defaults, worked out from the SA test data
// (not read back from the app):
//   Latte          $3.00 + Medium $0.50 = $3.50
//   Caramel Latte  $3.50 + Medium $0.50 = $4.00
//   Espresso       $2.00 + Double $0.00 = $2.00
const latte = 18, caramelLatte = 4, espresso = 1;

/// Adds a drink with its default options, as "Add to cart" would.
Future<void> addDrink(
  WidgetTester tester,
  ProviderContainer container,
  int productId,
) async {
  final repo = container.read(menuRepositoryProvider);
  late final ProductCustomization customization;
  await tester.runAsync(() async {
    customization = await repo.fetchCustomization(productId);
  });
  container
      .read(cartControllerProvider.notifier)
      .add(DrinkSelection.initial(customization).toCartItem());
}

/// Starts the app as a guest with [drinks] in the cart and opens the cart.
Future<ProviderContainer> openCart(
  WidgetTester tester, [
  List<int> drinks = const [],
]) async {
  final container = await pumpMosApp(tester);
  await continueAsGuest(tester);
  for (final id in drinks) {
    await addDrink(tester, container, id);
  }
  container.read(routerProvider).push(AppRoutes.cart);
  await tester.pumpAndSettle();
  expect(find.byType(CartScreen), findsOneWidget);
  return container;
}

/// The Total row's amount.
String totalText(WidgetTester tester) {
  final row = find.ancestor(of: find.text('Total'), matching: find.byType(Row));
  final texts = tester
      .widgetList<Text>(
        find.descendant(of: row.first, matching: find.byType(Text)),
      )
      .map((t) => t.data)
      .toList();
  return texts.last!;
}

Finder card(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(CartLineCard));

void main() {
  testWidgets('empty cart: message, and "Browse menu" opens the Menu tab', (
    tester,
  ) async {
    await openCart(tester);

    expect(find.text('Your cart is empty'), findsOneWidget);
    expect(find.textContaining('item'), findsNothing);
    expect(find.text('Go to checkout'), findsNothing);

    await tester.tap(find.text('Browse menu'));
    await tester.pumpAndSettle();
    expect(find.byType(CartScreen), findsNothing);
    expect(find.byType(MenuScreen), findsOneWidget);
  });

  testWidgets('each line shows its name, options and price', (tester) async {
    await openCart(tester, [latte, caramelLatte]);

    expect(find.text('2 items'), findsOneWidget);
    expect(
      find.descendant(
        of: card('Latte'),
        matching: find.text('Medium · Hot · Regular sugar'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card('Latte'), matching: find.text(r'$3.50')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card('Caramel Latte'),
        matching: find.text('Medium · Iced · Less ice · Regular sugar'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card('Caramel Latte'), matching: find.text(r'$4.00')),
      findsOneWidget,
    );
    expect(totalText(tester), r'$7.50');
  });

  testWidgets('TC-16: change one quantity, remove the other; total follows', (
    tester,
  ) async {
    final container = await openCart(tester, [latte, espresso]);
    expect(totalText(tester), r'$5.50');

    await tester.tap(
      find.descendant(
        of: card('Latte'),
        matching: find.byTooltip('Increase quantity'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 items'), findsOneWidget);
    expect(
      find.descendant(of: card('Latte'), matching: find.text(r'$7.00')),
      findsOneWidget,
    );
    expect(totalText(tester), r'$9.00');

    await tester.tap(find.byTooltip('Remove Espresso'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Espresso'), findsNothing);
    expect(find.text('Espresso removed'), findsOneWidget);
    expect(totalText(tester), r'$7.00');
    expect(find.text('2 items'), findsOneWidget);

    // Undo puts it back where it was.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(container.read(cartControllerProvider).map((l) => l.product.name), [
      'Latte',
      'Espresso',
    ]);
    expect(totalText(tester), r'$9.00');
  });

  testWidgets('the "removed" bar closes by itself', (tester) async {
    await openCart(tester, [latte]);
    await tester.tap(find.byTooltip('Remove Latte'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Undo'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('"Add more items" has a dashed outline and opens the menu', (
    tester,
  ) async {
    await openCart(tester, [latte]);
    expect(
      find.descendant(
        of: find.byType(AddMoreButton),
        matching: find.byType(DottedBorder),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Add more items'));
    await tester.pumpAndSettle();
    expect(find.byType(MenuScreen), findsOneWidget);
    expect(find.byType(CartScreen), findsNothing);
  });

  testWidgets('"Edit options" opens the drink with the line\'s choices', (
    tester,
  ) async {
    await openCart(tester, [caramelLatte]);
    await tester.tap(find.text('Edit options'));
    await tester.pumpAndSettle();

    expect(find.byType(CustomizeDrinkScreen), findsOneWidget);
    expect(find.text(r'Save changes · $4.00'), findsOneWidget);
    final medium = tester.widget<SelectablePill>(
      find.byWidgetPredicate(
        (w) => w is SelectablePill && w.fullLabel == r'Medium +$0.00',
      ),
    );
    expect(medium.selected, isTrue);
  });

  testWidgets('TC-17: a drink that sold out is taken out at checkout', (
    tester,
  ) async {
    final container = await openCart(tester, [latte, espresso]);
    (container.read(menuRepositoryProvider) as MockMenuRepository).markSoldOut(
      espresso,
    );

    await tester.tap(find.text('Go to checkout'));
    await tester.pumpAndSettle();

    expect(
      find.text('Espresso is sold out and was removed from your cart.'),
      findsOneWidget,
    );
    expect(find.text('Espresso'), findsNothing);
    expect(find.text('1 item'), findsOneWidget);
    expect(totalText(tester), r'$3.50');
  });

  testWidgets('nothing sold out: the cart stays, checkout comes next', (
    tester,
  ) async {
    final container = await openCart(tester, [latte]);
    await tester.tap(find.text('Go to checkout'));
    await tester.pumpAndSettle();

    expect(find.text('Checkout comes in the next step.'), findsOneWidget);
    expect(container.read(cartControllerProvider), hasLength(1));
  });
}
