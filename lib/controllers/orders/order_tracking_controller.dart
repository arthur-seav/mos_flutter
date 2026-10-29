import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repository_providers.dart';
import 'order_progress.dart';

/// How often an open tracking page asks for the order again. NFR-02 asks
/// for status changes within 5 seconds; a real backend would push them.
/// Tests set it to null and call [OrderTrackingController.refresh].
final trackingPollProvider = Provider<Duration?>(
  (ref) => const Duration(seconds: 3),
);

@immutable
class TrackingState {
  const TrackingState({
    required this.order,
    required this.asapPrepMin,
    this.isCancelling = false,
  });

  final Order order;

  /// For "Est. 10:25 AM" on ASAP orders (`StoreSettings.asapPrepMin`).
  final int asapPrepMin;
  final bool isCancelling;

  OrderProgress get progress =>
      OrderProgress.of(order, asapPrepMin: asapPrepMin);

  /// Shown instead of the pickup code once cancelled or rejected.
  RefundInfo? get refund => RefundInfo.of(order);

  TrackingState copyWith({Order? order, bool? isCancelling}) => TrackingState(
    order: order ?? this.order,
    asapPrepMin: asapPrepMin,
    isCancelling: isCancelling ?? this.isCancelling,
  );
}

/// The tracking page for one order (SA §4.2.4, FR-15, FR-17, TC-24–27).
final orderTrackingProvider = AsyncNotifierProvider.autoDispose
    .family<OrderTrackingController, TrackingState, int>(
      OrderTrackingController.new,
    );

class OrderTrackingController extends AsyncNotifier<TrackingState> {
  OrderTrackingController(this.orderId);

  final int orderId;
  Timer? _timer;
  bool _refreshing = false;

  @override
  Future<TrackingState> build() async {
    final order = await ref.read(orderRepositoryProvider).fetchOrder(orderId);
    final store = await ref.read(storeRepositoryProvider).fetchStoreInfo();
    final every = ref.read(trackingPollProvider);
    if (every != null && order.isInProgress) {
      _timer = Timer.periodic(every, (_) => refresh());
    }
    ref.onDispose(() => _timer?.cancel());
    return TrackingState(order: order, asapPrepMin: store.settings.asapPrepMin);
  }

  /// Asks for the order again. Stops asking once it is over.
  Future<void> refresh() async {
    final s = state.value;
    if (s == null || _refreshing) return;
    _refreshing = true;
    try {
      final order = await ref.read(orderRepositoryProvider).fetchOrder(orderId);
      if (!ref.mounted) return;
      if (!order.isInProgress) _timer?.cancel();
      state = AsyncData((state.value ?? s).copyWith(order: order));
    } on Object {
      // Keep showing the last known status; the next poll tries again.
    } finally {
      _refreshing = false;
    }
  }

  /// "Yes, cancel order" (BR-09, TC-25). Returns a message when the
  /// store got there first (TC-26); the page then shows the new status.
  Future<String?> cancel() async {
    final s = state.value;
    if (s == null || s.isCancelling) return null;
    state = AsyncData(s.copyWith(isCancelling: true));
    final orders = ref.read(orderRepositoryProvider);
    try {
      final order = await orders.cancelOrder(orderId);
      _timer?.cancel();
      if (ref.mounted) {
        state = AsyncData(s.copyWith(order: order, isCancelling: false));
      }
      return null;
    } on OrderException catch (e) {
      final order = await orders.fetchOrder(orderId).catchError((_) => s.order);
      if (ref.mounted) {
        state = AsyncData(s.copyWith(order: order, isCancelling: false));
      }
      return e.message;
    }
  }
}
