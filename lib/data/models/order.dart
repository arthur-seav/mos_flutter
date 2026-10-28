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
  });

  final int productId;
  final String productName;

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
    this.pickupCode,
    this.pickupTime,
    this.note,
    this.placedAt,
    this.payments = const [],
  });

  final int id;
  final OrderStatus status;
  final PickupType pickupType;

  /// Only for [PickupType.scheduled].
  final DateTime? pickupTime;
  final String? note;
  final List<OrderItem> items;

  /// Worked out by the backend from today's menu prices, not taken from
  /// the app (data dictionary; TC-23).
  final Money totalAmount;

  /// FR-14: given once payment succeeds, e.g. "A1024".
  final String? pickupCode;
  final DateTime createdAt;

  /// When payment succeeded.
  final DateTime? placedAt;
  final List<Payment> payments;

  bool get isAwaitingPayment => status == OrderStatus.pendingPayment;

  Payment? get lastPayment => payments.isEmpty ? null : payments.last;

  int get drinkCount => items.fold(0, (sum, i) => sum + i.quantity);
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
