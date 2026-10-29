import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/order.dart';
import '../../data/repository_providers.dart';
import 'order_tracking_controller.dart';

/// The Orders tab (SA §4.2.5.1, FR-18): orders on their way, and the
/// rest. Newest first in both.
@immutable
class MyOrders {
  const MyOrders({required this.inProgress, required this.past});

  final List<Order> inProgress;
  final List<Order> past;

  /// "Order Not Found" (Figma: Orders (empty)).
  bool get isEmpty => inProgress.isEmpty && past.isEmpty;
}

final myOrdersProvider =
    AsyncNotifierProvider.autoDispose<MyOrdersController, MyOrders>(
      MyOrdersController.new,
    );

/// Loads the signed-in customer's orders. While some are in progress it
/// asks again every few seconds (same as the tracking page), so their
/// status badges move on by themselves.
class MyOrdersController extends AsyncNotifier<MyOrders> {
  Timer? _timer;

  @override
  Future<MyOrders> build() async {
    ref.onDispose(() => _timer?.cancel());
    final orders = await _load();
    _keepUpdating(orders);
    return orders;
  }

  Future<MyOrders> _load() async {
    final all = await ref.read(orderRepositoryProvider).fetchMyOrders();
    return MyOrders(
      inProgress: [
        for (final o in all)
          if (o.isInProgress) o,
      ],
      past: [
        for (final o in all)
          if (!o.isInProgress) o,
      ],
    );
  }

  void _keepUpdating(MyOrders orders) {
    _timer?.cancel();
    final every = ref.read(trackingPollProvider);
    if (every == null || orders.inProgress.isEmpty) return;
    _timer = Timer.periodic(every, (_) => refresh());
  }

  /// Pull to refresh, coming back to the tab, or the timer.
  Future<void> refresh() async {
    try {
      final orders = await _load();
      if (!ref.mounted) return;
      state = AsyncData(orders);
      _keepUpdating(orders);
    } on Object catch (e, s) {
      if (ref.mounted && !state.hasValue) state = AsyncError(e, s);
    }
  }
}
