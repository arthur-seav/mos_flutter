import 'package:flutter/foundation.dart' show immutable;

import 'money.dart';

/// Order states (BR-08, data dictionary `orders.status`).
enum OrderStatus {
  pendingPayment,
  placed,
  confirmed,
  preparing,
  ready,
  completed,
  cancelled,
  rejected,
  abandoned,
}

/// `orders.pickup_type`.
enum PickupType { asap, scheduled }

/// `payments.method`. Cash is for walk-in orders only.
enum PaymentMethod {
  khqr('KHQR'),
  card('Card'),
  cash('Cash');

  const PaymentMethod(this.label);

  /// "KHQR", "Card".
  final String label;
}

/// `payments.status`.
enum PaymentStatus { pending, paid, failed, refundPending, refunded }

/// One try at paying for an order (`payments`). An order can have more
/// than one, e.g. a declined card and then KHQR (TC-22).
@immutable
class Payment {
  const Payment({
    required this.id,
    required this.orderId,
    required this.method,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.transactionRef,
    this.paidAt,
    this.failureReason,
  });

  final int id;
  final int orderId;
  final PaymentMethod method;
  final Money amount;
  final PaymentStatus status;
  final DateTime createdAt;
  final String? transactionRef;
  final DateTime? paidAt;

  /// Why it failed, for the failure screen ("The card was declined.").
  /// Not stored in the data dictionary; it comes from the gateway's reply.
  final String? failureReason;

  bool get isPaid => status == PaymentStatus.paid;
  bool get isFailed => status == PaymentStatus.failed;

  /// Money that was paid and is going back (BR-10, TC-25, TC-27).
  bool get isRefund =>
      status == PaymentStatus.refundPending || status == PaymentStatus.refunded;

  Payment copyWith({PaymentStatus? status}) => Payment(
    id: id,
    orderId: orderId,
    method: method,
    amount: amount,
    status: status ?? this.status,
    createdAt: createdAt,
    transactionRef: transactionRef,
    paidAt: paidAt,
    failureReason: failureReason,
  );
}

/// A drink in an order (`order_items` + `order_item_options`). Names and
/// prices are copied when the order is placed (BR-04).
@immutable
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.productName,
    required this.optionNames,
    required this.unitPrice,
    required this.quantity,
    this.optionIds = const [],
  });

  final int productId;
  final String productName;

  /// The chosen options (`order_item_options.option_id`), for "Reorder"
  /// (TC-28).
  final List<int> optionIds;

  /// As shown in the cart: "Medium · Iced · Less ice".
  final List<String> optionNames;
  final Money unitPrice;
  final int quantity;

  Money get lineTotal => unitPrice * quantity;
}

/// An order (`orders`).
@immutable
class Order {
  const Order({
    required this.id,
    required this.status,
    required this.pickupType,
    required this.items,
    required this.totalAmount,
    required this.createdAt,
    this.customerId,
    this.pickupCode,
    this.pickupTime,
    this.note,
    this.rejectReason,
    this.placedAt,
    this.confirmedAt,
    this.preparingAt,
    this.readyAt,
    this.completedAt,
    this.endedAt,
    this.payments = const [],
  });

  final int id;
  final OrderStatus status;
  final PickupType pickupType;

  /// Empty for walk-in orders.
  final int? customerId;

  /// Only for [PickupType.scheduled].
  final DateTime? pickupTime;
  final String? note;
  final List<OrderItem> items;

  /// Worked out by the backend from today's menu prices, not taken from
  /// the app (data dictionary; TC-23).
  final Money totalAmount;

  /// FR-14: given once payment succeeds, e.g. "A1024".
  final String? pickupCode;

  /// Why staff rejected it (BR-10, FR-38), e.g. "Sold out".
  final String? rejectReason;
  final DateTime createdAt;

  /// When payment succeeded.
  final DateTime? placedAt;
  final DateTime? confirmedAt;
  final DateTime? preparingAt;
  final DateTime? readyAt;
  final DateTime? completedAt;

  /// When it was cancelled, rejected or abandoned.
  final DateTime? endedAt;
  final List<Payment> payments;

  bool get isAwaitingPayment => status == OrderStatus.pendingPayment;

  /// Placed, confirmed, preparing or ready: still on its way.
  bool get isInProgress => switch (status) {
    OrderStatus.placed ||
    OrderStatus.confirmed ||
    OrderStatus.preparing ||
    OrderStatus.ready => true,
    _ => false,
  };

  /// Cancelled, rejected or abandoned.
  bool get endedEarly => switch (status) {
    OrderStatus.cancelled ||
    OrderStatus.rejected ||
    OrderStatus.abandoned => true,
    _ => false,
  };

  /// BR-09: customers can cancel only while it is Placed.
  bool get canCancel => status == OrderStatus.placed;

  Payment? get lastPayment => payments.isEmpty ? null : payments.last;

  /// The payment that went through (it may since be refunded).
  Payment? get paidPayment {
    for (final p in payments.reversed) {
      if (p.isPaid || p.isRefund) return p;
    }
    return null;
  }

  int get drinkCount => items.fold(0, (sum, i) => sum + i.quantity);

  Order copyWith({
    OrderStatus? status,
    String? pickupCode,
    String? rejectReason,
    DateTime? placedAt,
    DateTime? confirmedAt,
    DateTime? preparingAt,
    DateTime? readyAt,
    DateTime? completedAt,
    DateTime? endedAt,
    List<Payment>? payments,
  }) => Order(
    id: id,
    status: status ?? this.status,
    pickupType: pickupType,
    items: items,
    totalAmount: totalAmount,
    createdAt: createdAt,
    customerId: customerId,
    pickupCode: pickupCode ?? this.pickupCode,
    pickupTime: pickupTime,
    note: note,
    rejectReason: rejectReason ?? this.rejectReason,
    placedAt: placedAt ?? this.placedAt,
    confirmedAt: confirmedAt ?? this.confirmedAt,
    preparingAt: preparingAt ?? this.preparingAt,
    readyAt: readyAt ?? this.readyAt,
    completedAt: completedAt ?? this.completedAt,
    endedAt: endedAt ?? this.endedAt,
    payments: payments ?? this.payments,
  );
}

/// What the app sends to place an order. No prices: the backend works
/// them out (TC-23).
@immutable
class OrderRequest {
  const OrderRequest({
    required this.lines,
    required this.pickupType,
    this.pickupTime,
    this.note,
  });

  final List<OrderLineRequest> lines;
  final PickupType pickupType;
  final DateTime? pickupTime;
  final String? note;
}

@immutable
class OrderLineRequest {
  const OrderLineRequest({
    required this.productId,
    required this.optionIds,
    required this.quantity,
  });

  final int productId;
  final List<int> optionIds;
  final int quantity;
}

/// A KHQR charge waiting to be paid (SA §4.2.3.3).
@immutable
class KhqrCharge {
  const KhqrCharge({
    required this.paymentId,
    required this.orderId,
    required this.qrData,
    required this.amount,
    required this.merchantName,
    required this.expiresAt,
  });

  final int paymentId;
  final int orderId;

  /// The KHQR string the QR code encodes. Made by the backend / bank.
  final String qrData;
  final Money amount;
  final String merchantName;
  final DateTime expiresAt;
}
