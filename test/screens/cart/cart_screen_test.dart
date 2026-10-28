import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/cart/cart_controller.dart';
import 'package:mos_app/data/mock/mock_menu_repository.dart';
import 'package:mos_app/data/models/drink_selection.dart';
import 'package:mos_app/data/repository_providers.dart';
import 'package:mos_app/router.dart';
import 'package:mos_app/screens/home/home_screen.dart';
import 'package:mos_app/screens/menu/customize_drink_screen.dart';

import '../../helpers.dart';

/// Loads a drink's customization and adds it to the cart, as the
/// customization page would via `DrinkSelection.initial(...).toCartItem()`.
Future<void> _addDrink(
  WidgetTester tester,
  ProviderContainer container,
  int productId,
) async {
  final repo = container.read(menuRepositoryProvider) as MockMenuRepository;
  late final dynamic customization;
  await tester.runAsync(() async {
    customization = await repo.fetchCustomization(productId);
  });
  final item = DrinkSelection.initial(customization).toCartItem();
  container.read(cartControllerProvider.notifier).add(item);
}

void _openCart(WidgetTester tester, ProviderContainer container) {
  container.read(routerProvider).push(AppRoutes.cart);
}

void main() {
  group('CartScreen', () {
    testWidgets('empty cart shows message and Browse menu goes to menu', (
      tester,
    ) async {
      final container = await pumpMosApp(tester);
      await continueAsGuest(tester);
      _openCart(tester, container);
      await tester.pumpAndSettle();

      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Browse menu'), findsOneWidget);
      expect(find.textContaining('item'), findsNothing);

      await tester.tap(find.text('Browse menu'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Your cart'), findsNothing);
    });

    testWidgets('shows lines with names, summaries, prices and item count', (
      tester,
    ) async {
      final container = await pumpMosApp(tester);
      await continueAsGuest(tester);
      await _addDrink(tester, container, 18); // Latte
      await _addDrink(tester, container, 4); // Caramel Latte
      _openCart(tester, container);
      await tester.pumpAndSettle();

      expect(find.text('2 items'), findsOneWidget);
      expect(find.text('Latte'), findsOneWidget);
      expect(find.text('Caramel Latte'), findsOneWidget);
      expect(find.textContaining('·'), findsWidgets);

      final cart = container.read(cartControllerProvider);
      for (final item in cart) {
        expect(find.text(item.lineTotal.format()), findsWidgets);
      }
    });

    testWidgets('TC-16: change quantity, remove a line, total updates', (
      tester,
    ) async {
      final container = await pumpMosApp(tester);
      await continueAsGuest(tester);
      await _addDrink(tester, container, 18); // Latte
      await _addDrink(tester, container, 1); // Espresso
      _openCart(tester, container);
      await tester.pumpAndSettle();

      expect(find.text('2 items'), findsOneWidget);

      await tester.tap(find.widgetWithIcon(InkWell, Icons.add).first);
      await tester.pumpAndSettle();

      final total = container.read(cartTotalProvider);
      expect(find.text(total.format()), findsWidgets);
      expect(find.text('3 items'), findsOneWidget);

      final espressoName = container
          .read(cartControllerProvider)
          .firstWhere((l) => l.product.name == 'Espresso')
          .product
          .name;
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.delete_outline).at(1),
      );
      await tester.pump(); // schedule the entrance animation
      await tester.pump(const Duration(milliseconds: 300)); // entrance done

      expect(find.text(espressoName), findsNothing);
      expect(find.textContaining('removed'), findsOneWidget);

      final newTotal = container.read(cartTotalProvider);
      expect(find.text(newTotal.format()), findsWidgets);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(find.text('Espresso'), findsOneWidget);
    });

    testWidgets('remove SnackBar with Undo auto-dismisses after its duration', (
      tester,
    ) async {
      final container = await pumpMosApp(tester);
      await continueAsGuest(tester);
      await _addDrink(tester, container, 18); // Latte
      _openCart(tester, container);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
      await tester.pump(); // schedule the entrance animation
      await tester.pump(
        const Duration(milliseconds: 300),
      ); // entrance done, timer starts

      expect(find.text('Undo'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5)); // timer fires, exit starts
      await tester.pump(
        const Duration(milliseconds: 300),
      ); // exit animation done

      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('Edit options opens CustomizeDrinkScreen in edit mode', (
      tester,
    ) async {
      final container = await pumpMosApp(tester);
      await continueAsGuest(tester);
      await _addDrink(tester, container, 18); // Latte
      _openCart(tester, container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit options'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomizeDrinkScreen), findsOneWidget);
      expect(find.textContaining('Save changes'), findsOneWidget);
    });

    testWidgets('TC-17: sold-out drink removed at checkout with message', (
      tester,
    ) async {
      final container = await pumpMosApp(tester);
      await continueAsGuest(tester);
      await _addDrink(tester, container, 18); // Latte
      await _addDrink(tester, container, 1); // Espresso
      final repo = container.read(menuRepositoryProvider) as MockMenuRepository;
      repo.markSoldOut(1); // Espresso

      _openCart(tester, container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go to checkout'));
      await tester.pumpAndSettle();

      expect(
        find.text('Espresso is sold out and was removed from your cart.'),
        findsOneWidget,
      );
      expect(find.text('Espresso'), findsNothing);
      expect(find.text('1 item'), findsOneWidget);

      final total = container.read(cartTotalProvider);
      expect(find.text(total.format()), findsWidgets);
    });

    testWidgets('nothing sold out shows checkout-next-step message', (
      tester,
    ) async {
      final container = await pumpMosApp(tester);
      await continueAsGuest(tester);
      await _addDrink(tester, container, 18); // Latte
      _openCart(tester, container);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go to checkout'));
      await tester.pumpAndSettle();

      expect(find.text('Checkout comes in the next step.'), findsOneWidget);
    });
  });
}
