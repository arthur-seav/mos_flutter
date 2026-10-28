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
class MockOrderRepository implements OrderRepository {
  MockOrderRepository({
    required this.menu,
    required this.store,
    required this.cards,
    this.latency = const Duration(milliseconds: 600),
    this.khqrPaysAfter = const Duration(seconds: 5),
    this.khqrExpiresAfter = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final MockMenuRepository menu;
  final MockStoreRepository store;
  final MockCardRepository cards;
  final Duration latency;
  final Duration? khqrPaysAfter;
  final Duration khqrExpiresAfter;
  final DateTime Function() _now;

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

  Order _order(int orderId) {
    final order = _orders[orderId];
    if (order == null) throw OrderException('No order $orderId.');
    return _withPayments(order);
  }

  Order _withPayments(Order o) => Order(
    id: o.id,
    status: o.status,
    pickupType: o.pickupType,
    pickupTime: o.pickupTime,
    note: o.note,
    items: o.items,
    totalAmount: o.totalAmount,
    pickupCode: o.pickupCode,
    createdAt: o.createdAt,
    placedAt: o.placedAt,
    payments: paymentsFor(o.id),
  );

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
    _orders[o.id] = Order(
      id: o.id,
      status: OrderStatus.placed,
      pickupType: o.pickupType,
      pickupTime: o.pickupTime,
      note: o.note,
      items: o.items,
      totalAmount: o.totalAmount,
      pickupCode: 'A${_nextPickupNumber++}',
      createdAt: o.createdAt,
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
