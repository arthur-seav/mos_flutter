import '../models/money.dart';
import '../models/order.dart';
import '../models/pickup_schedule.dart';
import '../repositories/order_repository.dart';
import 'mock_card_repository.dart';
import 'mock_menu_repository.dart';
import 'mock_store_repository.dart';

/// Orders and payments without a backend, kept until the app closes.
///
/// It behaves like the backend should (SA §3.5):
/// - prices come from the menu, never from the app (TC-23);
/// - BR-05, BR-07 and FR-41 are checked again when the order is created;
/// - the pickup code is given when payment succeeds (FR-14).
///
/// Payments work like a gateway's test mode: a KHQR charge is paid
/// [khqrPaysAfter] after it starts (null = never, to show it expiring),
/// and a card ending in 0002 is declined (TC-22).
///
/// There are no staff, so [staffTimings] moves paid orders along by
/// itself (Placed -> Confirmed -> Preparing -> Ready -> Completed),
/// worked out from the clock whenever an order is read, so no timers
/// run. The staff* methods do the same by hand (the "Demo: staff" panel
/// and the tests), including rejecting an order (TC-27).
class MockOrderRepository implements OrderRepository {
  MockOrderRepository({
    required this.menu,
    required this.store,
    required this.cards,
    this.latency = const Duration(milliseconds: 600),
    this.khqrPaysAfter = const Duration(seconds: 5),
    this.khqrExpiresAfter = const Duration(minutes: 5),
    this.staffTimings,
    int? Function()? currentCustomerId,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now,
       _customerId = currentCustomerId ?? _nobody;

  static int? _nobody() => null;

  final MockMenuRepository menu;
  final MockStoreRepository store;
  final MockCardRepository cards;
  final Duration latency;
  final Duration? khqrPaysAfter;
  final Duration khqrExpiresAfter;
  final DateTime Function() _now;

  /// Who is signed in: their orders are theirs (`orders.customer_id`).
  final int? Function() _customerId;

  /// null = staff never act by themselves (tests).
  StaffTimings? staffTimings;

  /// The demo panel can stop the automatic staff for a while.
  bool staffPaused = false;

  final Map<int, Order> _orders = {};
  final Map<int, Payment> _payments = {};
  final Map<int, DateTime> _khqrExpiry = {};
  int _nextOrderId = 1;
  int _nextPaymentId = 1;
  int _nextPickupNumber = 1024;

  /// Every payment ever made for an order, for tests (TC-22).
  List<Payment> paymentsFor(int orderId) => [
    for (final p in _payments.values)
      if (p.orderId == orderId) p,
  ];

  @override
  Future<Order> createOrder(OrderRequest request) async {
    await Future<void>.delayed(latency);
    if (request.lines.isEmpty) {
      throw const OrderException('Your cart is empty.');
    }
    final info = await store.fetchStoreInfo();
    if (!info.settings.onlineOrderingOpen) {
      throw const OrderException(
        'Online ordering is paused right now.',
        reason: OrderFailure.orderingPaused,
      );
    }
    final schedule = PickupSchedule(store: info, now: _now());
    switch (request.pickupType) {
      case PickupType.asap when !schedule.canPickUpAsap:
        throw const OrderException(
          'The store is closed now. Choose a later pickup time.',
          reason: OrderFailure.slotUnavailable,
        );
      case PickupType.scheduled
          when request.pickupTime == null ||
              !schedule.allows(request.pickupTime!):
        throw const OrderException(
          'That pickup time is no longer available. Choose another.',
          reason: OrderFailure.slotUnavailable,
        );
      default:
    }

    final items = <OrderItem>[];
    for (final line in request.lines) {
      items.add(await _priceLine(line));
    }
    final order = Order(
      id: _nextOrderId++,
      status: OrderStatus.pendingPayment,
      pickupType: request.pickupType,
      pickupTime: request.pickupTime,
      note: request.note,
      items: items,
      totalAmount: items.fold(Money.zero, (sum, i) => sum + i.lineTotal),
      createdAt: _now(),
      customerId: _customerId(),
    );
    _orders[order.id] = order;
    return order;
  }

  /// TC-23: the price is worked out here from the menu.
  Future<OrderItem> _priceLine(OrderLineRequest line) async {
    final customization = await menu
        .fetchCustomization(line.productId)
        .catchError(
          (Object _) => throw const OrderException(
            'A drink in your cart is no longer on the menu.',
            reason: OrderFailure.drinkUnavailable,
          ),
        );
    final product = customization.product;
    if (product.isSoldOut) {
      throw OrderException(
        '${product.name} is sold out.',
        reason: OrderFailure.drinkUnavailable,
      );
    }
    var unit = product.basePrice;
    final names = <String>[];
    for (final g in customization.groups) {
      for (final id in line.optionIds) {
        final option = g.optionById(id);
        if (option == null) continue;
        unit = unit + option.extraPrice;
        names.add(g.group.summaryNameOf(option));
      }
    }
    return OrderItem(
      productId: product.id,
      productName: product.name,
      optionIds: [
        for (final g in customization.groups)
          for (final id in line.optionIds)
            if (g.optionById(id) != null) id,
      ],
      optionNames: names,
      unitPrice: unit,
      quantity: line.quantity,
    );
  }

  @override
  Future<Order> fetchOrder(int orderId) async {
    await Future<void>.delayed(latency);
    return _order(orderId);
  }

  @override
  Future<List<Order>> fetchMyOrders() async {
    await Future<void>.delayed(latency);
    final me = _customerId();
    if (me == null) return const [];
    final mine = [
      for (final id in _orders.keys)
        if (_orders[id]!.customerId == me && !_orders[id]!.isAwaitingPayment)
          _order(id),
    ];
    mine.sort(
      (a, b) =>
          (b.placedAt ?? b.createdAt).compareTo(a.placedAt ?? a.createdAt),
    );
    return mine;
  }

  @override
  Future<Order> cancelOrder(int orderId) async {
    await Future<void>.delayed(latency);
    final order = _order(orderId);
    if (!order.canCancel) {
      throw const OrderException(
        'The store has already confirmed this order, so it can no longer '
        'be cancelled.',
      );
    }
    return _endEarly(order, OrderStatus.cancelled);
  }

  /// BR-10: a paid order that is cancelled or rejected is refunded.
  Order _endEarly(Order order, OrderStatus status, {String? reason}) {
    for (final p in paymentsFor(order.id)) {
      if (p.isPaid) {
        _payments[p.id] = p.copyWith(status: PaymentStatus.refundPending);
      }
    }
    _orders[order.id] = _orders[order.id]!.copyWith(
      status: status,
      rejectReason: reason,
      endedAt: _now(),
    );
    return _order(order.id);
  }

  /// Past orders for the demo account, as in Figma's Orders page: two
  /// picked up, one cancelled and refunded. Their pickup codes are below
  /// the new ones (A1024 on).
  void seedHistory({required int customerId}) {
    final today = _now();
    DateTime day(int daysAgo, int h, int m) {
      final d = today.subtract(Duration(days: daysAgo));
      return DateTime(d.year, d.month, d.day, h, m);
    }

    OrderItem item(
      int id,
      String name,
      int cents,
      List<int> options,
      List<String> names,
    ) => OrderItem(
      productId: id,
      productName: name,
      optionIds: options,
      optionNames: names,
      unitPrice: Money.cents(cents),
      quantity: 1,
    );

    const m = MockMenuRepository.medium, hot = MockMenuRepository.hot;
    const iced = MockMenuRepository.iced, ice = MockMenuRepository.regularIce;
    const sugar = MockMenuRepository.normalSugar;
    const dbl = MockMenuRepository.doubleShot;
    const hotSugar = ['Hot', 'Regular sugar'];

    void add(
      String code,
      DateTime at,
      List<OrderItem> items, {
      bool cancelled = false,
    }) {
      final total = items.fold(Money.zero, (sum, i) => sum + i.lineTotal);
      final id = _nextOrderId++;
      final payment = Payment(
        id: _nextPaymentId++,
        orderId: id,
        method: PaymentMethod.khqr,
        amount: total,
        status: cancelled ? PaymentStatus.refunded : PaymentStatus.paid,
        createdAt: at,
        transactionRef: 'DEMO-$code',
        paidAt: at,
      );
      _payments[payment.id] = payment;
      _orders[id] = Order(
        id: id,
        status: cancelled ? OrderStatus.cancelled : OrderStatus.completed,
        pickupType: PickupType.asap,
        customerId: customerId,
        pickupCode: code,
        items: items,
        totalAmount: total,
        createdAt: at,
        placedAt: at,
        confirmedAt: cancelled ? null : at.add(const Duration(minutes: 1)),
        preparingAt: cancelled ? null : at.add(const Duration(minutes: 3)),
        readyAt: cancelled ? null : at.add(const Duration(minutes: 12)),
        completedAt: cancelled ? null : at.add(const Duration(minutes: 15)),
        endedAt: cancelled ? at.add(const Duration(minutes: 2)) : null,
      );
    }

    add('A0998', day(29, 9, 5), [
      item(4, 'Caramel Latte', 350, [m, hot, sugar], ['Medium', ...hotSugar]),
    ], cancelled: true);
    add('A1007', day(23, 14, 30), [
      item(3, 'Cappuccino', 320, [m, hot, sugar], ['Medium', ...hotSugar]),
      item(6, 'Flat White', 340, [m, hot, sugar], ['Medium', ...hotSugar]),
      item(1, 'Espresso', 200, [dbl, hot], ['Double shot', 'Hot']),
    ]);
    add('A1019', day(19, 8, 45), [
      item(
        5,
        'Mocha',
        410,
        [m, iced, ice, sugar],
        ['Medium', 'Iced', 'Regular ice', 'Regular sugar'],
      ),
    ]);
  }

  // Staff (no backend): the "Demo: staff" panel and the tests.

  /// BR-08: staff move an order forward one step.
  Order staffAdvance(int orderId) {
    final o = _order(orderId);
    final now = _now();
    final next = switch (o.status) {
      OrderStatus.placed => o.copyWith(
        status: OrderStatus.confirmed,
        confirmedAt: now,
      ),
      OrderStatus.confirmed => o.copyWith(
        status: OrderStatus.preparing,
        preparingAt: now,
      ),
      OrderStatus.preparing => o.copyWith(
        status: OrderStatus.ready,
        readyAt: now,
      ),
      OrderStatus.ready => o.copyWith(
        status: OrderStatus.completed,
        completedAt: now,
      ),
      _ => throw OrderException('Order ${o.id} cannot move on.'),
    };
    _orders[o.id] = next.copyWith(payments: const []);
    return _order(o.id);
  }

  /// BR-08 / BR-10: staff reject an order only while it is Placed, with
  /// a reason; a paid order is refunded (TC-27).
  Order staffReject(int orderId, String reason) {
    final o = _order(orderId);
    if (o.status != OrderStatus.placed) {
      throw OrderException('Order ${o.id} can no longer be rejected.');
    }
    return _endEarly(o, OrderStatus.rejected, reason: reason);
  }

  Order _order(int orderId) {
    final order = _orders[orderId];
    if (order == null) throw OrderException('No order $orderId.');
    final moved = _staffCatchUp(order);
    if (!identical(moved, order)) _orders[orderId] = moved;
    return moved.copyWith(payments: paymentsFor(orderId));
  }

  /// What the automatic staff would have done by now.
  Order _staffCatchUp(Order o) {
    final t = staffTimings;
    if (t == null || staffPaused) return o;
    final now = _now();
    var order = o;
    while (true) {
      final DateTime? since;
      final Duration wait;
      switch (order.status) {
        case OrderStatus.placed:
          (since, wait) = (order.placedAt, t.confirm);
        case OrderStatus.confirmed:
          (since, wait) = (order.confirmedAt, t.startPreparing);
        case OrderStatus.preparing:
          (since, wait) = (order.preparingAt, t.ready);
        case OrderStatus.ready:
          (since, wait) = (order.readyAt, t.complete);
        default:
          return order;
      }
      if (since == null) return order;
      final at = since.add(wait);
      if (now.isBefore(at)) return order;
      order = switch (order.status) {
        OrderStatus.placed => order.copyWith(
          status: OrderStatus.confirmed,
          confirmedAt: at,
        ),
        OrderStatus.confirmed => order.copyWith(
          status: OrderStatus.preparing,
          preparingAt: at,
        ),
        OrderStatus.preparing => order.copyWith(
          status: OrderStatus.ready,
          readyAt: at,
        ),
        _ => order.copyWith(status: OrderStatus.completed, completedAt: at),
      };
    }
  }

  Order _awaitingPayment(int orderId) {
    final order = _order(orderId);
    if (!order.isAwaitingPayment) {
      throw const OrderException('This order is already paid.');
    }
    return order;
  }

  @override
  Future<KhqrCharge> startKhqr(int orderId) async {
    await Future<void>.delayed(latency);
    final order = _awaitingPayment(orderId);
    final now = _now();
    final payment = _addPayment(order, PaymentMethod.khqr, now);
    final expiresAt = now.add(khqrExpiresAfter);
    _khqrExpiry[payment.id] = expiresAt;
    final info = await store.fetchStoreInfo();
    return KhqrCharge(
      paymentId: payment.id,
      orderId: order.id,
      // Not a real KHQR string: the backend will get one from the bank.
      qrData:
          'MOS-DEMO-KHQR|order=${order.id}|payment=${payment.id}|'
          'amount=${order.totalAmount.cents}',
      amount: order.totalAmount,
      merchantName: info.settings.storeName,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<Payment> checkPayment(int paymentId) async {
    await Future<void>.delayed(latency);
    final payment = _payment(paymentId);
    if (payment.status != PaymentStatus.pending) return payment;
    final now = _now();
    final paysAfter = khqrPaysAfter;
    if (paysAfter != null && !now.isBefore(payment.createdAt.add(paysAfter))) {
      return _markPaid(payment, now);
    }
    if (!now.isBefore(_khqrExpiry[paymentId]!)) {
      return _markFailed(
        payment,
        'The QR code expired before payment was received.',
      );
    }
    return payment;
  }

  @override
  Future<Payment> cancelPayment(int paymentId) async {
    await Future<void>.delayed(latency);
    final payment = _payment(paymentId);
    if (payment.status != PaymentStatus.pending) return payment;
    return _markFailed(payment, 'You cancelled the payment.');
  }

  @override
  Future<Payment> payWithCard({
    required int orderId,
    required int cardId,
  }) async {
    await Future<void>.delayed(latency);
    final order = _awaitingPayment(orderId);
    final card = cards.card(cardId);
    if (card == null) throw const OrderException('That card is not saved.');
    final now = _now();
    final payment = _addPayment(order, PaymentMethod.card, now);
    if (cards.isDeclined(cardId)) {
      return _markFailed(payment, 'Your card was declined.');
    }
    if (!now.isBefore(DateTime(card.expiryYear, card.expiryMonth + 1))) {
      return _markFailed(payment, 'This card has expired.');
    }
    return _markPaid(payment, now);
  }

  Payment _payment(int paymentId) {
    final payment = _payments[paymentId];
    if (payment == null) throw OrderException('No payment $paymentId.');
    return payment;
  }

  Payment _addPayment(Order order, PaymentMethod method, DateTime now) {
    final payment = Payment(
      id: _nextPaymentId++,
      orderId: order.id,
      method: method,
      amount: order.totalAmount,
      status: PaymentStatus.pending,
      createdAt: now,
    );
    _payments[payment.id] = payment;
    return payment;
  }

  Payment _markPaid(Payment p, DateTime now) {
    final paid = Payment(
      id: p.id,
      orderId: p.orderId,
      method: p.method,
      amount: p.amount,
      status: PaymentStatus.paid,
      createdAt: p.createdAt,
      transactionRef: 'DEMO-${p.id.toString().padLeft(6, '0')}',
      paidAt: now,
    );
    _payments[p.id] = paid;
    final o = _orders[p.orderId]!;
    // FR-14: the pickup code comes with the first successful payment.
    _orders[o.id] = o.copyWith(
      status: OrderStatus.placed,
      pickupCode: 'A${_nextPickupNumber++}',
      placedAt: now,
    );
    return paid;
  }

  Payment _markFailed(Payment p, String reason) {
    final failed = Payment(
      id: p.id,
      orderId: p.orderId,
      method: p.method,
      amount: p.amount,
      status: PaymentStatus.failed,
      createdAt: p.createdAt,
      failureReason: reason,
    );
    _payments[p.id] = failed;
    return failed;
  }
}

/// How long the automatic demo staff take for each step.
class StaffTimings {
  const StaffTimings({
    this.confirm = const Duration(seconds: 30),
    this.startPreparing = const Duration(seconds: 15),
    this.ready = const Duration(seconds: 45),
    this.complete = const Duration(minutes: 1),
  });

  /// Placed -> Confirmed. Long enough to try "Cancel order" (TC-25).
  final Duration confirm;
  final Duration startPreparing;
  final Duration ready;

  /// Ready -> Completed: the customer picks it up (BR-12 allows 30 min).
  final Duration complete;
}
