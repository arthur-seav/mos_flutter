import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/orders/my_orders_controller.dart';
import 'package:mos_app/controllers/orders/order_tracking_controller.dart';
import 'package:mos_app/data/mock/mock_backend.dart';
import 'package:mos_app/data/mock/mock_menu_repository.dart';
import 'package:mos_app/data/models/order.dart';
import 'package:mos_app/router.dart';
import 'package:mos_app/screens/auth/login_screen.dart';
import 'package:mos_app/screens/cart/cart_screen.dart';
import 'package:mos_app/screens/orders/order_tracking_screen.dart';
import 'package:mos_app/screens/orders/orders_screen.dart';
import 'package:mos_app/widgets/orders/list/order_card.dart';

import '../../helpers.dart';

/// The Orders tab (SA 2.0 §4.2.5.1, FR-18, TC-28).
///
/// Dara's seeded history, worked out from the SA test data and
/// `testNow()` = Thursday 29 October 2026, 10:12 AM:
///   #A1019  Completed  Oct 10, 8:45 AM   Mocha (sold out today)  $4.10
///   #A1007  Completed  Oct 6,  2:30 PM   Cappuccino, Flat White, Espresso
///                                        $3.20 + $3.40 + $2.00 = $8.60
///   #A0998  Cancelled  Sep 30, 9:05 AM   Caramel Latte           $3.50
/// A new paid order gets the next pickup code, #A1024.

/// A backend holding Dara's three past orders.
MockBackend historyBackend() =>
    MockBackend(latency: Duration.zero, clock: testNow, seedHistory: true);

/// Starts the app, signs in (or continues as a guest) and opens the
/// Orders tab. The polling timer is off: tests refresh by hand.
Future<ProviderContainer> openOrders(
  WidgetTester tester, {
  MockBackend? backend,
  bool guest = false,
}) async {
  final container = await pumpMosApp(
    tester,
    backend: backend ?? testBackend(),
    extraOverrides: [trackingPollProvider.overrideWithValue(null)],
  );
  if (guest) {
    await continueAsGuest(tester);
  } else {
    await signInAsDara(tester);
  }
  container.read(routerProvider).go(AppRoutes.orders);
  await tester.pumpAndSettle();
  expect(find.byType(OrdersScreen), findsOneWidget);
  return container;
}

/// Places and pays for one Latte (product 18, Medium + Hot + Normal
/// sugar), as checkout would. Returns the order the backend made.
Future<Order> placePaidOrder(WidgetTester tester, MockBackend backend) async {
  late final Order order;
  await tester.runAsync(() async {
    order = await backend.orders.createOrder(
      const OrderRequest(
        lines: [
          OrderLineRequest(
            productId: 18,
            optionIds: [
              MockMenuRepository.medium,
              MockMenuRepository.hot,
              MockMenuRepository.normalSugar,
            ],
            quantity: 1,
          ),
        ],
        pickupType: PickupType.asap,
      ),
    );
    final cards = await backend.cards.fetchCards();
    await backend.orders.payWithCard(orderId: order.id, cardId: cards.first.id);
  });
  return order;
}

/// Asks for the orders again, as pull-to-refresh and the poll timer do.
Future<void> refreshOrders(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.runAsync(
    () => container.read(myOrdersProvider.notifier).refresh(),
  );
  await tester.pumpAndSettle();
}

/// The "Reorder" button inside the card with this pickup code, so the
/// right order is reordered even as the list grows.
Finder reorderButtonOn(String code) => find.descendant(
  of: find.ancestor(of: find.text(code), matching: find.byType(OrderCard)),
  matching: find.text('Reorder'),
);

void main() {
  testWidgets('a guest is asked to log in, and "Log in" opens the login page', (
    tester,
  ) async {
    await openOrders(tester, guest: true);

    expect(find.text('Log in to see your orders'), findsOneWidget);
    expect(
      find.text(
        'Your orders and their status show up here once you have an account.',
      ),
      findsOneWidget,
    );
    expect(find.byType(OrderCard), findsNothing);

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('a customer with no orders sees the empty page', (tester) async {
    await openOrders(tester);

    expect(find.text('No orders yet'), findsOneWidget);
    expect(find.text('Your orders will show up here.'), findsOneWidget);
    expect(find.byType(OrderCard), findsNothing);
    // Nothing to group while there is nothing to show.
    expect(find.text('In progress'), findsNothing);
    expect(find.text('Past orders'), findsNothing);
  });

  testWidgets('past orders show their code, status, time, drinks and total', (
    tester,
  ) async {
    await openOrders(tester, backend: historyBackend());

    expect(find.text('Past orders'), findsOneWidget);
    // Nothing is on its way, so that section stays away.
    expect(find.text('In progress'), findsNothing);

    expect(find.text('#A1019'), findsOneWidget);
    expect(find.text('#A1007'), findsOneWidget);
    expect(find.text('#A0998'), findsOneWidget);
    expect(find.byType(OrderCard), findsNWidgets(3));

    // #A1019 and #A1007 were picked up; #A0998 was cancelled.
    expect(find.text('Completed'), findsNWidgets(2));
    expect(find.text('Cancelled'), findsOneWidget);

    expect(find.text('Oct 10 · 8:45 AM'), findsOneWidget);
    expect(find.text('Oct 6 · 2:30 PM'), findsOneWidget);
    expect(find.text('Sep 30 · 9:05 AM'), findsOneWidget);
    // Past orders are over, so they say nothing about pickup.
    expect(find.textContaining('Pickup'), findsNothing);

    expect(find.text('Cappuccino, Flat White, Espresso'), findsOneWidget);
    expect(find.text('Mocha'), findsOneWidget);
    expect(find.text(r'$8.60'), findsOneWidget);
    expect(find.text(r'$4.10'), findsOneWidget);

    // Reorder on each past order, and no tracking for orders that ended.
    expect(find.text('Reorder'), findsNWidgets(3));
    expect(find.text('Track order'), findsNothing);
  });

  testWidgets('a paid order is on its way, with its status and pickup', (
    tester,
  ) async {
    final backend = historyBackend();
    final container = await openOrders(tester, backend: backend);
    final order = await placePaidOrder(tester, backend);
    // Staff confirm it, then start making it (BR-08).
    backend.orders.staffAdvance(order.id);
    backend.orders.staffAdvance(order.id);
    await refreshOrders(tester, container);

    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('#A1024'), findsOneWidget);
    expect(find.text('Preparing'), findsOneWidget);
    expect(find.text('Today · 10:12 AM · Pickup ASAP'), findsOneWidget);
    expect(find.text('Latte'), findsOneWidget);
    expect(find.text('Track order'), findsOneWidget);

    // The history is still below it.
    expect(find.text('Past orders'), findsOneWidget);
    expect(find.byType(OrderCard), findsNWidgets(4));
  });

  testWidgets('"Track order" opens that order\'s tracking page', (
    tester,
  ) async {
    final backend = historyBackend();
    final container = await openOrders(tester, backend: backend);
    final order = await placePaidOrder(tester, backend);
    await refreshOrders(tester, container);

    await tester.tap(find.text('Track order'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderTrackingScreen), findsOneWidget);
    expect(
      tester
          .widget<OrderTrackingScreen>(find.byType(OrderTrackingScreen))
          .orderId,
      order.id,
    );
  });

  testWidgets('TC-28: Reorder puts #A1007\'s drinks back in the cart', (
    tester,
  ) async {
    await openOrders(tester, backend: historyBackend());

    await tester.ensureVisible(reorderButtonOn('#A1007'));
    await tester.tap(reorderButtonOn('#A1007'));
    await tester.pumpAndSettle();

    // The cart opens with the three drinks of that order, at today's
    // prices.
    expect(find.byType(CartScreen), findsOneWidget);
    expect(find.text('Cappuccino'), findsOneWidget);
    expect(find.text('Flat White'), findsOneWidget);
    expect(find.text('Espresso'), findsOneWidget);

    // Let the notice close, so no timer outlives the test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('TC-28: reordering sold-out drinks says so and stays put', (
    tester,
  ) async {
    await openOrders(tester, backend: historyBackend());

    // #A1019 is a Mocha, and Mocha is sold out today (BR-05).
    await tester.ensureVisible(reorderButtonOn('#A1019'));
    await tester.tap(reorderButtonOn('#A1019'));
    await tester.pumpAndSettle();

    expect(
      find.text('None of these drinks are available right now.'),
      findsOneWidget,
    );
    expect(find.byType(CartScreen), findsNothing);
    expect(find.byType(OrdersScreen), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
