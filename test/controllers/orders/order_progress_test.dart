import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/orders/order_progress.dart';
import 'package:mos_app/data/models/money.dart';
import 'package:mos_app/data/models/order.dart';

// Order A1024: 2 drinks, $8.10, paid by KHQR, placed 10:12 AM, ASAP.
// The store says ASAP drinks take 10 minutes.
DateTime at(int h, int m) => DateTime(2026, 10, 29, h, m);

final paid = Payment(
  id: 1,
  orderId: 7,
  method: PaymentMethod.khqr,
  amount: const Money.cents(810),
  status: PaymentStatus.paid,
  createdAt: at(10, 12),
);

final placed = Order(
  id: 7,
  status: OrderStatus.placed,
  pickupType: PickupType.asap,
  pickupCode: 'A1024',
  createdAt: at(10, 11),
  placedAt: at(10, 12),
  totalAmount: const Money.cents(810),
  items: const [
    OrderItem(
      productId: 4,
      productName: 'Caramel Latte',
      optionNames: [],
      unitPrice: Money.cents(460),
      quantity: 1,
    ),
    OrderItem(
      productId: 2,
      productName: 'Americano',
      optionNames: [],
      unitPrice: Money.cents(350),
      quantity: 1,
    ),
  ],
  payments: [paid],
);

OrderProgress of(Order o) => OrderProgress.of(o, asapPrepMin: 10);
List<(String, String, StepState)> steps(OrderProgress p) => [
  for (final s in p.steps) (s.title, s.subtitle, s.state),
];

void main() {
  test('Placed (Figma: Order · Placed)', () {
    final p = of(placed);
    expect(p.title, 'Order placed');
    expect(p.subtitle, 'Waiting for the store to confirm');
    expect(p.tone, StatusTone.inProgress);
    expect(p.filledSegments, 1);
    expect(steps(p), [
      ('Order placed', 'Waiting for the store to confirm', StepState.current),
      ('Confirmed by store', 'Usually within a minute', StepState.upcoming),
      ('Preparing', 'Up next', StepState.upcoming),
      ('Ready for pickup', 'Est. 10:22 AM', StepState.upcoming),
      ('Picked up', 'Show code at the counter', StepState.upcoming),
    ]);
    expect(p.summary, r'2 items · $8.10 · Paid with KHQR');
    expect(
      p.pickupHint,
      'Show this code at the counter when your order is ready.',
    );
  });

  test('Preparing: estimate counts from when they started', () {
    final p = of(
      placed.copyWith(
        status: OrderStatus.preparing,
        confirmedAt: at(10, 13),
        preparingAt: at(10, 15),
      ),
    );
    expect(p.title, 'Being prepared');
    expect(p.subtitle, 'Estimated ready at 10:25 AM');
    expect(p.filledSegments, 3);
    expect(steps(p), [
      ('Order placed', '10:12 AM', StepState.done),
      ('Confirmed by store', '10:13 AM', StepState.done),
      ('Preparing', 'In progress', StepState.current),
      ('Ready for pickup', 'Est. 10:25 AM', StepState.upcoming),
      ('Picked up', 'Show code at the counter', StepState.upcoming),
    ]);
  });

  test('a scheduled order is ready at its pickup time', () {
    final scheduled = Order(
      id: 8,
      status: OrderStatus.confirmed,
      pickupType: PickupType.scheduled,
      pickupTime: at(11, 40),
      createdAt: at(10, 11),
      placedAt: at(10, 12),
      confirmedAt: at(10, 13),
      totalAmount: const Money.cents(350),
      items: const [],
    );
    expect(of(scheduled).steps[3].subtitle, 'Est. 11:40 AM');
  });

  test('Ready (green card, code hint changes)', () {
    final p = of(
      placed.copyWith(
        status: OrderStatus.ready,
        confirmedAt: at(10, 13),
        preparingAt: at(10, 15),
        readyAt: at(10, 25),
      ),
    );
    expect(p.title, 'Ready for pickup!');
    expect(p.subtitle, 'Show your pickup code at the counter');
    expect(p.tone, StatusTone.ready);
    expect(p.filledSegments, 4);
    expect(p.steps[3].subtitle, 'Waiting at the counter');
    expect(p.steps[3].state, StepState.current);
    expect(
      p.pickupHint,
      'Show this code at the counter now. Your drinks are waiting.',
    );
  });

  test('Completed: every step done, with times', () {
    final p = of(
      placed.copyWith(
        status: OrderStatus.completed,
        confirmedAt: at(10, 13),
        preparingAt: at(10, 15),
        readyAt: at(10, 25),
        completedAt: at(10, 27),
      ),
    );
    expect(p.title, 'Enjoy your drinks');
    expect(p.subtitle, 'Picked up at 10:27 AM');
    expect(p.tone, StatusTone.done);
    expect(p.filledSegments, 5);
    expect(p.steps.map((s) => s.subtitle), [
      '10:12 AM',
      '10:13 AM',
      '10:15 AM',
      '10:25 AM',
      '10:27 AM',
    ]);
    expect(p.steps.every((s) => s.state == StepState.done), isTrue);
  });

  test('Cancelled (TC-25): red card, stopped at step 2, refund', () {
    final o = placed.copyWith(
      status: OrderStatus.cancelled,
      endedAt: at(10, 14),
      payments: [paid.copyWith(status: PaymentStatus.refundPending)],
    );
    final p = of(o);
    expect(p.title, 'Order cancelled');
    expect(p.subtitle, 'Cancelled by you at 10:14 AM');
    expect(p.tone, StatusTone.ended);
    expect(steps(p), [
      ('Order placed', '10:12 AM', StepState.done),
      ('Cancelled', '10:14 AM · Full refund issued', StepState.failed),
      ('Preparing', '—', StepState.skipped),
      ('Ready for pickup', '—', StepState.skipped),
      ('Picked up', '—', StepState.skipped),
    ]);
    expect(p.summary, r'2 items · $8.10 · Refund processing');
    final refund = RefundInfo.of(o)!;
    expect(refund.amount, r'$8.10');
    expect(
      refund.where,
      'Back to your KHQR account, usually within 1–3 business days.',
    );
    expect(refund.isDone, isFalse);
  });

  test('Rejected (TC-27): the reason is shown', () {
    final o = placed.copyWith(
      status: OrderStatus.rejected,
      rejectReason: 'Sold out',
      endedAt: at(10, 14),
      payments: [paid.copyWith(status: PaymentStatus.refundPending)],
    );
    final p = of(o);
    expect(p.title, 'Order rejected');
    expect(p.subtitle, "The store couldn't take it: Sold out");
    expect(p.steps[1].title, 'Rejected by store');
    expect(p.steps[1].subtitle, '10:14 AM · Sold out');
    expect(RefundInfo.of(o), isNotNull);
  });

  test('no refund block while the order is going', () {
    expect(RefundInfo.of(placed), isNull);
  });

  test('one drink: "1 item"; card refunds go back to the card', () {
    final card = Payment(
      id: 2,
      orderId: 9,
      method: PaymentMethod.card,
      amount: const Money.cents(350),
      status: PaymentStatus.refunded,
      createdAt: at(10, 12),
    );
    final o = Order(
      id: 9,
      status: OrderStatus.cancelled,
      pickupType: PickupType.asap,
      createdAt: at(10, 11),
      placedAt: at(10, 12),
      endedAt: at(10, 13),
      totalAmount: const Money.cents(350),
      items: const [
        OrderItem(
          productId: 18,
          productName: 'Latte',
          optionNames: [],
          unitPrice: Money.cents(350),
          quantity: 1,
        ),
      ],
      payments: [card],
    );
    expect(of(o).summary, r'1 item · $3.50 · Refunded');
    final refund = RefundInfo.of(o)!;
    expect(
      refund.where,
      'Back to your card, usually within 1–3 business days.',
    );
    expect(refund.isDone, isTrue);
  });
}
