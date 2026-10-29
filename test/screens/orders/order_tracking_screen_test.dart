import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/cart/cart_controller.dart';
import 'package:mos_app/controllers/orders/order_tracking_controller.dart';
import 'package:mos_app/data/mock/mock_backend.dart';
import 'package:mos_app/data/mock/mock_menu_repository.dart';
import 'package:mos_app/data/models/order.dart';
import 'package:mos_app/router.dart';
import 'package:mos_app/screens/cart/cart_screen.dart';
import 'package:mos_app/screens/home/home_screen.dart';
import 'package:mos_app/screens/orders/order_tracking_screen.dart';

import '../../helpers.dart';

/// SA 2.0 §4.2.4 Order Tracking (TC-24 to TC-28).
///
/// Every test places the same order: one Latte, Medium, Hot, Normal
/// sugar ($3.00 + $0.50 = $3.50), paid by card at 10:12 AM, pickup code
/// A1024. Polling is switched off so each test says exactly when the
/// page asks the backend again.
void main() {
  /// The one order under test. Its id is always 1: the mock backend
  /// starts counting there and no test places a second order.
  const orderId = 1;

  /// Signs in as Dara, places and pays for the Latte, then opens the
  /// tracking page for it.
  Future<ProviderContainer> openTracking(
    WidgetTester tester,
    MockBackend backend,
  ) async {
    final container = await pumpMosApp(
      tester,
      backend: backend,
      extraOverrides: [trackingPollProvider.overrideWithValue(null)],
    );
    await signInAsDara(tester);
    // Backend calls run in real async; the widget test runs on fake time.
    await tester.runAsync(() async {
      final order = await backend.orders.createOrder(
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
      await backend.orders.payWithCard(
        orderId: order.id,
        cardId: cards.first.id,
      );
    });
    // push() only completes when the page is popped, so it is not awaited.
    unawaited(container.read(routerProvider).push(AppRoutes.order(orderId)));
    await tester.pumpAndSettle();
    return container;
  }

  /// Asks the backend for the order again, the way the poll timer would.
  /// Not awaited directly: the repository's delay is a timer that only
  /// fires while the test pumps.
  Future<void> refreshTracking(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    unawaited(
      container.read(orderTrackingProvider(orderId).notifier).refresh(),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a placed order shows its status, code and what to do', (
    tester,
  ) async {
    final backend = testBackend();
    await openTracking(tester, backend);

    expect(find.byType(OrderTrackingScreen), findsOneWidget);
    expect(find.text('Order #A1024'), findsOneWidget); // header
    // Twice: the status card title and the first step of the timeline.
    expect(find.text('Order placed'), findsNWidgets(2));
    // Twice: the status card subtitle and that step's subtitle.
    expect(find.text('Waiting for the store to confirm'), findsNWidgets(2));
    expect(find.text('A1024'), findsOneWidget); // the pickup code card
    expect(
      find.text('Show this code at the counter when your order is ready.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'You can cancel until the store confirms. Refunds go back to '
        'your card.',
      ),
      findsOneWidget,
    );
    expect(find.text('Cancel order'), findsOneWidget);
    // Nothing from the later states.
    expect(find.text('Reorder'), findsNothing);
    expect(find.text('Back to menu'), findsNothing);
  });

  testWidgets('TC-24: the page follows the store: Placed -> Preparing', (
    tester,
  ) async {
    final backend = testBackend();
    final container = await openTracking(tester, backend);
    expect(find.text('Cancel order'), findsOneWidget); // still cancellable

    backend.orders.staffAdvance(orderId); // Placed -> Confirmed
    backend.orders.staffAdvance(orderId); // Confirmed -> Preparing
    await refreshTracking(tester, container);

    expect(find.text('Being prepared'), findsOneWidget); // status card title
    expect(
      find.text('Estimated ready at 10:22 AM'),
      findsOneWidget,
    ); // status card subtitle: 10:12, plus the store's 10 min prep time
    // Third step, now the current one.
    expect(find.text('In progress'), findsOneWidget);
    // BR-09: once the store has it, the customer can no longer cancel.
    expect(find.text('Cancel order'), findsNothing);
  });

  testWidgets('TC-25: cancel a placed order -> cancelled, refund on its way', (
    tester,
  ) async {
    final backend = testBackend();
    await openTracking(tester, backend);

    await tester.tap(find.text('Cancel order'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this order?'), findsOneWidget); // sheet title
    expect(
      find.text(
        "The store hasn't started on it yet. You'll get a full refund of "
        r'$3.50 to your card.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Yes, cancel order'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel this order?'), findsNothing); // sheet closed
    expect(find.text('Order cancelled'), findsOneWidget); // status card title
    expect(find.text(r'Refund · $3.50'), findsOneWidget);
    expect(find.text('Processing'), findsOneWidget); // refund badge
    expect(
      find.text('Back to your card, usually within 1–3 business days.'),
      findsOneWidget,
    );
    // The refund card replaces the pickup code (SA §4.2.4.6).
    expect(find.text('A1024'), findsNothing);
    expect(find.text('Pickup code'), findsNothing);
    expect(find.text('Back to menu'), findsOneWidget);
    expect(find.text('Cancel order'), findsNothing);
  });

  testWidgets('"Keep my order" closes the sheet and leaves the order placed', (
    tester,
  ) async {
    final backend = testBackend();
    await openTracking(tester, backend);

    await tester.tap(find.text('Cancel order'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this order?'), findsOneWidget);

    await tester.tap(find.text('Keep my order'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel this order?'), findsNothing); // sheet closed
    // Still placed: status card title + first timeline step.
    expect(find.text('Order placed'), findsNWidgets(2));
    expect(find.text('Cancel order'), findsOneWidget); // offer still there
    expect(find.text('Back to menu'), findsNothing);
  });

  testWidgets('TC-26: the store confirms first -> the cancel is refused', (
    tester,
  ) async {
    final backend = testBackend();
    await openTracking(tester, backend);

    await tester.tap(find.text('Cancel order'));
    await tester.pumpAndSettle();
    // The store gets there while the sheet is open.
    backend.orders.staffAdvance(orderId); // Placed -> Confirmed
    await tester.tap(find.text('Yes, cancel order'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The store has already confirmed this order, so it can no longer '
        'be cancelled.',
      ),
      findsOneWidget, // the SnackBar
    );
    // The page caught up with the store.
    expect(find.text('Order confirmed'), findsOneWidget); // status card title
    expect(find.text('Order cancelled'), findsNothing);
    expect(find.text('Cancel order'), findsNothing);
  });

  testWidgets('a ready order tells the customer to go to the counter', (
    tester,
  ) async {
    final backend = testBackend();
    final container = await openTracking(tester, backend);

    backend.orders.staffAdvance(orderId); // Confirmed
    backend.orders.staffAdvance(orderId); // Preparing
    backend.orders.staffAdvance(orderId); // Ready
    await refreshTracking(tester, container);

    expect(find.text('Ready for pickup!'), findsOneWidget); // status card title
    expect(
      find.text('Show this code at the counter now. Your drinks are waiting.'),
      findsOneWidget, // next to the pickup code
    );
    expect(find.text('A1024'), findsOneWidget);
    // Waiting on the customer now: no button at the bottom.
    expect(find.text('Cancel order'), findsNothing);
    expect(find.text('Reorder'), findsNothing);
  });

  testWidgets('TC-28: "Reorder" on a finished order fills the cart again', (
    tester,
  ) async {
    final backend = testBackend();
    final container = await openTracking(tester, backend);

    for (var i = 0; i < 4; i++) {
      backend.orders.staffAdvance(orderId); // ... -> Completed
    }
    await refreshTracking(tester, container);
    expect(find.text('Enjoy your drinks'), findsOneWidget); // status card title

    await tester.tap(find.text('Reorder'));
    await tester.pumpAndSettle();

    expect(find.byType(CartScreen), findsOneWidget); // the new page
    final lines = container.read(cartControllerProvider);
    expect(lines.length, 1);
    expect(lines.first.product.name, 'Latte');
    expect(lines.first.quantity, 1);

    // Let the "Added to your cart" notice close by itself.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('"Back to home" on a finished order goes to Home', (
    tester,
  ) async {
    final backend = testBackend();
    final container = await openTracking(tester, backend);

    for (var i = 0; i < 4; i++) {
      backend.orders.staffAdvance(orderId); // ... -> Completed
    }
    await refreshTracking(tester, container);

    await tester.tap(find.text('Back to home'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget); // the new page
    expect(find.byType(OrderTrackingScreen), findsNothing);
  });

  testWidgets('TC-27: a rejected order says why and offers the menu', (
    tester,
  ) async {
    final backend = testBackend();
    final container = await openTracking(tester, backend);

    backend.orders.staffReject(orderId, 'Sold out');
    await refreshTracking(tester, container);

    expect(find.text('Order rejected'), findsOneWidget); // status card title
    expect(
      find.text("The store couldn't take it: Sold out"),
      findsOneWidget, // status card subtitle
    );
    expect(find.text(r'Refund · $3.50'), findsOneWidget);
    expect(find.text('A1024'), findsNothing); // refund replaces the code
    expect(find.text('Back to menu'), findsOneWidget);
  });

  testWidgets('the summary row opens to show the drinks', (tester) async {
    final backend = testBackend();
    await openTracking(tester, backend);

    expect(find.text(r'1 item · $3.50 · Paid with Card'), findsOneWidget);
    expect(find.text('1 × Latte'), findsNothing); // closed to start with

    // The row sits at the bottom of the scroll, below the fold.
    await tester.ensureVisible(find.text(r'1 item · $3.50 · Paid with Card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'1 item · $3.50 · Paid with Card'));
    await tester.pumpAndSettle();

    expect(find.text('1 × Latte'), findsOneWidget);
    // The sugar group adds its noun (OptionGroup.summaryNoun).
    expect(find.text('Medium · Hot · Regular sugar'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    // The line total and the order total, both $3.50.
    expect(find.text(r'$3.50'), findsNWidgets(2));
  });

  testWidgets('Close leaves the tracking page', (tester) async {
    final backend = testBackend();
    await openTracking(tester, backend);
    expect(find.byType(OrderTrackingScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget); // back where it came from
    expect(find.byType(OrderTrackingScreen), findsNothing);
  });
}
