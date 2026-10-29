import 'package:flutter/foundation.dart' show immutable;

import '../../data/models/order.dart';

/// What the success or failure page shows (SA §4.2.3.4): the order and
/// the payment that just finished.
@immutable
class PaymentOutcome {
  const PaymentOutcome({required this.order, required this.payment});

  final Order order;
  final Payment payment;

  bool get isPaid => payment.isPaid;
}
