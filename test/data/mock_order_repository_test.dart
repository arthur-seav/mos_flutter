import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/data/mock/mock_backend.dart';
import 'package:mos_app/data/mock/mock_menu_repository.dart';
import 'package:mos_app/data/models/money.dart';
import 'package:mos_app/data/models/order.dart';
import 'package:mos_app/data/models/saved_card.dart';
import 'package:mos_app/data/repositories/card_repository.dart';
import 'package:mos_app/data/repositories/order_repository.dart';

import '../helpers.dart';

void main() {
  late DateTime now;
  late MockBackend backend;

  setUp(() {
    now = testNow(); // 10:12 AM
    backend = MockBackend(latency: Duration.zero, clock: () => now);
  });

  // Latte (18): $3.00 + Large $1.00 + Oat milk $0.60 = $4.60 (TC-14).
  const latteLarge = OrderLineRequest(
    productId: 18,
    optionIds: [
      MockMenuRepository.large,
      MockMenuRepository.hot,
      MockMenuRepository.normalSugar,
      MockMenuRepository.oatMilk,
    ],
    quantity: 2,
  );

  Future<Order> place({
    List<OrderLineRequest> lines = const [latteLarge],
    PickupType type = PickupType.asap,
    DateTime? time,
  }) => backend.orders.createOrder(
    OrderRequest(lines: lines, pickupType: type, pickupTime: time),
  );

  test('TC-23: the total comes from the menu, not from the app', () async {
    final order = await place();
    expect(order.status, OrderStatus.pendingPayment);
    expect(order.items.single.unitPrice, Money.dollars(4.6));
    expect(order.totalAmount, Money.dollars(9.2));
    expect(order.items.single.optionNames, [
      'Large',
      'Hot',
      'Regular sugar',
      'Oat milk',
    ]);
    expect(order.pickupCode, isNull);
  });

  test('TC-21: KHQR is paid after 5 s; then a pickup code', () async {
    final order = await place();
    final charge = await backend.orders.startKhqr(order.id);
    expect(charge.amount, Money.dollars(9.2));
    expect(charge.expiresAt, now.add(const Duration(minutes: 5)));

    now = now.add(const Duration(seconds: 4));
    expect(
      (await backend.orders.checkPayment(charge.paymentId)).status,
      PaymentStatus.pending,
    );
    now = now.add(const Duration(seconds: 1));
    final paid = await backend.orders.checkPayment(charge.paymentId);
    expect(paid.status, PaymentStatus.paid);
    expect(paid.paidAt, now);

    final placed = await backend.orders.fetchOrder(order.id);
    expect(placed.status, OrderStatus.placed);
    expect(placed.pickupCode, 'A1024');
    expect(placed.placedAt, now);
  });

  test('an unpaid QR code expires after 5 minutes', () async {
    backend = MockBackend(
      latency: Duration.zero,
      clock: () => now,
      khqrPaysAfter: null,
    );
    final order = await place();
    final charge = await backend.orders.startKhqr(order.id);
    now = now.add(const Duration(minutes: 5));
    final failed = await backend.orders.checkPayment(charge.paymentId);
    expect(failed.status, PaymentStatus.failed);
    expect(failed.failureReason, contains('expired'));
    expect(
      (await backend.orders.fetchOrder(order.id)).status,
      OrderStatus.pendingPayment,
    );
  });

  test(
    'TC-22: declined card, then KHQR: two payments, failed then paid',
    () async {
      final declined = await backend.cards.addCard(
        const NewCard(
          number: '4000000000000002',
          holderName: 'Dara Sok',
          expiryMonth: 12,
          expiryYear: 2030,
          cvv: '123',
        ),
      );
      final order = await place();
      final first = await backend.orders.payWithCard(
        orderId: order.id,
        cardId: declined.id,
      );
      expect(first.status, PaymentStatus.failed);
      expect(first.failureReason, 'Your card was declined.');
      // Staff don't see it: still waiting for payment, no pickup code.
      final unpaid = await backend.orders.fetchOrder(order.id);
      expect(unpaid.status, OrderStatus.pendingPayment);
      expect(unpaid.pickupCode, isNull);

      final charge = await backend.orders.startKhqr(order.id);
      now = now.add(const Duration(seconds: 5));
      await backend.orders.checkPayment(charge.paymentId);
      final paid = await backend.orders.fetchOrder(order.id);
      expect(paid.status, OrderStatus.placed);
      expect(paid.payments.map((p) => (p.method, p.status)), [
        (PaymentMethod.card, PaymentStatus.failed),
        (PaymentMethod.khqr, PaymentStatus.paid),
      ]);
    },
  );

  test('the demo card (4242) pays at once', () async {
    final order = await place();
    final payment = await backend.orders.payWithCard(
      orderId: order.id,
      cardId: 1,
    );
    expect(payment.status, PaymentStatus.paid);
    expect(payment.method, PaymentMethod.card);
  });

  test('a paid order cannot be paid again', () async {
    final order = await place();
    await backend.orders.payWithCard(orderId: order.id, cardId: 1);
    expect(
      () => backend.orders.payWithCard(orderId: order.id, cardId: 1),
      throwsA(isA<OrderException>()),
    );
  });

  test('cancelling a KHQR payment leaves the order unpaid', () async {
    final order = await place();
    final charge = await backend.orders.startKhqr(order.id);
    final cancelled = await backend.orders.cancelPayment(charge.paymentId);
    expect(cancelled.status, PaymentStatus.failed);
    now = now.add(const Duration(seconds: 10));
    // A cancelled charge is not paid later.
    expect(
      (await backend.orders.checkPayment(charge.paymentId)).status,
      PaymentStatus.failed,
    );
  });

  test('FR-41 / TC-20: no new orders while ordering is paused', () async {
    backend.store.pauseOnlineOrdering();
    await expectLater(
      place(),
      throwsA(
        isA<OrderException>().having(
          (e) => e.reason,
          'reason',
          OrderFailure.orderingPaused,
        ),
      ),
    );
  });

  test('BR-07 is checked again by the backend', () async {
    await expectLater(
      place(type: PickupType.scheduled, time: DateTime(2026, 10, 29, 10, 30)),
      throwsA(isA<OrderException>()),
    );
    await expectLater(
      place(type: PickupType.scheduled, time: DateTime(2026, 10, 29, 20, 15)),
      throwsA(isA<OrderException>()),
    );
    final ok = await place(
      type: PickupType.scheduled,
      time: DateTime(2026, 10, 29, 10, 45),
    );
    expect(ok.pickupTime, DateTime(2026, 10, 29, 10, 45));
  });

  test('BR-05: a sold-out drink cannot be ordered', () async {
    backend.menu.markSoldOut(18);
    await expectLater(place(), throwsA(isA<OrderException>()));
  });

  group('saved cards', () {
    test('only the last four digits are kept and shown', () async {
      final card = await backend.cards.addCard(
        const NewCard(
          number: '5555555555554444',
          holderName: ' dara sok ',
          expiryMonth: 1,
          expiryYear: 2029,
          cvv: '123',
        ),
      );
      expect(card.brand, 'Mastercard');
      expect(card.last4, '4444');
      expect(card.maskedNumber, '•••• •••• •••• 4444');
      expect(card.expiry, '01/29');
      expect(card.holderName, 'DARA SOK');
    });

    test('a number that fails the checksum is refused', () async {
      await expectLater(
        backend.cards.addCard(
          const NewCard(
            number: '4242424242424241',
            holderName: 'A',
            expiryMonth: 1,
            expiryYear: 2029,
            cvv: '123',
          ),
        ),
        throwsA(isA<CardException>()),
      );
    });

    test('an expired card is refused', () async {
      await expectLater(
        backend.cards.addCard(
          const NewCard(
            number: '4242424242424242',
            holderName: 'A',
            expiryMonth: 9,
            expiryYear: 2026,
            cvv: '123',
          ),
        ),
        throwsA(isA<CardException>()),
      );
    });
  });
}
