import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/order.dart';
import '../../data/repository_providers.dart';
import '../../utils/clock.dart';
import '../cart/cart_controller.dart';
import 'payment_outcome.dart';

/// Where a KHQR payment is.
enum KhqrStage {
  /// QR shown, waiting for the bank ("Waiting for payment...").
  waiting,

  /// Paid: show the success page with [KhqrState.outcome].
  paid,

  /// Expired: show the failure page with [KhqrState.outcome].
  failed,

  /// "Cancel payment": go back to checkout.
  cancelled,
}

@immutable
class KhqrState {
  const KhqrState({
    required this.charge,
    required this.order,
    required this.stage,
    required this.timeLeft,
    this.outcome,
  });

  final KhqrCharge charge;

  /// What is being paid for: the saved QR image lists it.
  final Order order;
  final KhqrStage stage;

  /// "Expires in 04:59".
  final Duration timeLeft;

  /// Set when [stage] is paid or failed.
  final PaymentOutcome? outcome;

  /// "04:59"
  String get timeLeftText {
    final s = timeLeft.inSeconds.clamp(0, 99 * 60);
    return '${(s ~/ 60).toString().padLeft(2, '0')}:'
        '${(s % 60).toString().padLeft(2, '0')}';
  }

  KhqrState copyWith({
    KhqrStage? stage,
    Duration? timeLeft,
    PaymentOutcome? outcome,
  }) => KhqrState(
    charge: charge,
    order: order,
    stage: stage ?? this.stage,
    timeLeft: timeLeft ?? this.timeLeft,
    outcome: outcome ?? this.outcome,
  );
}

/// The KHQR page for one order (SA §4.2.3.3, TC-21).
///
/// Starts the charge, counts down to its expiry, and asks the backend
/// every [pollEvery] whether the bank has been paid. On success the cart
/// is emptied (the drinks are now an order).
final khqrPaymentProvider = AsyncNotifierProvider.autoDispose
    .family<KhqrPaymentController, KhqrState, int>(KhqrPaymentController.new);

class KhqrPaymentController extends AsyncNotifier<KhqrState> {
  KhqrPaymentController(this.orderId);

  final int orderId;

  static const pollEvery = Duration(seconds: 2);

  Timer? _ticker;
  bool _checking = false;
  int _ticks = 0;

  @override
  Future<KhqrState> build() async {
    final orders = ref.read(orderRepositoryProvider);
    final order = await orders.fetchOrder(orderId);
    final charge = await orders.startKhqr(orderId);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    ref.onDispose(() => _ticker?.cancel());
    return KhqrState(
      charge: charge,
      order: order,
      stage: KhqrStage.waiting,
      timeLeft: charge.expiresAt.difference(ref.read(clockProvider)()),
    );
  }

  Future<void> _tick() async {
    final s = state.value;
    if (s == null || s.stage != KhqrStage.waiting) return;
    final left = s.charge.expiresAt.difference(ref.read(clockProvider)());
    state = AsyncData(
      s.copyWith(timeLeft: left.isNegative ? Duration.zero : left),
    );
    _ticks++;
    if (_ticks % pollEvery.inSeconds == 0 || left <= Duration.zero) {
      await check();
    }
  }

  /// Asks the backend once. Also used by tests.
  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    try {
      final repo = ref.read(orderRepositoryProvider);
      final payment = await repo.checkPayment(
        state.requireValue.charge.paymentId,
      );
      if (!ref.mounted) return;
      final s = state.requireValue;
      if (s.stage != KhqrStage.waiting) return;
      if (payment.isPaid || payment.isFailed) {
        _ticker?.cancel();
        final order = await repo.fetchOrder(orderId);
        if (!ref.mounted) return;
        if (payment.isPaid) ref.read(cartControllerProvider.notifier).clear();
        state = AsyncData(
          s.copyWith(
            stage: payment.isPaid ? KhqrStage.paid : KhqrStage.failed,
            outcome: PaymentOutcome(order: order, payment: payment),
          ),
        );
      }
    } finally {
      _checking = false;
    }
  }

  /// "Cancel payment". The order stays unpaid; checkout can try again.
  Future<void> cancel() async {
    final s = state.value;
    if (s == null || s.stage != KhqrStage.waiting) return;
    _ticker?.cancel();
    await ref.read(orderRepositoryProvider).cancelPayment(s.charge.paymentId);
    if (!ref.mounted) return;
    state = AsyncData(s.copyWith(stage: KhqrStage.cancelled));
  }
}
