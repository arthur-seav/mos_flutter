import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/account/notification_settings_controller.dart';
import 'package:mos_app/controllers/cart/cart_controller.dart';
import 'package:mos_app/data/mock/mock_backend.dart';
import 'package:mos_app/data/mock/mock_menu_repository.dart';
import 'package:mos_app/data/models/order.dart';
import 'package:mos_app/screens/cart/cart_screen.dart';
import 'package:mos_app/screens/checkout/payment_result_screen.dart';
import 'package:mos_app/screens/orders/order_tracking_screen.dart';
import 'package:mos_app/screens/orders/orders_screen.dart';

import '../helpers.dart';

/// After paying, across pages, only with the taps a customer (or, in the
/// mock, the "Demo: staff" panel) would make: payment result -> tracking
/// -> notice when ready -> Orders tab -> picked up -> reorder.
void main() {
  Future<void> pumpFrames(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Opens the staff panel on the tracking page and taps [action]. The
  /// button is at the end of the page, so scroll to it first, as a person
  /// would.
  Future<void> staff(WidgetTester tester, String action) async {
    await tester.ensureVisible(find.text('Demo: staff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Demo: staff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  /// Lets the order notices check again (every 3 s) and the notice show.
  Future<void> nextCheck(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await pumpFrames(tester);
  }

  /// Lets a 6-second notice close by itself.
  Future<void> letNoticeClose(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
  }

  testWidgets('TC-21 -> TC-24 -> FR-16 -> FR-18 -> TC-28: pay, follow the '
      'order while staff work, find it in Orders, reorder it', (tester) async {
    var now = testNow();
    final backend = testBackend(clock: () => now);
    final container = await pumpMosApp(tester, backend: backend);
    await signInAsDara(tester);
    await orderCaramelLatte(tester);

    // KHQR: the mock bank confirms after a few seconds.
    await tester.tap(find.text(r'Pay $4.00'));
    await pumpFrames(tester);
    for (var i = 0; i < 6; i++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    await pumpFrames(tester);
    expect(find.byType(PaymentResultScreen), findsOneWidget);

    await tester.tap(find.text('Track my order'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderTrackingScreen), findsOneWidget);
    expect(find.text('Order #A1024'), findsOneWidget);
    // Status card title and the first step of the timeline.
    expect(find.text('Order placed'), findsNWidgets(2));
    expect(find.text('Cancel order'), findsOneWidget);

    // TC-24: the page follows the store, step by step.
    await staff(tester, 'Confirm order');
    expect(find.text('Order confirmed'), findsOneWidget);
    expect(find.text('Cancel order'), findsNothing); // BR-09
    await staff(tester, 'Start preparing');
    expect(find.text('Being prepared'), findsOneWidget);
    await staff(tester, 'Mark ready');
    expect(find.text('Ready for pickup!'), findsOneWidget);

    // FR-16: the notice comes even here; no "View", we are on it already.
    await nextCheck(tester);
    expect(find.text('Order #A1024 is ready'), findsOneWidget);
    expect(find.text('Show your pickup code at the counter.'), findsOneWidget);
    expect(find.text('View'), findsNothing);
    await letNoticeClose(tester);
    expect(find.text('Order #A1024 is ready'), findsNothing);

    // Opened from the payment result there is no page under it, so Close
    // goes to the Orders tab, where the order is still in progress.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('#A1024'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget); // the status badge
    expect(find.text('Past orders'), findsNothing);

    // Picked up, then reorder it from the tracking page (TC-28).
    await tester.tap(find.text('Track order'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderTrackingScreen), findsOneWidget);
    await staff(tester, 'Picked up (complete)');
    expect(find.text('Picked up at 10:12 AM'), findsOneWidget);
    expect(find.text('Demo: staff'), findsNothing); // the order is over

    await tester.tap(find.text('Reorder'));
    await tester.pumpAndSettle();
    expect(find.byType(CartScreen), findsOneWidget);
    final lines = container.read(cartControllerProvider);
    expect(lines, hasLength(1));
    expect(lines.single.product.name, 'Caramel Latte');
    expect(lines.single.quantity, 1);
    await letNoticeClose(tester);
  });

  group('FR-16 notices and the Notifications switch', () {
    /// Dara pays for a Latte outside the app's pages (straight to the
    /// mock), so the test can watch the notice on any tab.
    Future<int> paidOrder(WidgetTester tester, MockBackend backend) async {
      late int id;
      await tester.runAsync(() async {
        final o = await backend.orders.createOrder(
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
        await backend.orders.payWithCard(orderId: o.id, cardId: cards.first.id);
        id = o.id;
      });
      return id;
    }

    void makeReady(MockBackend backend, int id) {
      for (var i = 0; i < 3; i++) {
        backend.orders.staffAdvance(id); // confirmed, preparing, ready
      }
    }

    testWidgets('on another tab the notice has "View", which opens the '
        'order', (tester) async {
      final backend = testBackend();
      await pumpMosApp(tester, backend: backend);
      await signInAsDara(tester);
      final id = await paidOrder(tester, backend);
      await nextCheck(tester); // notes it as Placed: nothing to say yet
      expect(find.textContaining('is ready'), findsNothing);

      makeReady(backend, id);
      await nextCheck(tester);
      expect(find.text('Order #A1024 is ready'), findsOneWidget);
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderTrackingScreen), findsOneWidget);
      expect(find.text('Ready for pickup!'), findsOneWidget);
      await letNoticeClose(tester);
    });

    testWidgets('switched off on the Profile tab: no notice', (tester) async {
      final backend = testBackend();
      final container = await pumpMosApp(tester, backend: backend);
      await signInAsDara(tester);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(container.read(notificationsEnabledProvider).value, isFalse);

      final id = await paidOrder(tester, backend);
      await nextCheck(tester);
      makeReady(backend, id);
      await nextCheck(tester);
      expect(find.text('Order #A1024 is ready'), findsNothing);
      // ...but the order did become ready.
      late Order order;
      await tester.runAsync(() async {
        order = await backend.orders.fetchOrder(id);
      });
      expect(order.status, OrderStatus.ready);
    });
  });
}
