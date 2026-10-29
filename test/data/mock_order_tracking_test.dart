import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/data/mock/mock_backend.dart';
import 'package:mos_app/data/mock/mock_menu_repository.dart';
import 'package:mos_app/data/mock/mock_order_repository.dart';
import 'package:mos_app/data/models/order.dart';
import 'package:mos_app/data/repositories/order_repository.dart';

import '../helpers.dart';

/// What happens to an order after it is paid (SA §4.2.4): staff steps,
/// cancelling, rejecting, refunds, and the customer's order list.
void main() {
  late DateTime now;
  late MockBackend backend;

  // Dara is customer 1 (demo account).
  const dara = 1;

  setUp(() {
    now = testNow(); // Thursday 29 Oct 2026, 10:12 AM
    backend = MockBackend(latency: Duration.zero, clock: () => now);
    backend.auth.signedInUserId = dara;
  });

  Duration s(int seconds) => Duration(seconds: seconds);

  /// A Latte ordered and paid by the saved card (4242) at 10:12.
  Future<Order> paidOrder() async {
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
    await backend.orders.payWithCard(orderId: order.id, cardId: cards.first.id);
    return backend.orders.fetchOrder(order.id);
  }

  test(
    'a paid order is Placed, belongs to the customer and has a code',
    () async {
      final o = await paidOrder();
      expect(o.status, OrderStatus.placed);
      expect(o.customerId, dara);
      expect(o.pickupCode, 'A1024');
      expect(o.placedAt, testNow());
      expect(o.canCancel, isTrue);
      expect(o.isInProgress, isTrue);
    },
  );

  test(
    'TC-25: cancel while Placed -> Cancelled, payment refund_pending',
    () async {
      final o = await paidOrder();
      now = now.add(const Duration(minutes: 2)); // 10:14
      final cancelled = await backend.orders.cancelOrder(o.id);
      expect(cancelled.status, OrderStatus.cancelled);
      expect(cancelled.endedAt, DateTime(2026, 10, 29, 10, 14));
      expect(cancelled.paidPayment!.status, PaymentStatus.refundPending);
      expect(cancelled.endedEarly, isTrue);
      expect(cancelled.isInProgress, isFalse);
    },
  );

  test('TC-26: once the store confirms, it cannot be cancelled', () async {
    final o = await paidOrder();
    backend.orders.staffAdvance(o.id); // confirmed
    expect(
      () => backend.orders.cancelOrder(o.id),
      throwsA(
        isA<OrderException>().having(
          (e) => e.message,
          'message',
          'The store has already confirmed this order, so it can no longer '
              'be cancelled.',
        ),
      ),
    );
    final still = await backend.orders.fetchOrder(o.id);
    expect(still.status, OrderStatus.confirmed);
    expect(still.paidPayment!.status, PaymentStatus.paid);
  });

  test(
    'TC-27: staff reject with a reason -> Rejected, refund pending',
    () async {
      final o = await paidOrder();
      final rejected = backend.orders.staffReject(o.id, 'Sold out');
      expect(rejected.status, OrderStatus.rejected);
      expect(rejected.rejectReason, 'Sold out');
      expect(rejected.paidPayment!.status, PaymentStatus.refundPending);
    },
  );

  test('BR-08: staff can only reject while Placed', () async {
    final o = await paidOrder();
    backend.orders.staffAdvance(o.id);
    expect(
      () => backend.orders.staffReject(o.id, 'Sold out'),
      throwsA(isA<OrderException>()),
    );
  });

  test('BR-08: staff move it forward one step at a time, with times', () async {
    final o = await paidOrder();
    now = now.add(s(60));
    expect(backend.orders.staffAdvance(o.id).confirmedAt, testNow().add(s(60)));
    now = now.add(s(60));
    expect(backend.orders.staffAdvance(o.id).status, OrderStatus.preparing);
    now = now.add(s(60));
    expect(backend.orders.staffAdvance(o.id).status, OrderStatus.ready);
    now = now.add(s(60));
    final done = backend.orders.staffAdvance(o.id);
    expect(done.status, OrderStatus.completed);
    expect(done.completedAt, testNow().add(s(240)));
    expect(done.isInProgress, isFalse);
    expect(
      () => backend.orders.staffAdvance(o.id),
      throwsA(isA<OrderException>()),
    );
  });

  group('automatic demo staff', () {
    setUp(() => backend.orders.staffTimings = const StaffTimings());

    test('moves the order along by the clock', () async {
      final o = await paidOrder(); // placed 10:12:00
      now = testNow().add(s(29));
      expect(
        (await backend.orders.fetchOrder(o.id)).status,
        OrderStatus.placed,
      );
      now = testNow().add(s(30));
      var got = await backend.orders.fetchOrder(o.id);
      expect(got.status, OrderStatus.confirmed);
      expect(got.confirmedAt, testNow().add(s(30)));
      // Confirmed +15 s, preparing +45 s: ready at 10:13:30.
      now = testNow().add(s(90));
      got = await backend.orders.fetchOrder(o.id);
      expect(got.status, OrderStatus.ready);
      expect(got.preparingAt, testNow().add(s(45)));
      expect(got.readyAt, testNow().add(s(90)));
      // Picked up a minute later.
      now = testNow().add(s(150));
      got = await backend.orders.fetchOrder(o.id);
      expect(got.status, OrderStatus.completed);
      expect(got.completedAt, testNow().add(s(150)));
    });

    test('catches up several steps at once (app was closed)', () async {
      final o = await paidOrder();
      now = testNow().add(const Duration(hours: 1));
      final got = await backend.orders.fetchOrder(o.id);
      expect(got.status, OrderStatus.completed);
      expect(got.readyAt, testNow().add(s(90)));
    });

    test('paused staff do nothing', () async {
      final o = await paidOrder();
      backend.orders.staffPaused = true;
      now = testNow().add(const Duration(hours: 1));
      expect(
        (await backend.orders.fetchOrder(o.id)).status,
        OrderStatus.placed,
      );
    });

    test('a cancelled order stays cancelled', () async {
      final o = await paidOrder();
      await backend.orders.cancelOrder(o.id);
      now = testNow().add(const Duration(hours: 1));
      expect(
        (await backend.orders.fetchOrder(o.id)).status,
        OrderStatus.cancelled,
      );
    });
  });

  group('FR-18: my orders', () {
    test('only the signed-in customer\'s, paid ones, newest first', () async {
      final first = await paidOrder(); // 10:12
      now = now.add(const Duration(minutes: 5));
      final second = await paidOrder(); // 10:17
      // An unpaid one is left out.
      await backend.orders.createOrder(
        const OrderRequest(
          lines: [OrderLineRequest(productId: 1, optionIds: [], quantity: 1)],
          pickupType: PickupType.asap,
        ),
      );
      final mine = await backend.orders.fetchMyOrders();
      expect(mine.map((o) => o.id), [second.id, first.id]);

      backend.auth.signedInUserId = 2;
      expect(await backend.orders.fetchMyOrders(), isEmpty);
      backend.auth.signedInUserId = null; // guest
      expect(await backend.orders.fetchMyOrders(), isEmpty);
    });
  });

  test("the demo account's past orders (Figma: Orders)", () async {
    final seeded = MockBackend(
      latency: Duration.zero,
      clock: () => now,
      seedHistory: true,
    );
    seeded.auth.signedInUserId = dara;
    final mine = await seeded.orders.fetchMyOrders();
    expect(mine.map((o) => o.pickupCode), ['A1019', 'A1007', 'A0998']);
    expect(mine.map((o) => o.totalAmount.format()), [
      r'$4.10',
      r'$8.60',
      r'$3.50',
    ]);
    expect(mine.map((o) => o.status), [
      OrderStatus.completed,
      OrderStatus.completed,
      OrderStatus.cancelled,
    ]);
    // Oct 10, 8:45 AM: 19 days before Thursday 29 Oct.
    expect(mine.first.placedAt, DateTime(2026, 10, 10, 8, 45));
    expect(mine.last.paidPayment!.status, PaymentStatus.refunded);
  });
}
