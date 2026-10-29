import 'package:flutter/foundation.dart' show immutable;

import '../../data/models/order.dart';
import '../../utils/time_format.dart';

/// How a step of the order flow is drawn on the tracking page.
enum StepState {
  /// Green check and the time it happened.
  done,

  /// Caramel ring, bold title, caramel subtitle.
  current,

  /// Empty ring.
  upcoming,

  /// Red cross: where a cancelled or rejected order stopped.
  failed,

  /// Greyed out after a failed step.
  skipped,
}

/// The colour of the "Current status" card (Figma: dark brown while it is
/// being made, green when ready, lighter brown when picked up, red when
/// it ended early).
enum StatusTone { inProgress, ready, done, ended }

@immutable
class ProgressStep {
  const ProgressStep(this.title, this.subtitle, this.state);

  final String title;
  final String subtitle;
  final StepState state;
}

/// Everything the tracking page shows that depends on the order's status
/// (SA §4.2.4, Figma: Order · Placed … Order · Cancelled). Worked out
/// here so the page only draws it, and so it can be tested without
/// widgets.
@immutable
class OrderProgress {
  const OrderProgress._({
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.filledSegments,
    required this.steps,
    required this.pickupHint,
    required this.summary,
  });

  /// The five steps of the flow, also the five bars on the status card.
  static const stepCount = 5;

  factory OrderProgress.of(Order order, {required int asapPrepMin}) {
    final ready = _estimatedReady(order, asapPrepMin);
    final readyText = ready == null ? '' : formatClock(ready);
    final placed = _clock(order.placedAt);

    final (title, subtitle, tone, filled) = switch (order.status) {
      OrderStatus.placed => (
        'Order placed',
        'Waiting for the store to confirm',
        StatusTone.inProgress,
        1,
      ),
      OrderStatus.confirmed => (
        'Order confirmed',
        'A barista will start on it shortly',
        StatusTone.inProgress,
        2,
      ),
      OrderStatus.preparing => (
        'Being prepared',
        'Estimated ready at $readyText',
        StatusTone.inProgress,
        3,
      ),
      OrderStatus.ready => (
        'Ready for pickup!',
        'Show your pickup code at the counter',
        StatusTone.ready,
        4,
      ),
      OrderStatus.completed => (
        'Enjoy your drinks',
        'Picked up at ${_clock(order.completedAt)}',
        StatusTone.done,
        5,
      ),
      OrderStatus.cancelled => (
        'Order cancelled',
        'Cancelled by you at ${_clock(order.endedAt)}',
        StatusTone.ended,
        1,
      ),
      OrderStatus.rejected => (
        'Order rejected',
        "The store couldn't take it: ${order.rejectReason ?? 'no reason'}",
        StatusTone.ended,
        1,
      ),
      // Not shown on the tracking page: not paid yet, or a walk-in.
      OrderStatus.pendingPayment || OrderStatus.abandoned => (
        'Waiting for payment',
        'This order has not been paid',
        StatusTone.ended,
        0,
      ),
    };

    final List<ProgressStep> steps;
    if (order.endedEarly) {
      final why = order.status == OrderStatus.rejected
          ? order.rejectReason ?? 'Rejected'
          : _refundWords(order);
      steps = [
        ProgressStep('Order placed', placed, StepState.done),
        ProgressStep(
          order.status == OrderStatus.rejected
              ? 'Rejected by store'
              : 'Cancelled',
          '${_clock(order.endedAt)} · $why',
          StepState.failed,
        ),
        const ProgressStep('Preparing', '—', StepState.skipped),
        const ProgressStep('Ready for pickup', '—', StepState.skipped),
        const ProgressStep('Picked up', '—', StepState.skipped),
      ];
    } else {
      final at = [
        order.placedAt,
        order.confirmedAt,
        order.preparingAt,
        order.readyAt,
        order.completedAt,
      ];
      const titles = [
        'Order placed',
        'Confirmed by store',
        'Preparing',
        'Ready for pickup',
        'Picked up',
      ];
      final upcoming = [
        '',
        'Usually within a minute',
        'Up next',
        'Est. $readyText',
        'Show code at the counter',
      ];
      const nowWords = [
        'Waiting for the store to confirm',
        'A barista will start shortly',
        'In progress',
        'Waiting at the counter',
        '',
      ];
      // Index of the current step; completed = all five done.
      final current = order.status == OrderStatus.completed ? 5 : filled - 1;
      steps = [
        for (var i = 0; i < stepCount; i++)
          if (i < current)
            ProgressStep(titles[i], _clock(at[i]), StepState.done)
          else if (i == current)
            ProgressStep(titles[i], nowWords[i], StepState.current)
          else
            ProgressStep(titles[i], upcoming[i], StepState.upcoming),
      ];
    }

    final paid = order.paidPayment;
    final count = order.drinkCount;
    final items = '$count ${count == 1 ? 'item' : 'items'}';
    final money = order.totalAmount.format();
    final payment = switch (paid?.status) {
      PaymentStatus.refundPending => 'Refund processing',
      PaymentStatus.refunded => 'Refunded',
      _ when paid != null => 'Paid with ${paid.method.label}',
      _ => 'Not paid',
    };

    return OrderProgress._(
      title: title,
      subtitle: subtitle,
      tone: tone,
      filledSegments: filled,
      steps: steps,
      pickupHint: order.status == OrderStatus.ready
          ? 'Show this code at the counter now. Your drinks are waiting.'
          : 'Show this code at the counter when your order is ready.',
      summary: '$items · $money · $payment',
    );
  }

  /// "Current status" card.
  final String title;
  final String subtitle;
  final StatusTone tone;

  /// How many of the [stepCount] bars are lit.
  final int filledSegments;
  final List<ProgressStep> steps;

  /// Next to the pickup code.
  final String pickupHint;

  /// "2 items · $8.10 · Paid with KHQR" (the collapsed summary row).
  final String summary;

  /// Scheduled: the pickup time. ASAP: `asap_prep_min` after the store
  /// started on it (or confirmed, or it was placed).
  static DateTime? _estimatedReady(Order order, int asapPrepMin) {
    if (order.pickupType == PickupType.scheduled) return order.pickupTime;
    final from = order.preparingAt ?? order.confirmedAt ?? order.placedAt;
    return from?.add(Duration(minutes: asapPrepMin));
  }

  static String _clock(DateTime? t) => t == null ? '' : formatClock(t);

  static String _refundWords(Order order) =>
      switch (order.paidPayment?.status) {
        PaymentStatus.refundPending ||
        PaymentStatus.refunded => 'Full refund issued',
        _ => 'Not charged',
      };
}

/// The refund block that replaces the pickup code on a cancelled or
/// rejected order (SA §4.2.4.6, BR-10).
@immutable
class RefundInfo {
  const RefundInfo({
    required this.amount,
    required this.where,
    required this.isDone,
  });

  /// Null when nothing was paid, so there is nothing to refund.
  static RefundInfo? of(Order order) {
    final p = order.paidPayment;
    if (!order.endedEarly || p == null || !p.isRefund) return null;
    return RefundInfo(
      amount: p.amount.format(),
      where: p.method == PaymentMethod.card
          ? 'Back to your card, usually within 1–3 business days.'
          : 'Back to your ${p.method.label} account, usually within 1–3 '
                'business days.',
      isDone: p.status == PaymentStatus.refunded,
    );
  }

  /// "$8.10"
  final String amount;
  final String where;

  /// Badge: "Refunded" when done, "Processing" while pending.
  final bool isDone;
}
